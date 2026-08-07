import AVFoundation
import FirebaseAILogic
import Foundation
import OSLog
import Observation

/// Manages a Gemini Live session for copilot voice (and optional screen-share) calls.
@MainActor
@Observable
final class GeminiLiveSessionService {
    enum ConnectionState: Equatable {
        case idle
        case connecting
        case connected
        case ended
        case failed(String)
    }

    private(set) var connectionState: ConnectionState = .idle
    private(set) var inputTranscript: String = ""
    private(set) var outputTranscript: String = ""
    private(set) var isMuted = false

    private let logger = Logger(subsystem: "CAOCAP", category: "GeminiLive")
    private let audioEngine = CopilotCallAudioEngine()
    private let screenCapture = ScreenCaptureController()

    private var liveSession: LiveSession?
    private var receiveTask: Task<Void, Never>?
    private var mode: CopilotInteractionMode = .voice

    static let liveModelName = "gemini-2.5-flash-native-audio-preview-12-2025"

    func start(
        mode: CopilotInteractionMode,
        persona: CopilotPersona,
        projectContext: String?
    ) async {
        await stop()
        self.mode = mode
        connectionState = .connecting
        inputTranscript = ""
        outputTranscript = ""

        do {
            guard await requestMicrophoneAuthorization() else {
                connectionState = .failed(
                    LocalizationManager.shared.localizedString("copilot.call.micPermissionDenied")
                )
                return
            }

            let systemText = Self.systemInstruction(persona: persona, projectContext: projectContext, mode: mode)
            let liveModel = FirebaseAI.firebaseAI(backend: .googleAI()).liveModel(
                modelName: Self.liveModelName,
                generationConfig: LiveGenerationConfig(
                    responseModalities: [.audio],
                    inputAudioTranscription: AudioTranscriptionConfig(),
                    outputAudioTranscription: AudioTranscriptionConfig()
                ),
                systemInstruction: ModelContent(role: "system", parts: systemText)
            )

            let session = try await liveModel.connect()
            liveSession = session

            audioEngine.onPCMChunk = { [weak self] data in
                Task { @MainActor in
                    await self?.liveSession?.sendAudioRealtime(data)
                }
            }
            try audioEngine.start()

            if mode == .video {
                screenCapture.onJPEGFrame = { [weak self] jpeg in
                    Task { @MainActor in
                        await self?.liveSession?.sendVideoRealtime(jpeg, mimeType: "image/jpeg")
                    }
                }
                screenCapture.onError = { [weak self] error in
                    Task { @MainActor in
                        self?.logger.error("Screen capture error: \(error.localizedDescription, privacy: .public)")
                        if case .connected = self?.connectionState {
                            self?.connectionState = .failed(error.localizedDescription)
                        }
                    }
                }
                screenCapture.start()
            }

            connectionState = .connected
            receiveTask = Task { [weak self] in
                await self?.consumeResponses(from: session)
            }

            await session.sendTextRealtime(
                LocalizationManager.shared.localizedString(
                    "copilot.call.greetingPrompt",
                    arguments: [persona.displayName]
                )
            )
        } catch {
            logger.error("Live connect failed: \(error.localizedDescription, privacy: .public)")
            connectionState = .failed(error.localizedDescription)
            await stop()
        }
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        audioEngine.setMuted(muted)
    }

    func stop() async {
        receiveTask?.cancel()
        receiveTask = nil
        screenCapture.stop()
        audioEngine.stop()
        if let liveSession {
            await liveSession.close()
        }
        liveSession = nil
        if case .failed = connectionState {
            // keep failure message
        } else if connectionState != .idle {
            connectionState = .ended
        }
    }

    private func consumeResponses(from session: LiveSession) async {
        do {
            for try await message in session.responses {
                if Task.isCancelled { break }
                switch message.payload {
                case .content(let content):
                    if content.wasInterrupted {
                        audioEngine.clearPlayback()
                    }
                    if let input = content.inputAudioTranscription?.text, !input.isEmpty {
                        inputTranscript = input
                    }
                    if let output = content.outputAudioTranscription?.text, !output.isEmpty {
                        outputTranscript = output
                    }
                    content.modelTurn?.parts.forEach { part in
                        if let inline = part as? InlineDataPart,
                           inline.mimeType.starts(with: "audio/pcm") {
                            audioEngine.enqueuePlaybackPCM16(inline.data)
                        }
                    }
                case .toolCall, .toolCallCancellation, .goingAwayNotice:
                    break
                @unknown default:
                    break
                }
            }
        } catch {
            if !Task.isCancelled {
                logger.error("Live receive failed: \(error.localizedDescription, privacy: .public)")
                connectionState = .failed(error.localizedDescription)
            }
        }
    }

    private static func systemInstruction(
        persona: CopilotPersona,
        projectContext: String?,
        mode: CopilotInteractionMode
    ) -> String {
        var lines = [
            "You are \(persona.displayName), the user's copilot in CAOCAP.",
            LocalizationManager.shared.localizedString(persona.roleKey),
            persona.mantra,
            "Keep spoken replies concise and helpful for building on an infinite canvas."
        ]
        if mode == .video {
            lines.append(
                "The user is sharing their app screen. Use the screen frames to understand their canvas and guide them."
            )
        }
        if let projectContext, !projectContext.isEmpty {
            lines.append("Project context:\n\(projectContext)")
        }
        return lines.joined(separator: "\n")
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
