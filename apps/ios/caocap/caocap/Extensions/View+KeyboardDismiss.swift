import SwiftUI

extension View {
    /// Dismisses the keyboard when the user taps the background of this view,
    /// clearing the supplied `FocusState` binding. Uses a simultaneous gesture
    /// so child controls (buttons, rows, links) remain tappable.
    func dismissKeyboardOnTap(isFocused: FocusState<Bool>.Binding) -> some View {
        contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    isFocused.wrappedValue = false
                }
            )
    }

    /// Dismisses the keyboard when the user taps the background of this view,
    /// for surfaces that do not own a `FocusState` binding. Resigns the current
    /// first responder via `KeyboardDismisser`.
    func dismissKeyboardOnTap() -> some View {
        contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    KeyboardDismisser.dismiss()
                }
            )
    }

    /// Dismisses the keyboard interactively as the user scrolls.
    func interactiveKeyboardDismiss() -> some View {
        scrollDismissesKeyboard(.interactively)
    }
}
