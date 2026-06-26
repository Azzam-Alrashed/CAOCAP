import SwiftUI

struct CoCaptainView: View {
    var viewModel: CoCaptainViewModel
    @State private var text: String = ""
    /// The baseline count of completed CoCaptain responses, used to wait for the assistant's
    /// response to complete before advancing the active onboarding step.
    @State private var onboardingChatResponseBaseline: Int?
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
            .navigationTitle("Co-Captain")
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
        .onChange(of: viewModel.completedAssistantResponseCount) {
            advanceChatOnboardingIfResponseFinished()
        }
        .onChange(of: onboarding?.currentStep) { _, step in
            if step == .chatCoCaptain {
                hideChatOnboardingIfTextIsPresent()
            } else {
                onboardingChatResponseBaseline = nil
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
        viewModel.sendMessage(prompt)
        text = ""
        isFocused = false
        advanceChatOnboardingIfResponseFinished()
    }

    private func sendQuickPrompt(_ prompt: String) {
        guard !viewModel.isThinking else { return }

        text = ""
        isFocused = false
        beginChatOnboardingResponseWaitIfNeeded()
        viewModel.sendMessage(prompt)
        advanceChatOnboardingIfResponseFinished()
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

    /// Stores the current assistant response count baseline and hides the popover, starting the wait
    /// for CoCaptain's response.
    private func beginChatOnboardingResponseWaitIfNeeded() {
        guard onboarding?.currentStep == .chatCoCaptain else { return }

        onboardingChatResponseBaseline = viewModel.completedAssistantResponseCount
        onboarding?.hidePopoverForCurrentStep()
    }

    /// Completes the chat onboarding step if the assistant's response count baseline has been exceeded.
    private func advanceChatOnboardingIfResponseFinished() {
        guard let baseline = onboardingChatResponseBaseline,
              onboarding?.currentStep == .chatCoCaptain,
              viewModel.completedAssistantResponseCount > baseline else {
            return
        }

        onboardingChatResponseBaseline = nil
        onboarding?.completeCurrentStep()
    }
}

#Preview {
    CoCaptainView(viewModel: CoCaptainViewModel())
}
