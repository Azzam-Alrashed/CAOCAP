import SwiftUI
import Popovers

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
    @State private var llmService = LLMService.shared
    
    // Onboarding glow animation states
    @State private var onboardingGlowScale: CGFloat = 1.0
    @State private var onboardingGlowOpacity: CGFloat = 0.8

    private var isInputValid: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSend: Bool {
        isInputValid && !isThinking
    }

    var body: some View {
        VStack(spacing: 10) {
            Divider().opacity(0.5)

            if llmService.isDownloadingLocalModel {
                VStack(spacing: 6) {
                    HStack {
                        Label("Downloading Local Gemma 4 Model...", systemImage: "cpu")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                        Spacer()
                        Text("\(Int(llmService.localModelDownloadProgress * 100))%")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: llmService.localModelDownloadProgress)
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
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isFocused ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .overlay {
            if let onboarding, onboarding.currentStep == .chatCoCaptain && onboarding.showPopover {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                            onboardingGlowScale = 1.08
                            onboardingGlowOpacity = 0.0
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .popover(
            present: Binding(
                get: {
                    guard let onboarding else { return false }
                    return onboarding.currentStep == .chatCoCaptain && onboarding.showPopover
                },
                set: { newValue in
                    onboarding?.showPopover = newValue
                }
            ),
            attributes: { attributes in
                attributes.position = .absolute(
                    originAnchor: .top,
                    popoverAnchor: .bottom
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
                attributes.sourceFrameInset = UIEdgeInsets(top: -8, left: 0, bottom: 0, right: 0)
            }
        ) {
            if let step = onboarding?.currentStep {
                OnboardingPopoverCard(step: step) {
                    onboarding?.skip()
                }
            }
        }
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
