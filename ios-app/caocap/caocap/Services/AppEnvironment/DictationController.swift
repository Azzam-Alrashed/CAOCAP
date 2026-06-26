import AVFoundation
import Foundation
import Observation
import Speech

/// A centralized speech-to-text dictation controller that manages the audio engine,
/// speech recognition requests, permissions, and localization settings for text input fields.
@MainActor
@Observable
final class DictationController {
    /// Indicates whether dictation is currently recording audio.
    var isRecording = false
    
    /// The accumulated transcribed text from the current dictation session.
    var transcript = ""
    
    /// Contains a localized error message if the dictation process encounters a failure.
    var errorMessage: String?

    /// The audio engine used to capture microphone input buffers.
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    
    /// The recognition request that buffers audio input for the speech recognizer.
    @ObservationIgnored private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    /// The active speech recognition task monitoring the stream.
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    
    /// Tracks if an audio tap has been installed on the input node to prevent redundant taps.
    private var hasInstalledAudioTap = false
    
    /// Tracks if the audio capture has been signaled to end.
    private var hasEndedAudio = false
    
    /// A unique identifier for the active dictation session to prevent late-arriving results from stale tasks.
    private var activeSessionID = UUID()
    
    /// Seed text from the input field prior to dictation, which the transcript will be appended to.
    private var seedText = ""

    /// Starts a speech recognition dictation session.
    /// - Parameters:
    ///   - initialText: The existing text in the input field. The dictation results will append to this.
    ///   - localeOption: The chosen localization strategy (.auto, Arabic, or English).
    func start(initialText: String, localeOption: DictationLocaleOption = .auto) async {
        // Stop any currently running task before starting a new one
        stop(cancelRecognition: true)
        errorMessage = nil
        let sessionID = UUID()
        activeSessionID = sessionID

        let recognitionLocale = localeOption.recognitionLocale(for: initialText)
        let speechRecognizer = SFSpeechRecognizer(locale: recognitionLocale)
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "\(localeOption.displayName) dictation is not available right now."
            return
        }

        // Verify microphone and speech recognition authorizations
        guard await requestSpeechAuthorization() else {
            errorMessage = "Speech recognition permission is required for dictation."
            return
        }

        guard await requestMicrophoneAuthorization() else {
            errorMessage = "Microphone permission is required for dictation."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportReportedPartialResults = false // Fallback compatibility
        request.shouldReportPartialResults = true
        recognitionRequest = request
        hasEndedAudio = false
        seedText = initialText.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try configureAudioSession(with: request)
            
            // Initiate the speech recognition task with a callback for results
            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    // Ignore callbacks from previous sessions
                    guard self.activeSessionID == sessionID else { return }

                    if let result {
                        self.transcript = self.composedTranscript(
                            from: result.bestTranscription.formattedString
                        )
                    }

                    if error != nil || result?.isFinal == true {
                        self.finishRecognition(sessionID: sessionID)
                    }
                }
            }

            isRecording = true
        } catch {
            errorMessage = "Dictation could not start."
            stop(cancelRecognition: true)
        }
    }

    /// Stops the dictation session gracefully, ending audio capture and requesting final results.
    func stop() {
        stop(cancelRecognition: false)
    }

    /// Stops audio capture and optionally cancels the active speech recognition task.
    /// - Parameter cancelRecognition: If true, discards the current task without waiting for final results.
    private func stop(cancelRecognition: Bool) {
        stopAudioCapture()

        if cancelRecognition {
            recognitionTask?.cancel()
            recognitionRequest = nil
            recognitionTask = nil
            hasEndedAudio = false
            activeSessionID = UUID()
        } else if !hasEndedAudio {
            recognitionRequest?.endAudio()
            hasEndedAudio = true
        }

        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Cleans up recognition state after a session has completed or encountered an error.
    private func finishRecognition(sessionID: UUID) {
        guard activeSessionID == sessionID else { return }
        stopAudioCapture()
        recognitionRequest = nil
        recognitionTask = nil
        hasEndedAudio = false
        activeSessionID = UUID()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Stops the audio engine and removes the installed tap on the input node.
    private func stopAudioCapture() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if hasInstalledAudioTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledAudioTap = false
        }
    }

    /// Configures the AVAudioSession and installs an audio tap to stream buffers to the recognition request.
    private func configureAudioSession(with request: SFSpeechAudioBufferRecognitionRequest) throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Tap the microphone input node to stream buffers to the Speech framework
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        hasInstalledAudioTap = true

        audioEngine.prepare()
        try audioEngine.start()
    }

    /// Composes the final transcript string by appending the new spoken text to any pre-existing seed text.
    private func composedTranscript(from spokenText: String) -> String {
        guard !seedText.isEmpty else { return spokenText }
        guard !spokenText.isEmpty else { return seedText }
        return "\(seedText) \(spokenText)"
    }

    /// Requests authorization for Speech Recognition.
    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Requests authorization for Microphone usage.
    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { isGranted in
                continuation.resume(returning: isGranted)
            }
        }
    }
}

/// Represents the locale options available for dictation input.
enum DictationLocaleOption: String, CaseIterable, Identifiable {
    /// Automatically infers the language based on input text and system preferred languages.
    case auto
    /// Explicitly sets the locale to Arabic (Saudi Arabia).
    case arabicSaudiArabia
    /// Explicitly sets the locale to English (United States).
    case englishUnitedStates

    var id: String { rawValue }

    /// A user-friendly name of the locale option.
    var displayName: String {
        switch self {
        case .auto:
            "Auto"
        case .arabicSaudiArabia:
            "Arabic (Saudi Arabia)"
        case .englishUnitedStates:
            "English (US)"
        }
    }

    /// The SF Symbol associated with the locale option.
    var systemImageName: String {
        switch self {
        case .auto:
            "wand.and.stars"
        case .arabicSaudiArabia:
            "textformat"
        case .englishUnitedStates:
            "character.cursor.ibeam"
        }
    }

    /// Resolves the concrete Locale object to use for speech recognition.
    /// - Parameter text: The initial text used to infer language in the `.auto` option.
    func recognitionLocale(for text: String) -> Locale {
        switch self {
        case .auto:
            // If the existing text contains Arabic scalars or system preferred languages prioritize Arabic, use ar-SA
            if text.containsArabicScalars || Locale.preferredLanguages.contains(where: { $0.hasPrefix("ar") }) {
                return Locale(identifier: "ar-SA")
            }

            return .autoupdatingCurrent
        case .arabicSaudiArabia:
            return Locale(identifier: "ar-SA")
        case .englishUnitedStates:
            return Locale(identifier: "en-US")
        }
    }
}

private extension String {
    /// Determines whether the string contains characters belonging to Arabic Unicode ranges.
    var containsArabicScalars: Bool {
        unicodeScalars.contains { scalar in
            (0x0600...0x06FF).contains(scalar.value)     // Arabic core
            || (0x0750...0x077F).contains(scalar.value) // Arabic Supplement
            || (0x08A0...0x08FF).contains(scalar.value) // Arabic Extended-A
            || (0xFB50...0xFDFF).contains(scalar.value) // Arabic Presentation Forms-A
            || (0xFE70...0xFEFF).contains(scalar.value) // Arabic Presentation Forms-B
        }
    }
}
