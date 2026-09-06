import AppKit
import SwiftUI

/// A keyboard-capable chat panel, separate from both the floating sprite and the hub.
final class AgentChatPanel: NSPanel {
    init(rootView: some View) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.preferredSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = NSHostingView(rootView: rootView)
        title = "Agent chat"
        setAccessibilityLabel("Agent chat")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    static let preferredSize = NSSize(width: 372, height: 510)

    /// Prefer beside the agent, falling back above it when neither side has room.
    static func frame(beside agent: NSRect, visibleFrame: NSRect) -> NSRect {
        let margin: CGFloat = 12
        let gap: CGFloat = 10
        let available = visibleFrame.insetBy(dx: margin, dy: margin)
        let size = NSSize(
            width: min(preferredSize.width, available.width),
            height: min(preferredSize.height, available.height)
        )
        let x: CGFloat
        let y: CGFloat
        if agent.minX - gap - size.width >= available.minX {
            x = agent.minX - gap - size.width
            y = agent.minY
        } else if agent.maxX + gap + size.width <= available.maxX {
            x = agent.maxX + gap
            y = agent.minY
        } else {
            x = agent.midX - size.width / 2
            y = agent.maxY + gap
        }
        return NSRect(
            x: min(max(x, available.minX), available.maxX - size.width),
            y: min(max(y, available.minY), available.maxY - size.height),
            width: size.width,
            height: size.height
        )
    }
}
