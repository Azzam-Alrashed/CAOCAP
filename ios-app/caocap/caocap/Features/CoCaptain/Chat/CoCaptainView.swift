import SwiftUI
import Popovers

struct CoCaptainView: View {
    var viewModel: CoCaptainViewModel
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    
    @Environment(OnboardingCoordinator.self) private var onboarding: OnboardingCoordinator?
    @State private var onboardingGlowScale: CGFloat = 1.0
    @State private var onboardingGlowOpacity: CGFloat = 0.8

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
                    .overlay {
                        if let onboarding, onboarding.currentStep == .dismissCoCaptain && onboarding.showPopover {
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color(hex: "6C5CE7"), Color(hex: "0984E3")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .scaleEffect(onboardingGlowScale)
                                .opacity(onboardingGlowOpacity)
                                .onAppear {
                                    withAnimation(
                                        .easeInOut(duration: 1.5)
                                            .repeatForever(autoreverses: false)
                                    ) {
                                        onboardingGlowScale = 1.3
                                        onboardingGlowOpacity = 0.0
                                    }
                                }
                        }
                    }
                    .popover(
                        present: Binding(
                            get: {
                                guard let onboarding else { return false }
                                return onboarding.currentStep == .dismissCoCaptain && onboarding.showPopover
                            },
                            set: { newValue in
                                onboarding?.showPopover = newValue
                            }
                        ),
                        attributes: { attributes in
                            attributes.position = .absolute(
                                originAnchor: .bottom,
                                popoverAnchor: .top
                            )
                            attributes.dismissal.mode = .none
                            attributes.rubberBandingMode = .none
                            attributes.blocksBackgroundTouches = false
                            attributes.presentation.animation = .spring(response: 0.4, dampingFraction: 0.8)
                            attributes.presentation.transition = .asymmetric(
                                insertion: .scale(scale: 0.85).combined(with: .opacity),
                                removal: .scale(scale: 0.9).combined(with: .opacity)
                            )
                            attributes.dismissal.animation = .spring(response: 0.3, dampingFraction: 0.8)
                            attributes.dismissal.transition = .asymmetric(
                                insertion: .scale(scale: 0.85).combined(with: .opacity),
                                removal: .scale(scale: 0.9).combined(with: .opacity)
                            )
                            attributes.sourceFrameInset = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
                        }
                    ) {
                        if let step = onboarding?.currentStep {
                            OnboardingPopoverCard(step: step, arrowOffset: 125, arrowPlacement: .top) {
                                onboarding?.skip()
                            }
                        } else {
                            EmptyView()
                        }
                    }
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
        if onboarding?.currentStep == .chatCoCaptain {
            onboarding?.completeCurrentStep()
        }
    }
}

#Preview {
    CoCaptainView(viewModel: CoCaptainViewModel())
}
