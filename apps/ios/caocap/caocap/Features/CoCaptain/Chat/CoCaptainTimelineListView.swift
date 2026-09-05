import SwiftUI

/// A vertically scrolling list of all conversation items (messages, actions, reviews)
/// that auto-scrolls to the latest item when the assistant is typing or thinking.
struct CoCaptainTimelineListView: View {
    let viewModel: CoCaptainViewModel
    @Binding var lastScrollPosition: UUID?
    @FocusState.Binding var isFocused: Bool

    @State private var isPinnedToBottom = true
    @State private var unseenItemCount = 0
    @State private var lastObservedItemID: UUID?
    @Environment(OnboardingCoordinator.self) private var onboarding: OnboardingCoordinator?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum ScrollAnchor {
        static let bottom = "timeline_bottom"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: CoCaptainChatStyle.sectionSpacing
                    ) {
                        if viewModel.isConversationArchiveLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text(
                                    LocalizationManager.shared.localizedString(
                                        "Loading conversations"
                                    )
                                )
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 180)
                            .accessibilityElement(children: .combine)
                        } else if showsWelcome {
                            CoCaptainWelcomeView(
                                projectName: viewModel.store?.projectName,
                                onPrompt: { prompt in
                                    viewModel.sendMessage(prompt)
                                }
                            )
                        } else {
                            ForEach(viewModel.items) { item in
                                if !item.isEmptyAssistantMessage {
                                    if let index = viewModel.items.firstIndex(where: { $0.id == item.id }),
                                       shouldShowDaySeparator(at: index) {
                                        daySeparator(for: item.createdAt)
                                    }
                                    TimelineItemView(item: item, viewModel: viewModel)
                                        .id(item.id)
                                }
                            }
                        }

                        if let progressPhase = viewModel.progressPhase {
                            HStack(alignment: .bottom, spacing: 8) {
                                CopilotAvatarView(size: 28)
                                    .accessibilityHidden(true)

                                CoCaptainProgressView(phase: progressPhase)

                                Spacer()
                            }
                            .id("thinking_indicator")
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(ScrollAnchor.bottom)
                    }
                    .padding(.horizontal, CoCaptainChatStyle.sectionSpacing)
                    .padding(.vertical, CoCaptainChatStyle.standardSpacing)
                    .scrollTargetLayout()
                    .frame(maxWidth: 720, alignment: .topLeading)
                    .frame(maxWidth: .infinity)
                    .dismissKeyboardOnTap(isFocused: $isFocused)
                }
                .defaultScrollAnchor(showsWelcome ? .top : .bottom)
                .interactiveKeyboardDismiss()
                .scrollPosition(id: $lastScrollPosition)

                if !isPinnedToBottom {
                    Button {
                        isPinnedToBottom = true
                        unseenItemCount = 0
                        scrollToBottom(proxy: proxy)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down")
                            Text(LocalizationManager.shared.localizedString("Latest"))
                            if unseenItemCount > 0 {
                                Text("\(unseenItemCount)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.accentColor, in: Capsule())
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(minHeight: CoCaptainChatStyle.minimumHitSize)
                        .background(.regularMaterial, in: Capsule())
                        .overlay {
                            Capsule().stroke(CoCaptainChatStyle.subtleStroke)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                    .accessibilityLabel(
                        LocalizationManager.shared.localizedString("Jump to latest")
                    )
                }
            }
            .onChange(of: viewModel.items.last) {
                followBottomIfNeeded(proxy: proxy)
            }
            .onChange(of: viewModel.items.last?.id) { _, itemID in
                guard let itemID else { return }
                defer { lastObservedItemID = itemID }
                guard lastObservedItemID != nil,
                      lastObservedItemID != itemID,
                      !isPinnedToBottom else {
                    return
                }
                unseenItemCount += 1
            }
            .onChange(of: viewModel.progressPhase) {
                followBottomIfNeeded(proxy: proxy)
            }
            .onChange(of: viewModel.shouldPinToBottom) {
                if viewModel.shouldPinToBottom {
                    isPinnedToBottom = true
                    unseenItemCount = 0
                    scrollToBottom(proxy: proxy)
                    viewModel.shouldPinToBottom = false
                }
            }
            .onChange(of: isFocused) { _, newValue in
                if newValue {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        isPinnedToBottom = true
                        unseenItemCount = 0
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            .onChange(of: viewModel.scrollFocusRequest) { _, position in
                guard let position else { return }
                isPinnedToBottom = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    proxy.scrollTo(position, anchor: .center)
                }
                viewModel.scrollFocusRequest = nil
            }
            .onChange(of: lastScrollPosition) { _, position in
                isPinnedToBottom = position == nil
                    || position == viewModel.bottomTimelineItemID
                if isPinnedToBottom {
                    unseenItemCount = 0
                }
                viewModel.updateLastScrollPosition(position)
            }
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    if showsWelcome {
                        isPinnedToBottom = true
                        lastObservedItemID = nil
                        return
                    }
                    if let lastScrollPosition {
                        isPinnedToBottom = lastScrollPosition == viewModel.bottomTimelineItemID
                        proxy.scrollTo(lastScrollPosition, anchor: .center)
                    } else {
                        isPinnedToBottom = true
                        scrollToBottom(proxy: proxy)
                    }
                    lastObservedItemID = viewModel.items.last?.id
                }
            }
        }
    }

    private var showsWelcome: Bool {
        !viewModel.hasUserMessages
            && viewModel.items.isEmpty
            && onboarding?.currentStep == nil
    }

    private func shouldShowDaySeparator(at index: Int) -> Bool {
        guard index > 0 else { return false }
        let previous = viewModel.items[index - 1].createdAt
        let current = viewModel.items[index].createdAt
        return !Calendar.current.isDate(previous, inSameDayAs: current)
    }

    private func daySeparator(for date: Date) -> some View {
        HStack {
            Divider()
            Text(date, format: .dateTime.month(.abbreviated).day())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
            Divider()
        }
        .accessibilityElement(children: .combine)
    }

    /// Follows new content only when the user is already near the bottom or just sent a message.
    private func followBottomIfNeeded(proxy: ScrollViewProxy) {
        guard isPinnedToBottom || viewModel.shouldPinToBottom else { return }
        scrollToBottom(proxy: proxy)
        viewModel.shouldPinToBottom = false
    }

    /// Scrolls to the bottom sentinel so content sits above the composer without a phantom gap.
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo(ScrollAnchor.bottom, anchor: .bottom)
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(ScrollAnchor.bottom, anchor: .bottom)
            }
        }
    }
}

