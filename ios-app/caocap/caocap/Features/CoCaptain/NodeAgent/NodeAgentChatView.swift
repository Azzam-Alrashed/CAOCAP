import SwiftUI

/// A specialized instance of the CoCaptain interface bound strictly to a single
/// node's local agent context, allowing node-specific conversational editing.
struct NodeAgentChatView: View {
    let nodeID: UUID
    let store: ProjectStore
    var actionDispatcher: (any AppActionPerforming)?
    var onFlyToNode: ((UUID) -> Void)?

    @State private var viewModel = CoCaptainViewModel()
    @State private var text = ""
    @State private var mentions: [CoCaptainNodeMention] = []
    @State private var attachments: [CoCaptainAttachment] = []
    @FocusState private var isFocused: Bool
    @AppStorage(CoCaptainChatMode.storageKey) private var chatModeRawValue = CoCaptainChatMode.agent.rawValue

    private var chatModeBinding: Binding<CoCaptainChatMode> {
        Binding(
            get: {
                CoCaptainChatMode(rawValue: chatModeRawValue) ?? .agent
            },
            set: { newValue in
                chatModeRawValue = newValue.rawValue
                viewModel.chatMode = newValue
            }
        )
    }

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
                chatMode: chatModeBinding,
                mentions: $mentions,
                attachments: $attachments,
                isFocused: $isFocused,
                store: store,
                allowsContextPinning: false,
                pinnableNodes: [],
                isThinking: viewModel.isThinking,
                analysisItems: [],
                pendingReviewCount: viewModel.pendingReviewCount,
                onSend: sendCurrentMessage,
                onStop: viewModel.stopStreaming,
                onQuickPrompt: sendQuickPrompt,
                onFocusPendingReviews: viewModel.focusPendingReviews,
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
            syncChatModeFromStorage()
            viewModel.configureNodeSession(
                store: store,
                nodeID: nodeID,
                dispatcher: actionDispatcher
            )
            viewModel.onFlyToNode = onFlyToNode
        }
        .onChange(of: chatModeRawValue) { _, _ in
            syncChatModeFromStorage()
        }
    }

    /// Shares the same persisted Agent/Ask/Plan selection as project-scoped CoCaptain.
    private func syncChatModeFromStorage() {
        viewModel.chatMode = CoCaptainChatMode(rawValue: chatModeRawValue) ?? .agent
    }

    /// Extracts the display name from the node's agent profile.
    private var nodeTitle: String {
        guard let node = store.nodes.first(where: { $0.id == nodeID }) else { return "Agent" }
        return node.agentProfile.roleName
    }

    /// Submits the user's typed input to the local node agent.
    private func sendCurrentMessage() {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!prompt.isEmpty || !attachments.isEmpty), !viewModel.isThinking else { return }
        let submittedPrompt = prompt.isEmpty ? "Review the attached files." : prompt

        viewModel.sendMessage(submittedPrompt, attachments: attachments)
        text = ""
        attachments = []
        isFocused = false
    }

    /// Submits a pre-defined quick prompt directly without user typing.
    private func sendQuickPrompt(_ prompt: String) {
        guard !viewModel.isThinking else { return }

        text = ""
        attachments = []
        isFocused = false
        viewModel.sendMessage(prompt)
    }
}
