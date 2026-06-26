import SwiftUI

struct CoCaptainView: View {
    var viewModel: CoCaptainViewModel
    @State private var text: String = ""
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

    private func hideChatOnboardingWhenTypingChanges(from oldValue: String, to newValue: String) {
        guard onboarding?.currentStep == .chatCoCaptain else { return }

        let wasEmpty = oldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isTyping = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if wasEmpty && isTyping {
            onboarding?.hidePopoverForCurrentStep()
        }
    }

    private func hideChatOnboardingIfTextIsPresent() {
        guard onboarding?.currentStep == .chatCoCaptain,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        onboarding?.hidePopoverForCurrentStep()
    }

    private func beginChatOnboardingResponseWaitIfNeeded() {
        guard onboarding?.currentStep == .chatCoCaptain else { return }

        onboardingChatResponseBaseline = viewModel.completedAssistantResponseCount
        onboarding?.hidePopoverForCurrentStep()
    }

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
