import SwiftUI

/// Desktop pet content: Ready bubble, idle sprite, drag to move, click to open.
struct CompanionView: View {
    @Bindable var controller: CompanionController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var bobOffset: CGFloat = 0
    @State private var dragOrigin: CGPoint?

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("Ready")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())

            Image("CoCaptainIdle")
                .resizable()
                .interpolation(.high)
                .frame(width: CompanionLayout.spriteSize, height: CompanionLayout.spriteSize)
                .offset(y: bobOffset)
                .accessibilityLabel("CoCaptain")
        }
        .padding(8)
        .frame(
            width: CompanionLayout.panelSize.width,
            height: CompanionLayout.panelSize.height,
            alignment: .bottomTrailing
        )
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .onAppear(perform: startIdleMotion)
        .onChange(of: reduceMotion) { _, reduced in
            if reduced {
                bobOffset = 0
            } else {
                startIdleMotion()
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragOrigin == nil {
                    dragOrigin = controller.origin
                }
                guard let start = dragOrigin else { return }
                // SwiftUI Y grows downward; AppKit window origins grow upward.
                controller.move(
                    to: NSPoint(
                        x: start.x + value.translation.width,
                        y: start.y - value.translation.height
                    )
                )
            }
            .onEnded { value in
                let distance = hypot(value.translation.width, value.translation.height)
                if distance < CompanionLayout.clickSlop {
                    controller.openMainWindow()
                } else {
                    controller.persistOrigin()
                }
                dragOrigin = nil
            }
    }

    private func startIdleMotion() {
        guard !reduceMotion else {
            bobOffset = 0
            return
        }
        bobOffset = 0
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            bobOffset = -3
        }
    }
}
