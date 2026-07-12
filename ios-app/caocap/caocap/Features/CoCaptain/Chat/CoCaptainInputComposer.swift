import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct CoCaptainInputComposer: View {
    @Binding var text: String
    @Binding var chatMode: CoCaptainChatMode
    @Binding var mentions: [CoCaptainNodeMention]
    @Binding var attachments: [CoCaptainAttachment]
    @FocusState.Binding var isFocused: Bool
    let store: ProjectStore?
    /// When false (node-scoped chat), inline cross-node @ suggestions are disabled.
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
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isPhotoPickerPresented = false
    @State private var isFileImporterPresented = false
    @State private var attachmentError: String?

    private var isInputValid: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
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

            if let attachmentError {
                Text(attachmentError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.primary.opacity(0.02))
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isContextVisible)
        .animation(.easeInOut(duration: 0.2), value: dictation.errorMessage)
        .onChange(of: dictation.transcript) { _, transcript in
            text = transcript
        }
        .onChange(of: text) { _, draft in
            mentions.removeAll { !draft.contains("@\($0.displayTitle)") }
        }
        .onDisappear {
            dictation.stop()
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true,
            onCompletion: importFiles
        )
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedPhotos,
            maxSelectionCount: 5,
            matching: .images
        )
        .onChange(of: selectedPhotos) { _, items in
            Task { await importPhotos(items) }
        }
    }

    /// Two-row capsule: tools on top, text + send below — one continuous composer surface.
    private var composerCapsule: some View {
        VStack(alignment: .leading, spacing: 8) {
            composerToolbar
            if !attachments.isEmpty { attachmentPreview }
            if !mentionSuggestions.isEmpty { mentionSuggestionList }
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
        .animation(.easeInOut(duration: 0.2), value: mentions)
        .animation(.easeInOut(duration: 0.2), value: attachments)
    }

    private var composerToolbar: some View {
        HStack(spacing: 8) {
            chatModePicker

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
            Button {
                isPhotoPickerPresented = true
            } label: {
                Label("Photos", systemImage: "photo.on.rectangle")
            }

            Button {
                isFileImporterPresented = true
            } label: {
                Label("Files", systemImage: "doc")
            }

            Divider()

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
        .accessibilityLabel("Add attachments or use a quick prompt")
        .simultaneousGesture(
            TapGesture().onEnded {
                isFocused = false
            }
        )
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

    private var activeMentionQuery: String? {
        guard allowsContextPinning,
              let atIndex = text.lastIndex(of: "@") else { return nil }
        let prefix = text[..<atIndex]
        if let last = prefix.last, !last.isWhitespace { return nil }
        let query = text[text.index(after: atIndex)...]
        guard !query.contains(where: { $0.isWhitespace || $0.isNewline }) else { return nil }
        return String(query)
    }

    private var mentionSuggestions: [SpatialNode] {
        guard let query = activeMentionQuery else { return [] }
        return pinnableNodes.filter {
            query.isEmpty || $0.displayTitle.localizedCaseInsensitiveContains(query)
        }.prefix(5).map { $0 }
    }

    private var mentionSuggestionList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(mentionSuggestions) { node in
                Button {
                    insertMention(node)
                } label: {
                    Label(node.displayTitle, systemImage: node.icon ?? node.type.defaultIcon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mention \(node.displayTitle)")
            }
        }
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private var attachmentPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    HStack(spacing: 6) {
                        Image(systemName: attachment.isImage ? "photo" : "doc")
                        Text(attachment.fileName).lineLimit(1)
                        Button {
                            attachments.removeAll { $0.id == attachment.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(attachment.fileName)")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1), in: Capsule())
                }
            }
        }
    }

    private func insertMention(_ node: SpatialNode) {
        guard let atIndex = text.lastIndex(of: "@") else { return }
        text.replaceSubrange(atIndex..<text.endIndex, with: "@\(node.displayTitle) ")
        if !mentions.contains(where: { $0.nodeID == node.id }) {
            mentions.append(CoCaptainNodeMention(nodeID: node.id, displayTitle: node.displayTitle))
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard attachments.count < 5 else {
                attachmentError = "You can attach up to 5 files per message."
                break
            }
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            guard data.count <= 10 * 1_024 * 1_024 else {
                attachmentError = "A selected photo is larger than 10 MB."
                continue
            }
            let type = item.supportedContentTypes.first
            attachments.append(
                CoCaptainAttachment(
                    fileName: "Photo \(attachments.count + 1).\(type?.preferredFilenameExtension ?? "jpg")",
                    mimeType: type?.preferredMIMEType ?? "image/jpeg",
                    data: data
                )
            )
        }
        selectedPhotos = []
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        do {
            for url in try result.get() {
                guard attachments.count < 5 else {
                    attachmentError = "You can attach up to 5 files per message."
                    break
                }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                guard data.count <= 10 * 1_024 * 1_024 else {
                    attachmentError = "\(url.lastPathComponent) is larger than 10 MB."
                    continue
                }
                let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
                attachments.append(
                    CoCaptainAttachment(
                        fileName: url.lastPathComponent,
                        mimeType: type?.preferredMIMEType ?? "application/octet-stream",
                        data: data
                    )
                )
            }
        } catch {
            attachmentError = error.localizedDescription
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
