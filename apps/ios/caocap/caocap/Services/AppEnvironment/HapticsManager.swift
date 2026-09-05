import SwiftUI
import UIKit

/// Centralises haptic feedback across the app, respecting the user's
/// enabled/intensity preferences stored in `AppStorage`.
///
/// All five `UIImpactFeedbackGenerator` styles are pre-warmed in `init` to
/// minimise latency on the first call.
@MainActor
public class HapticsManager {
    public static let shared = HapticsManager()

    /// When `false`, all feedback methods are silenced immediately.
    @AppStorage("haptics_enabled") private var hapticsEnabled = true
    /// User-selected intensity level: `"Subtle"`, `"Medium"` (default), or `"Sharp"`.
    /// This overrides the caller-requested style rather than scaling intensity.
    @AppStorage("haptics_intensity") private var hapticsIntensity = "Medium"

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)

    private init() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
        soft.prepare()
        rigid.prepare()
    }
    
    /// Fires an impact feedback event.
    ///
    /// The `hapticsIntensity` setting may override the requested `style`:
    /// - `"Subtle"` always uses `.light` regardless of `style`.
    /// - `"Sharp"` always uses `.rigid` regardless of `style`.
    /// - `"Medium"` (default) honours the caller-provided `style`.
    public func trigger(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard hapticsEnabled else { return }
        
        let adjustedStyle: UIImpactFeedbackGenerator.FeedbackStyle
        
        switch hapticsIntensity {
        case "Subtle":
            adjustedStyle = .light
        case "Sharp":
            adjustedStyle = .rigid
        default:
            adjustedStyle = style
        }
        
        switch adjustedStyle {
        case .light: light.impactOccurred()
        case .medium: medium.impactOccurred()
        case .heavy: heavy.impactOccurred()
        case .soft: soft.impactOccurred()
        case .rigid: rigid.impactOccurred()
        @unknown default:
            medium.impactOccurred()
        }
    }
    
    /// Fires a selection-changed feedback event.
    /// Suitable for momentary list or picker item selection changes.
    public func selectionChanged() {
        guard hapticsEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    /// Fires a notification-style feedback event (success, warning, or error).
    public func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
