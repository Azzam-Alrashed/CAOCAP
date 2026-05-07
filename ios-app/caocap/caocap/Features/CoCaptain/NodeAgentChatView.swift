import SwiftUI

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
                isFocused: isFocused
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

    private var nodeTitle: String {
        store.nodes.first(where: { $0.id == nodeID })?.displayTitle ?? "Node Co-Captain"
    }

    private func sendCurrentMessage() {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !viewModel.isThinking else { return }

        viewModel.sendMessage(prompt)
        text = ""
        isFocused = false
    }

    private func sendQuickPrompt(_ prompt: String) {
        guard !viewModel.isThinking else { return }

        text = ""
        isFocused = false
        viewModel.sendMessage(prompt)
    }
}
