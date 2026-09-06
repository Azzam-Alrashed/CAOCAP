import SwiftUI

/// Desktop agent and chat affordance. Drag is handled by AppKit.
struct CompanionView: View {
    @Bindable var controller: CompanionController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var bobOffset: CGFloat = 0

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(controller.isChatPresented ? "Let's talk" : "Chat with me")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())

            Image(controller.persona.idleImageName)
                .resizable()
                .interpolation(.high)
                .frame(width: CompanionLayout.spriteSize, height: CompanionLayout.spriteSize)
                .offset(y: controller.isDragging ? 0 : bobOffset)
                .accessibilityLabel(controller.persona.displayName)
        }
        .padding(8)
        .frame(
            width: CompanionLayout.panelSize.width,
            height: CompanionLayout.panelSize.height,
            alignment: .bottomTrailing
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chat with \(controller.persona.displayName)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { controller.toggleChat() }
        .onAppear(perform: startIdleMotion)
        .onChange(of: reduceMotion) { _, reduced in
            if reduced {
                bobOffset = 0
            } else if !controller.isDragging {
                startIdleMotion()
            }
        }
        .onChange(of: controller.isDragging) { _, dragging in
            if dragging {
                bobOffset = 0
            } else if !reduceMotion {
                startIdleMotion()
            }
        }
    }

    private func startIdleMotion() {
        guard !reduceMotion, !controller.isDragging else {
            bobOffset = 0
            return
        }
        bobOffset = 0
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            bobOffset = -3
        }
    }
}
