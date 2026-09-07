import AppKit
import SwiftUI

/// Brings the existing CAOCAP window forward instead of opening another one.
enum MainWindowFocus {
    /// Focuses a visible, miniaturized, or hidden main window. Returns false if none exists.
    @discardableResult
    static func focusExisting() -> Bool {
        let windows = mainWindows()
        if let visible = windows.first(where: { $0.isVisible && !$0.isMiniaturized }) {
            visible.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return true
        }
        if let docked = windows.first(where: { $0.isMiniaturized }) {
            docked.deminiaturize(nil)
            NSApp.activate()
            return true
        }
        if let hidden = windows.first {
            hidden.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return true
        }
        return false
    }

    /// Focus the existing main window, or create the single main window if it was closed.
    static func reveal(openIfNeeded: OpenWindowAction) {
        if focusExisting() { return }
        openIfNeeded(id: "main")
        NSApp.activate()
    }

    private static func mainWindows() -> [NSWindow] {
        NSApp.windows.filter { window in
            guard !(window is CompanionPanel) else { return false }
            guard window.canBecomeMain else { return false }
            guard window.level == .normal else { return false }
            return true
        }
    }
}
