import Foundation
import Observation

/// UI state for a copilot voice or screen-share call.
@MainActor
@Observable
final class CopilotCallViewModel {
    let mode: CopilotInteractionMode
    let persona: CopilotPersona
    let projectContext: String?
    let liveService = GeminiLiveSessionService()

    var onDismiss: (() -> Void)?
    var onUpgrade: (() -> Void)?

    init(
        mode: CopilotInteractionMode,
        persona: CopilotPersona,
        projectContext: String? = nil
    ) {
        self.mode = mode
        self.persona = persona
        self.projectContext = projectContext
    }

    var connectionState: GeminiLiveSessionService.ConnectionState {
        liveService.connectionState
    }

    var isMuted: Bool {
        liveService.isMuted
    }

    var isQuotaExceeded: Bool {
        liveService.isQuotaExceeded
    }

    var inputTranscript: String {
        liveService.inputTranscript
    }

    var outputTranscript: String {
        liveService.outputTranscript
    }

    var statusText: String {
        switch connectionState {
        case .idle:
            return LocalizationManager.shared.localizedString("copilot.call.status.idle")
        case .connecting:
            return LocalizationManager.shared.localizedString("copilot.call.status.connecting")
        case .connected:
            return LocalizationManager.shared.localizedString(
                mode == .video ? "copilot.call.status.sharing" : "copilot.call.status.connected"
            )
        case .ended:
            return LocalizationManager.shared.localizedString("copilot.call.status.ended")
        case .failed(let message):
            return message
        }
    }

    func start() {
        Task {
            await liveService.start(
                mode: mode,
                persona: persona,
                projectContext: projectContext
            )
        }
    }

    func toggleMute() {
        liveService.setMuted(!liveService.isMuted)
    }

    func endCall() {
        Task {
            await liveService.stop()
            onDismiss?()
        }
    }

    func upgradeToPro() {
        Task {
            await liveService.stop()
            onUpgrade?()
            onDismiss?()
        }
    }
}