private struct CoCaptainWelcomeView: View {
    let projectName: String?
    let onPrompt: (String) -> Void

    private struct Starter: Identifiable {
        let title: String
        let icon: String
        let prompt: String
        var id: String { title }
    }

    private let starters: [Starter] = [
        Starter(
            title: "Understand this canvas",
            icon: "scope",
            prompt: "Summarize the current canvas and explain how its pieces work together."
        ),
        Starter(
            title: "Find the next step",
            icon: "arrow.right.circle",
            prompt: "Suggest the most useful next improvement for this project."
        ),
        Starter(
            title: "Review for issues",
            icon: "checklist",
            prompt: "Review the current canvas for obvious issues, missing pieces, or polish opportunities."
        ),
        Starter(
            title: "Teach me something",
            icon: "lightbulb",
            prompt: "Teach me one useful software concept using this project as the example."
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: CoCaptainChatStyle.largeSpacing) {
            CopilotAvatarView(size: 54)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizationManager.shared.localizedString("Build with CoCaptain"))
                    .font(.title2.bold())
                Text(welcomeMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: CoCaptainChatStyle.smallSpacing) {
                ForEach(starters) { starter in
                    Button {
                        onPrompt(
                            LocalizationManager.shared.localizedString(starter.prompt)
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: starter.icon)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.accentColor, in: Circle())
                            Text(LocalizationManager.shared.localizedString(starter.title))
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.forward")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, CoCaptainChatStyle.standardSpacing)
                        .frame(minHeight: 56)
                        .coCaptainCardSurface()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: 560, alignment: .leading)
        .padding(.vertical, 20)
    }

    private var welcomeMessage: String {
        guard let projectName, !projectName.isEmpty else {
            return LocalizationManager.shared.localizedString(
                "Ask a question, make a plan, or propose a change. You stay in control."
            )
        }
        return LocalizationManager.shared.localizedString(
            "I can help you understand, plan, and improve %@. Every canvas change still waits for your approval.",
            arguments: [projectName]
        )
    }
}

private struct CoCaptainProgressView: View {
    let phase: CoCaptainProgressPhase

    var body: some View {
        HStack(spacing: CoCaptainChatStyle.smallSpacing) {
            ThinkingIndicator()
            Text(phase.localizedTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(phase.localizedTitle)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
