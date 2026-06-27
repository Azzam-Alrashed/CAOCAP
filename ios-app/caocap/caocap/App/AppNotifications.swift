import Foundation

/// Notification names used to post app-level commands through `NotificationCenter`.
/// This pattern lets hardware-keyboard `.commands` (iPadOS/macCatalyst) and
/// hidden zero-size buttons (iPhone, where `.commands` is ignored) all funnel
/// into the same action bus without coupling the sources to the view.
extension Notification.Name {
    static let openCommandPalette = Notification.Name("openCommandPalette")
    static let summonCoCaptain = Notification.Name("summonCoCaptain")
    static let performUndo = Notification.Name("performUndo")
    static let performRedo = Notification.Name("performRedo")
}
