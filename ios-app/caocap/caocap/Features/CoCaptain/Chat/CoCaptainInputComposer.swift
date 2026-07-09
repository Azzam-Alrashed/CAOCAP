import SwiftUI

struct CoCaptainInputComposer: View {
    @Binding var text: String
    @Binding var chatMode: CoCaptainChatMode
    @Binding var pinnedContextNodeID: UUID?
    @FocusState.Binding var isFocused: Bool
    let store: ProjectStore?
    /// When false (node-scoped chat), the @ pin control is hidden.
    let allowsContextPinning: Bool
    let pinnableNodes: [SpatialNode]
    let isThinking: Bool
    let analysisItems: [ProjectSuggestion]
    let pendingReviewCount: Int
    let onSend: () -> Void
    let onStop: () -> Void
    let onQuickPrompt: (String) -> Void
    let onFocusPendingReviews: () -> Void
    let onApplySuggestion: (ProjectSuggestion) -> Void
    let onDismissSuggestion: (ProjectSuggestion) -> Void
    
    @Environment(OnboardingCoordinator.self) private var onboarding: OnboardingCoordinator?
    @AppStorage("app.dictationLocale") private var dictationLocaleRawValue = DictationLocaleOption.auto.rawValue
    @State private var localModelManager = LocalMLXModelManager.shared
    /// Dictation manager for streaming microphone input and converting it to query text.
    @State private var dictation = DictationController()
    @State private var isContextVisible = false

    private var isInputValid: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSend: Bool {
        isInputValid && !isThinking
    }

    /// Grows with wrapped/newline content; scrolls once the user exceeds this.
    private static let composerLineLimit = 1...6

    private var composerNewlineCount: Int {
        text.reduce(0) { partial, character in
            character.isNewline ? partial + 1 : partial
        }
    }

    private var isChatOnboardingActive: Bool {
        guard let onboarding else { return false }
        return (onboarding.currentStep == .chatCoCaptain || onboarding.currentStep == .chatCoCaptainGameEdit)
            && onboarding.showPopover
    }

    /// Resolves the current user-selected or automatic dictation locale.
    private var dictationLocaleOption: DictationLocaleOption {
        DictationLocaleOption(rawValue: dictationLocaleRawValue) ?? .auto
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

            if isContextVisible, let store {
                ContextPill(
                    projectName: store.projectName,
                    fileName: store.fileName,
                    nodeCount: store.nodes.count
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            composerCapsule
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            if let errorMessage = dictation.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .background(Color.primary.opacity(0.02))
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isContextVisible)
        .animation(.easeInOut(duration: 0.2), value: dictation.errorMessage)
        .onChange(of: dictation.transcript) { _, transcript in
            text = transcript
        }
        .onDisappear {
            dictation.stop()
        }
    }

    /// Two-row capsule: tools on top, text + send below — one continuous composer surface.
    private var composerCapsule: some View {
        VStack(alignment: .leading, spacing: 8) {
            composerToolbar
            composerInputRow
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isChatOnboardingActive || isFocused
                        ? Color.blue.opacity(isChatOnboardingActive ? 0.55 : 0.3)
                        : Color.primary.opacity(0.06),
                    lineWidth: isChatOnboardingActive || isFocused ? 1.5 : 1
                )
        )
        .onboardingTooltipAnchor(.coCaptainInput)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .animation(.easeInOut(duration: 0.2), value: isChatOnboardingActive)
        .animation(.easeInOut(duration: 0.2), value: chatMode)
        .animation(.easeInOut(duration: 0.2), value: pinnedContextNodeID)
    }

    private var composerToolbar: some View {
        HStack(spacing: 8) {
            chatModePicker

            if allowsContextPinning {
                contextPinControl
            }

            Spacer(minLength: 4)

            quickPromptMenu
        }
    }

    private var composerInputRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(chatMode.composerPlaceholder, text: $text, axis: .vertical)
                .lineLimit(Self.composerLineLimit)
                // Expand with wrapped/newline content up to `composerLineLimit`, then scroll.
                .fixedSize(horizontal: false, vertical: true)
                .focused($isFocused)
                // Return inserts a newline so the capsule can grow; send via the button.
                .submitLabel(.return)
                .padding(.leading, 4)
                .padding(.vertical, 6)

