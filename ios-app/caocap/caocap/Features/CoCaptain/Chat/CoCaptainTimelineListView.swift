import SwiftUI

/// A vertically scrolling list of all conversation items (messages, actions, reviews)
/// that auto-scrolls to the latest item when the assistant is typing or thinking.
struct CoCaptainTimelineListView: View {
    let viewModel: CoCaptainViewModel
    @Binding var lastScrollPosition: UUID?
    @FocusState.Binding var isFocused: Bool

    @State private var isPinnedToBottom = true

    private enum ScrollAnchor {
        static let bottom = "timeline_bottom"
    }

    var body: some View {
        ScrollViewReader { proxy in
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

                    Color.clear
                        .frame(height: 1)
                        .id(ScrollAnchor.bottom)
                }
                .padding()
                .scrollTargetLayout()
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .dismissKeyboardOnTap(isFocused: $isFocused)
            }
            .defaultScrollAnchor(.bottom)
            .interactiveKeyboardDismiss()
            .onScrollGeometryChange(for: Bool.self) { geometry in
                let distanceFromBottom = geometry.contentSize.height
                    - geometry.contentOffset.y
                    - geometry.containerSize.height
                return distanceFromBottom < 96
            } action: { _, nearBottom in
                isPinnedToBottom = nearBottom
            }
            .onChange(of: viewModel.items) {
                followBottomIfNeeded(proxy: proxy)
            }
            .onChange(of: viewModel.isThinking) {
                followBottomIfNeeded(proxy: proxy)
            }
            .onChange(of: viewModel.shouldPinToBottom) {
                if viewModel.shouldPinToBottom {
                    isPinnedToBottom = true
                    scrollToBottom(proxy: proxy)
                    viewModel.shouldPinToBottom = false
                }
            }
            .onChange(of: isFocused) { _, newValue in
                if newValue {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        isPinnedToBottom = true
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
            .onAppear {
                isPinnedToBottom = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    scrollToBottom(proxy: proxy)
                }
            }
        }
    }

    /// Follows new content only when the user is already near the bottom or just sent a message.
    private func followBottomIfNeeded(proxy: ScrollViewProxy) {
        guard isPinnedToBottom || viewModel.shouldPinToBottom else { return }
        scrollToBottom(proxy: proxy)
        viewModel.shouldPinToBottom = false
    }

    /// Scrolls to the bottom sentinel so content sits above the composer without a phantom gap.
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(ScrollAnchor.bottom, anchor: .bottom)
        }
    }
}
