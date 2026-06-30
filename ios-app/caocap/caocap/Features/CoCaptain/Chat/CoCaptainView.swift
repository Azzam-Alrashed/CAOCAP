import SwiftUI

struct CoCaptainView: View {
    var viewModel: CoCaptainViewModel
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    
    @Environment(OnboardingCoordinator.self) private var onboarding: OnboardingCoordinator?

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            VStack(spacing: 0) {
                CoCaptainTimelineListView(
                    viewModel: viewModel,
                    lastScrollPosition: $viewModel.lastScrollPosition,
                    isFocused: $isFocused
                )

                CoCaptainInputComposer(
                    text: $text,
                    isFocused: $isFocused,
                    store: viewModel.store,
                    isThinking: viewModel.isThinking,
                    analysisItems: viewModel.analysisItems,
                    onSend: sendCurrentMessage,
                    onStop: viewModel.stopStreaming,
                    onQuickPrompt: sendQuickPrompt,
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
        .onboardingTooltipOverlay()
        .onChange(of: text) { oldValue, newValue in
            hideChatOnboardingWhenTypingChanges(from: oldValue, to: newValue)
        }
        .onChange(of: viewModel.lastTurnCompletion) { _, completion in
            advanceChatOnboardingIfHandoffFinished(completion)
        }
        .onChange(of: onboarding?.currentStep) { _, step in
            if step == .chatCoCaptain {
                hideChatOnboardingIfTextIsPresent()
            }
        }
        .onAppear {
            hideChatOnboardingIfTextIsPresent()
        }
    }

    private func sendCurrentMessage() {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !viewModel.isThinking else { return }

        beginChatOnboardingResponseWaitIfNeeded()
        viewModel.sendMessage(prompt, purpose: currentTurnPurpose)
        text = ""
        isFocused = false
    }

    private func sendQuickPrompt(_ prompt: String) {
        guard !viewModel.isThinking else { return }

        text = ""
        isFocused = false
        beginChatOnboardingResponseWaitIfNeeded()
        viewModel.sendMessage(prompt, purpose: currentTurnPurpose)
    }

    /// Gives each onboarding conversation turn its explicit UX objective.
    private var currentTurnPurpose: CoCaptainTurnPurpose {
        switch onboarding?.currentStep {
        case .some(.submitCoCaptainPrompt):
            return .onboardingWelcome
        case .some(.chatCoCaptain):
            return .onboardingBuildHandoff
        default:
            return .standard
        }
    }

    /// Hides the onboarding tooltip if the user begins typing a message in the text field.
    private func hideChatOnboardingWhenTypingChanges(from oldValue: String, to newValue: String) {
        guard onboarding?.currentStep == .chatCoCaptain else { return }

        let wasEmpty = oldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isTyping = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if wasEmpty && isTyping {
            onboarding?.hidePopoverForCurrentStep()
        }
    }

    /// Hides the onboarding tooltip if there is already text present in the chat input composer when appearing.
    private func hideChatOnboardingIfTextIsPresent() {
        guard onboarding?.currentStep == .chatCoCaptain,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        onboarding?.hidePopoverForCurrentStep()
    }

    /// Hides the chat instruction while the user's idea handoff is in progress.
    private func beginChatOnboardingResponseWaitIfNeeded() {
        guard onboarding?.currentStep == .chatCoCaptain else { return }

        onboarding?.hidePopoverForCurrentStep()
    }

    /// Shows the Back to Canvas step only after the exact onboarding handoff
    /// response succeeds. The coordinator applies its existing inter-step delay.
    private func advanceChatOnboardingIfHandoffFinished(
        _ completion: CoCaptainTurnCompletion?
    ) {
        guard onboarding?.currentStep == .chatCoCaptain,
              completion?.shouldAdvanceToCanvasDismissal == true else {
            return
        }

        onboarding?.completeCurrentStep()
    }
}

#Preview {
    CoCaptainView(viewModel: CoCaptainViewModel())
}