            sendButton
        }
        .animation(.easeInOut(duration: 0.15), value: composerNewlineCount)
    }

    private var quickPromptMenu: some View {
        Menu {
            if store != nil {
                Button {
                    isContextVisible.toggle()
                } label: {
                    Label(
                        isContextVisible ? "Hide Canvas Context" : "Show Canvas Context",
                        systemImage: "scope"
                    )
                }
                .disabled(isThinking)

                Divider()
            }

            if pendingReviewCount > 0 {
                Button {
                    onFocusPendingReviews()
                } label: {
                    Label(
                        LocalizationManager.shared.localizedString(
                            "Show Pending Reviews (%lld)",
                            arguments: [Int64(pendingReviewCount)]
                        ),
                        systemImage: "tray.full"
                    )
                }
                .disabled(isThinking)

                Divider()
            }

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
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                )
        }
        .accessibilityLabel("Quick prompts")
        .simultaneousGesture(
            TapGesture().onEnded {
                isFocused = false
            }
        )
    }

    private var pinnedNode: SpatialNode? {
        guard let pinnedContextNodeID else { return nil }
        return pinnableNodes.first(where: { $0.id == pinnedContextNodeID })
            ?? store?.nodes.first(where: { $0.id == pinnedContextNodeID })
    }

    /// Compact Agent/Ask/Plan control on the composer toolbar.
    private var chatModePicker: some View {
        Menu {
            ForEach(CoCaptainChatMode.allCases) { mode in
                Button {
                    chatMode = mode
                } label: {
                    if mode == chatMode {
                        Label(mode.displayName, systemImage: "checkmark")
                    } else {
                        Label(mode.displayName, systemImage: mode.systemImageName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: chatMode.systemImageName)
                    .font(.system(size: 11, weight: .semibold))
                Text(chatMode.displayName)
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.08))
            )
        }
        .accessibilityLabel(
            LocalizationManager.shared.localizedString("cocaptain.composer.modeAccessibility")
        )
        .accessibilityValue(chatMode.displayName)
        .disabled(isThinking)
        .simultaneousGesture(
            TapGesture().onEnded {
                isFocused = false
            }
        )
    }

    /// Compact @ pin for project-scope turns — focuses prompt context on one node.
    @ViewBuilder
    private var contextPinControl: some View {
        if let pinned = pinnedNode {
            HStack(spacing: 4) {
                Image(systemName: "at")
                    .font(.system(size: 11, weight: .semibold))
                Text(pinned.displayTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Button {
                    pinnedContextNodeID = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    LocalizationManager.shared.localizedString("cocaptain.composer.clearContextPin")
                )
            }
            .foregroundStyle(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.blue.opacity(0.12))
            )
            .layoutPriority(-1)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                LocalizationManager.shared.localizedString("cocaptain.composer.contextPinAccessibility")
            )
            .accessibilityValue(pinned.displayTitle)
            .disabled(isThinking)
        } else {
            Menu {
                if pinnableNodes.isEmpty {
                    Text(LocalizationManager.shared.localizedString("cocaptain.composer.noNodesToPin"))
                } else {
                    ForEach(pinnableNodes) { node in
                        Button {
                            pinnedContextNodeID = node.id
                        } label: {
                            Label(node.displayTitle, systemImage: node.icon ?? node.type.defaultIcon)
                        }
                    }
                }
            } label: {
                Image(systemName: "at")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.08))
                    )
            }
            .accessibilityLabel(
                LocalizationManager.shared.localizedString("cocaptain.composer.contextPinAccessibility")
            )
            .disabled(isThinking || pinnableNodes.isEmpty)
            .simultaneousGesture(
                TapGesture().onEnded {
                    isFocused = false
                }
            )
        }
    }

    private var sendButton: some View {
        Button(action: {
            if isThinking {
                onStop()
            } else if dictation.isRecording {
                dictation.stop()
            } else if isInputValid {
                onSend()
            } else {
                isFocused = false
                Task {
                    await dictation.start(initialText: text, localeOption: dictationLocaleOption)
                }
            }
        }) {
            ZStack {
                Circle()
                    .fill(sendButtonBackground)
                    .frame(width: 32, height: 32)

                if isThinking {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11, weight: .bold))
                        .transition(.scale.combined(with: .opacity))
                } else if dictation.isRecording {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .transition(.scale.combined(with: .opacity))
                } else if isInputValid {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .foregroundStyle(sendButtonForeground)
        }
        .accessibilityLabel(sendButtonAccessibilityLabel)
        .contextMenu {
            if !isInputValid || dictation.isRecording {
                dictationLocaleMenu
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isInputValid)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isThinking)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dictation.isRecording)
    }

    private var sendButtonBackground: Color {
        if dictation.isRecording {
            return .red.opacity(0.15)
        }
        if isThinking || isInputValid {
            return .blue
        }
        return Color.primary.opacity(0.08)
    }

    private var sendButtonForeground: Color {
        if dictation.isRecording {
            return .red
        }
        if isThinking || isInputValid {
            return .white
        }
        return .secondary
    }

    @ViewBuilder
    private var dictationLocaleMenu: some View {
        ForEach(DictationLocaleOption.allCases) { option in
            Button {
                if dictation.isRecording {
                    dictation.stop()
                }
                dictationLocaleRawValue = option.rawValue
            } label: {
                if option == dictationLocaleOption {
                    Label(option.displayName, systemImage: "checkmark")
                } else {
                    Label(option.displayName, systemImage: option.systemImageName)
                }
            }
        }
    }

    private var sendButtonAccessibilityLabel: String {
        if isThinking {
            "Stop CoCaptain"
        } else if dictation.isRecording {
            "Stop dictation"
        } else if isInputValid {
            "Send message"
        } else {
            "Start dictation"
        }
    }
}
