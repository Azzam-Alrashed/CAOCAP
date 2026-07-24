import Testing
@testable import caocap

struct LocalGemmaPromptContractTests {
    @MainActor
    @Test func localStructuredTurnUsesXMLWithoutCloudTools() {
        let prompt = LLMService.shared.buildPrompt(
            userMessage: "build a landing page",
            context: "Current Mini-App code",
            expectsStructuredResponse: true,
            availableActions: [],
            scope: .project,
            purpose: .standard,
            chatMode: .agent,
            nodeEditToolsEnabled: false,
            modelSupportsFunctionCalling: false
        )

        #expect(prompt.contains("XML schema for `cocaptain_actions`"))
        #expect(!prompt.contains("propose_node_edit"))
        #expect(!prompt.contains("read_node_section"))
    }
}
