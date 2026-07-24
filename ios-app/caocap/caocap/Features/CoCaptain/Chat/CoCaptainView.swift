import SwiftUI

struct CoCaptainView: View {
    @Bindable var viewModel: CoCaptainViewModel
    @State private var text: String = ""
    @State private var mentions: [CoCaptainNodeMention] = []
    @State private var attachments: [CoCaptainAttachment] = []
    @FocusState private var isFocused: Bool
    @AppStorage(CoCaptainChatMode.storageKey) private var chatModeRawValue = CoCaptainChatMode.agent.rawValue
    
    @Environment(OnboardingCoordinator.self) private var onboarding: OnboardingCoordinator?

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
        NavigationStack {
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
                    store: viewModel.store,
                    allowsContextPinning: true,
                    pinnableNodes: viewModel.pinnableContextNodes,
                    isThinking: viewModel.isThinking,
                    analysisItems: viewModel.analysisItems,
                    pendingReviewCount: viewModel.pendingReviewCount,
                    onSend: sendCurrentMessage,
                    onStop: viewModel.stopStreaming,
                    onQuickPrompt: sendQuickPrompt,
                    onFocusPendingReviews: viewModel.focusPendingReviews,
                    onApplySuggestion: viewModel.applySuggestion,
                    onDismissSuggestion: viewModel.dismissSuggestion
                )
            }
            .navigationTitle(
                viewModel.pendingReviewCount > 0
                    ? LocalizationManager.shared.localizedString(
                        "Co-Captain (%lld)",
                        arguments: [Int64(viewModel.pendingReviewCount)]
                    )
                    : "Co-Captain"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isFocused = false
                        viewModel.setPresented(false)
                    }
                    .onboardingTooltipAnchor(.coCaptainDoneButton)
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        viewModel.clearHistory()
                    }) {
                        Text("Clear")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .coCaptainOnboardingTooltipOverlay()
        .onChange(of: text) { oldValue, newValue in
            hideChatOnboardingWhenTypingChanges(from: oldValue, to: newValue)
        }
        .onChange(of: viewModel.lastTurnCompletion) { _, completion in
            advanceOnboardingAfterGuidedEdit(completion)
        }
        .onChange(of: onboarding?.currentStep) { _, step in
            if step == .chatCoCaptain {
                hideChatOnboardingIfTextIsPresent()
            }
        }
        .onAppear {
            syncChatModeFromStorage()
            hideChatOnboardingIfTextIsPresent()
        }
        .onChange(of: chatModeRawValue) { _, _ in
            syncChatModeFromStorage()
        }
    }

    /// Keeps the view model aligned with the persisted composer mode.
    private func syncChatModeFromStorage() {
        viewModel.chatMode = CoCaptainChatMode(rawValue: chatModeRawValue) ?? .agent
    }

    private func sendCurrentMessage() {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!prompt.isEmpty || !attachments.isEmpty), !viewModel.isThinking else { return }
        let submittedPrompt = prompt.isEmpty ? "Review the attached files." : prompt

        beginChatOnboardingResponseWaitIfNeeded()
        guard viewModel.sendMessage(
            submittedPrompt,
            mentions: mentions,
            attachments: attachments,
            purpose: currentTurnPurpose
        ) else { return }
        text = ""
        mentions = []
        attachments = []
        isFocused = false
    }

    private func sendQuickPrompt(_ prompt: String) {
        guard !viewModel.isThinking else { return }

        text = ""
        mentions = []
        attachments = []
        isFocused = false
        beginChatOnboardingResponseWaitIfNeeded()
        viewModel.sendMessage(prompt, purpose: currentTurnPurpose)
    }

    /// Gives each onboarding conversation turn its explicit UX objective.
    private var currentTurnPurpose: CoCaptainTurnPurpose {
        switch onboarding?.currentStep {
        case .some(.submitCoCaptainPrompt):
            return .onboardingWelcome
        case .some(.chatCoCaptain), .some(.chatCoCaptainGameEdit):
            return .onboardingGuidedEdit
        default:
            return .standard
        }
    }

    private var guidedEditQuickPrompt: String {
        LocalizationManager.shared.localizedString("onboarding.chatCoCaptain.quickPrompt")
    }

    /// Hides the onboarding tooltip if the user begins typing a message in the text field.
    private func hideChatOnboardingWhenTypingChanges(from oldValue: String, to newValue: String) {
        guard onboarding?.currentStep == .chatCoCaptain || onboarding?.currentStep == .chatCoCaptainGameEdit else { return }

        let wasEmpty = oldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isTyping = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if wasEmpty && isTyping {
            onboarding?.hidePopoverForCurrentStep()
        }
    }

    /// Hides the onboarding tooltip if there is already text present in the chat input composer when appearing.
    private func hideChatOnboardingIfTextIsPresent() {
        guard onboarding?.currentStep == .chatCoCaptain || onboarding?.currentStep == .chatCoCaptainGameEdit,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        onboarding?.hidePopoverForCurrentStep()
    }

    /// Hides the chat instruction while the user's idea handoff is in progress.
    private func beginChatOnboardingResponseWaitIfNeeded() {
        guard onboarding?.currentStep == .chatCoCaptain || onboarding?.currentStep == .chatCoCaptainGameEdit else { return }

        onboarding?.hidePopoverForCurrentStep()
    }

    /// Advances to the review step once the guided onboarding edit produces a review bundle.
    private func advanceOnboardingAfterGuidedEdit(
        _ completion: CoCaptainTurnCompletion?
    ) {
        guard onboarding?.currentStep == .chatCoCaptain || onboarding?.currentStep == .chatCoCaptainGameEdit,
              completion?.shouldAdvanceToOnboardingReview == true else {
            return
        }

        onboarding?.completeCurrentStep()
    }
}

#Preview {
    CoCaptainView(viewModel: CoCaptainViewModel())
}
