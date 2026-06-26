import UIKit

/// UIKit fallback for dismissing the keyboard on surfaces that present a
/// `TextEditor` or `TextField` without an owning `@FocusState` binding.
///
/// Prefer `View.dismissKeyboardOnTap(isFocused:)` whenever a parent already
/// tracks focus; this resigns whatever responder is currently first.
enum KeyboardDismisser {
    /// Resigns the first responder synchronously on the main thread,
    /// causing the software keyboard to retract.
    @MainActor
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
