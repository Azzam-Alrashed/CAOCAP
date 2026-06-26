import SwiftUI

/// A vertically scrolling list of all conversation items (messages, actions, reviews)
/// that auto-scrolls to the latest item when the assistant is typing or thinking.
struct CoCaptainTimelineListView: View {
    let viewModel: CoCaptainViewModel
    @Binding var lastScrollPosition: UUID?
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.items) { item in
                            if !item.isEmptyAssistantMessage {
                                TimelineItemView(item: item, viewModel: viewModel)
                                    .id(item.id)
                            }
                        }

                        if viewModel.isAwaitingFirstResponse {
                            HStack(alignment: .bottom, spacing: 8) {
                                Image("cocaptain")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())
                                    .shadow(color: .blue.opacity(0.5), radius: 4, x: 0, y: 0)

                                ThinkingIndicator()
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                                Spacer()
                            }
                            .id("thinking_indicator")
                        }
                    }
                    .padding()
                    .scrollTargetLayout()
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
                    .dismissKeyboardOnTap(isFocused: $isFocused)
                }
                .scrollPosition(id: $lastScrollPosition)
                .interactiveKeyboardDismiss()
            .onChange(of: viewModel.items) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isThinking) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isFocused) { _, newValue in
                if newValue {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            .onAppear {
                restoreScrollPosition(proxy: proxy)
            }
            }
        }
    }

    /// Restores the scroll position when the view appears, falling back to the bottom
    /// if no previous scroll anchor was saved.
    private func restoreScrollPosition(proxy: ScrollViewProxy) {
        if let lastScrollPosition {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                withAnimation {
                    proxy.scrollTo(lastScrollPosition, anchor: .top)
                }
            }
        } else {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(200))
                scrollToBottom(proxy: proxy)
            }
        }
    }

    /// Animates the scroll view down to the newest item or the thinking indicator.
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if viewModel.isAwaitingFirstResponse {
            withAnimation {
                proxy.scrollTo("thinking_indicator", anchor: .bottom)
            }
        } else if let lastItem = viewModel.items.last {
            withAnimation {
                proxy.scrollTo(lastItem.id, anchor: .bottom)
            }
        }
    }
}
