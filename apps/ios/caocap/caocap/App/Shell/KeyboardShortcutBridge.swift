import SwiftUI

/// Captures hardware keyboard shortcuts on iPhone where `.commands` is ignored.
struct KeyboardShortcutBridge: View {
    let onOpenCommandPalette: () -> Void
    let onSummonCoCaptain: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void

    var body: some View {
        Group {
            Button("") { onOpenCommandPalette() }
                .keyboardShortcut("k", modifiers: .command)

            Button("") { onSummonCoCaptain() }
                .keyboardShortcut("j", modifiers: .command)

            Button("") { onUndo() }
                .keyboardShortcut("z", modifiers: .command)

            Button("") { onRedo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        .opacity(0)
        .allowsHitTesting(false)
        .frame(width: 0, height: 0)
    }
}
