import SwiftUI
import UIKit

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
    @State private var showsClearConfirmation = false
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
                allowsContextPinning: false,
                pinnableNodes: [],
                isThinking: viewModel.isThinking,
                isConversationArchiveLoading: false,
                analysisItems: [],
                pendingReviewCount: viewModel.pendingReviewCount,
                onSend: sendCurrentMessage,
                onStop: viewModel.stopStreaming,
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
                    showsClearConfirmation = true
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
        .onChange(of: viewModel.composerDraftRequest) { _, draft in
            guard let draft else { return }
            text = draft.text
            mentions = draft.mentions
            attachments = draft.attachments
            viewModel.composerDraftRequest = nil
            isFocused = draft.shouldFocus
        }
        .onChange(of: viewModel.progressPhase) { oldPhase, newPhase in
            if let newPhase {
                announceForAccessibility(newPhase.localizedTitle)
            } else if oldPhase != nil {
                announceForAccessibility(
                    LocalizationManager.shared.localizedString(
                        "CoCaptain response ready."
                    )
                )
            }
        }
        .onChange(of: viewModel.pendingReviewCount) { oldCount, newCount in
            guard newCount > oldCount else { return }
            announceForAccessibility(
                LocalizationManager.shared.localizedString(
                    "Changes are ready for review."
                )
            )
        }
        .confirmationDialog(
            LocalizationManager.shared.localizedString("Clear this node conversation?"),
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(LocalizationManager.shared.localizedString("Clear"), role: .destructive) {
                viewModel.clearHistory()
            }
            Button(LocalizationManager.shared.localizedString("Cancel"), role: .cancel) {}
        } message: {
            Text(
                LocalizationManager.shared.localizedString(
                    "Pending Review Bundles in this node chat will also be removed."
                )
            )
        }
    }

    /// Shares the same persisted Agent/Ask/Plan selection as project-scoped CoCaptain.
    private func syncChatModeFromStorage() {
        viewModel.chatMode = CoCaptainChatMode(rawValue: chatModeRawValue) ?? .agent
    }

    private func announceForAccessibility(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
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

        guard viewModel.sendMessage(submittedPrompt, attachments: attachments) else { return }
        HapticsManager.shared.trigger(.soft)
        text = ""
        attachments = []
        isFocused = false
    }

}
