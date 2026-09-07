import Foundation
import Observation

/// Session-only UI state. Prompts are not sent until an agent service is connected.
@MainActor
@Observable
final class AgentChatSession {
    struct Prompt: Identifiable {
        let id = UUID()
        let text: String
    }

    var draft = ""
    private(set) var prompts: [Prompt] = []

    var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func submitDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        prompts.append(Prompt(text: text))
        draft = ""
    }
}
