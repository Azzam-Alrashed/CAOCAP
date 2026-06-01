import SwiftUI

struct CoCaptainInputComposer: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let store: ProjectStore?
    let isThinking: Bool
    let analysisItems: [ProjectSuggestion]
    let onSend: () -> Void
    let onStop: () -> Void
    let onQuickPrompt: (String) -> Void
    let onApplySuggestion: (ProjectSuggestion) -> Void
    let onDismissSuggestion: (ProjectSuggestion) -> Void
    
    @Environment(OnboardingCoordinator.self) private var onboarding: OnboardingCoordinator?
    @State private var localModelManager = LocalMLXModelManager.shared
    
    @State private var isOnboardingBreathing: Bool = false

    private var isInputValid: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSend: Bool {
        isInputValid && !isThinking
    }

    private var isChatOnboardingActive: Bool {
        guard let onboarding else { return false }
        return onboarding.currentStep == .chatCoCaptain && onboarding.showPopover
    }

    var body: some View {
        VStack(spacing: 10) {
            Divider().opacity(0.5)

            if localModelManager.isDownloadingLocalModel {
                VStack(spacing: 6) {
                    HStack {
                        Label("Downloading Local Gemma 4 Model...", systemImage: "cpu")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                        Spacer()
                        Text("\(Int(localModelManager.localModelDownloadProgress * 100))%")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: localModelManager.localModelDownloadProgress)
                        .tint(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if !analysisItems.isEmpty {
                CoCaptainAnalysisView(
                    suggestions: analysisItems,
                    onApply: onApplySuggestion,
                    onDismiss: onDismissSuggestion
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let store {
                ContextPill(
                    projectName: store.projectName,
                    fileName: store.fileName,
                    nodeCount: store.nodes.count
                )
            }

            HStack(alignment: .bottom, spacing: 8) {
                quickPromptMenu
                promptField
                sendButton
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .background(Color.primary.opacity(0.02))
    }

    private var quickPromptMenu: some View {
        Menu {
            Button {
                onQuickPrompt("Summarize the current canvas and point out the most important next step.")
            } label: {
                Label("Summarize Canvas", systemImage: "doc.text.magnifyingglass")
            }
            .disabled(isThinking)

            Button {
                onQuickPrompt("Review the current canvas for obvious issues, missing pieces, or polish opportunities.")
            } label: {
                Label("Review Canvas", systemImage: "checklist")
            }
            .disabled(isThinking)

            Button {
                onQuickPrompt("Suggest three useful next improvements for this project.")
            } label: {
                Label("Suggest Next Steps", systemImage: "sparkles")
            }
            .disabled(isThinking)
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 26))
                .foregroundColor(.blue)
                .shadow(color: .blue.opacity(0.2), radius: 4)
        }
        .padding(.bottom, 6)
    }

    private var promptField: some View {
        HStack(spacing: 0) {
            TextField("Ask Co-Captain...", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    onSend()
                    if onboarding?.currentStep == .chatCoCaptain {
                        onboarding?.completeCurrentStep()
                    }
                }
                .onKeyPress { press in
                    if press.key == .return {
                        if press.modifiers.contains(.shift) {
                            return .ignored
                        } else {
                            if canSend {
                                onSend()
                                if onboarding?.currentStep == .chatCoCaptain {
                                    onboarding?.completeCurrentStep()
                                }
                                return .handled
                            }
                        }
                    }
                    return .ignored
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .shadow(
                    color: isChatOnboardingActive ? Color(hex: "0066FF").opacity(isOnboardingBreathing ? 0.8 : 0.4) : .clear,
                    radius: isChatOnboardingActive ? (isOnboardingBreathing ? 24 : 10) : 0,
                    x: 0,
                    y: isChatOnboardingActive ? (isOnboardingBreathing ? 4 : 5) : 0
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isChatOnboardingActive ? Color(hex: "0066FF").opacity(isOnboardingBreathing ? 0.55 : 0.3) : (isFocused ? Color.blue.opacity(0.3) : Color.clear),
                    lineWidth: 1.5
                )
        )
        .onboardingScale(isActive: isChatOnboardingActive, isBreathing: isOnboardingBreathing)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .onAppear {
            if isChatOnboardingActive {
                withAnimation(
                    .easeInOut(duration: 1.8)
                        .repeatForever(autoreverses: true)
                ) {
                    isOnboardingBreathing = true
                }
            }
        }
        .onChange(of: isChatOnboardingActive) { _, newValue in
            if newValue {
                withAnimation(
                    .easeInOut(duration: 1.8)
                        .repeatForever(autoreverses: true)
                ) {
                    isOnboardingBreathing = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isOnboardingBreathing = false
                }
            }
        }
        .overlay(alignment: .top) {
            if let step = onboarding?.currentStep {
                if isChatOnboardingActive {
                    OnboardingPopoverCard(step: step, arrowPlacement: .bottom) {
                        onboarding?.skip()
                    }
                    .offset(y: -150)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .zIndex(10)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isChatOnboardingActive)
    }

    private var sendButton: some View {
        Button(action: {
            if isThinking {
                onStop()
            } else {
                onSend()
                if onboarding?.currentStep == .chatCoCaptain {
                    onboarding?.completeCurrentStep()
                }
            }
        }) {
            ZStack {
                if isThinking {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 38))
                        .frame(width: 38, height: 38)
                        .transition(.scale.combined(with: .opacity))
                } else if isInputValid {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 38))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 22))
                        .transition(.scale.combined(with: .opacity))
                        .frame(width: 38, height: 38)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .foregroundColor(.blue)
            .shadow(color: .blue.opacity(0.3), radius: 6, y: 3)
        }
        .disabled(!isThinking && !canSend)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isInputValid)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isThinking)
        .padding(.bottom, 5)
    }
}

private extension View {
    func onboardingScale(isActive: Bool, isBreathing: Bool) -> some View {
        scaleEffect(isActive ? (isBreathing ? 1.04 : 1.0) : 1.0)
    }
}
