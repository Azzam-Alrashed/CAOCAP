import Foundation
import Testing
@testable import caocap

@MainActor
struct AgentChatContextTests {
    @Test func reopeningAnAgentReplaysOnlyItsOwnTranscript() async {
        let client = SharedHistoryClient()
        let first = CoCaptainViewModel(agentCoordinator: CoCaptainAgentCoordinator(llmClient: client))
        let second = CoCaptainViewModel(agentCoordinator: CoCaptainAgentCoordinator(llmClient: client))
        first.resumeAgentSession()
        #expect(first.sendMessage("ALPHA_PRIVATE_CONTEXT", modeOverride: .ask))
        await finishTurn(first)
        first.suspendAgentSession()
        second.resumeAgentSession()
        #expect(second.sendMessage("BETA_PRIVATE_CONTEXT", modeOverride: .ask))
        await finishTurn(second)
        second.suspendAgentSession()
        first.resumeAgentSession()
        #expect(first.sendMessage("Continue our discussion", modeOverride: .ask))
        await finishTurn(first)
        #expect(client.modelHistory.count == 1)
        #expect(client.modelHistory.last?.contains("ALPHA_PRIVATE_CONTEXT") == true)
        #expect(client.modelHistory.last?.contains("BETA_PRIVATE_CONTEXT") == false)
    }

    private func finishTurn(_ model: CoCaptainViewModel) async {
        for _ in 0..<100 where model.isThinking {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(!model.isThinking)
    }
}

@MainActor
private final class SharedHistoryClient: CoCaptainLLMClient {
    var modelHistory: [String] = []
    func resetChat(scope: CoCaptainAgentScope) { modelHistory = [] }
    func streamAgentEvents(
        for userMessage: String,
        context: String?,
        expectsStructuredResponse: Bool,
        availableActions: [AppActionDefinition],
        scope: CoCaptainAgentScope,
        purpose: CoCaptainTurnPurpose,
        chatMode: CoCaptainChatMode,
        toolExecutor: CoCaptainToolExecutor?
    ) -> AsyncThrowingStream<CoCaptainLLMStreamEvent, Error> {
        modelHistory.append(userMessage)
        return AsyncThrowingStream { continuation in
            continuation.yield(.text("A reply."))
            continuation.finish()
        }
    }
}
