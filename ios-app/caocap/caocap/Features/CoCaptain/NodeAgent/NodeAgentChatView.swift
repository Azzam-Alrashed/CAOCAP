import SwiftUI

/// A specialized instance of the CoCaptain interface bound strictly to a single
/// node's local agent context, allowing node-specific conversational editing.
struct NodeAgentChatView: View {
    let nodeID: UUID
    let store: ProjectStore
    var actionDispatcher: (any AppActionPerforming)?

    @State private var viewModel = CoCaptainViewModel()
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            CoCaptainTimelineListView(
                viewModel: viewModel,
                lastScrollPosition: $viewModel.lastScrollPosition,
                isFocused: $isFocused
            )

            CoCaptainInputComposer(
                text: $text,
                isFocused: $isFocused,
                store: store,
                isThinking: viewModel.isThinking,
                analysisItems: [],
                onSend: sendCurrentMessage,
                onStop: viewModel.stopStreaming,
                onQuickPrompt: sendQuickPrompt,
                onApplySuggestion: viewModel.applySuggestion,
                onDismissSuggestion: viewModel.dismissSuggestion
            )
        }
        .navigationTitle(nodeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    viewModel.clearHistory()
                }
                .foregroundColor(.red)
            }
        }
        .onAppear {
            viewModel.configureNodeSession(
                store: store,
                nodeID: nodeID,
                dispatcher: actionDispatcher
            )
        }
    }

    /// Extracts the display name from the node's agent profile.
    private var nodeTitle: String {
        guard let node = store.nodes.first(where: { $0.id == nodeID }) else { return "Agent" }
        return node.agentProfile.roleName
    }

    /// Submits the user's typed input to the local node agent.
    private func sendCurrentMessage() {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !viewModel.isThinking else { return }

        viewModel.sendMessage(prompt)
        text = ""
        isFocused = false
    }

    /// Submits a pre-defined quick prompt directly without user typing.
    private func sendQuickPrompt(_ prompt: String) {
        guard !viewModel.isThinking else { return }

        text = ""
        isFocused = false
        viewModel.sendMessage(prompt)
    }
}
