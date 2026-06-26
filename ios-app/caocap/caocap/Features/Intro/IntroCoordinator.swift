import Foundation
import Observation

/// Manages state and progression for the first-launch product intro tour.
/// Persistence is handled with `UserDefaults` so the tour is only shown once per install.
/// Resetting via `reset()` clears the flag, enabling re-presentation for testing or Settings.
@MainActor
@Observable
final class IntroCoordinator {
    /// The zero-based index of the step currently visible in the `TabView`.
    var currentIndex: Int = 0
    /// `true` once the user has either completed or skipped the intro on this device.
    private(set) var isCompleted: Bool

    @ObservationIgnored
    private let defaults: UserDefaults

    /// Versioned key so a future intro redesign can reset the flag for existing users.
    private static let completedKey = "intro_completed_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isCompleted = defaults.bool(forKey: Self.completedKey)
    }

    /// Whether the intro should be presented to this user right now.
    var shouldPresent: Bool {
        !isCompleted
    }

    /// `true` when the user is on the first step and the back button should be hidden or disabled.
    var isFirstPage: Bool {
        currentIndex == 0
    }

    /// `true` when the user is on the final step, so the CTA becomes a "finish" action.
    var isLastPage: Bool {
        currentIndex >= IntroManifest.lastIndex
    }

    /// Advances to the next step, or completes the intro if already on the last page.
    func next() {
        guard !isLastPage else {
            complete()
            return
        }

        currentIndex = min(currentIndex + 1, IntroManifest.lastIndex)
    }

    /// Steps back to the previous page. Clamps at 0 so it is always safe to call.
    func back() {
        currentIndex = max(currentIndex - 1, 0)
    }

    /// Skips the remaining steps and marks the intro as complete.
    func skip() {
        complete()
    }

    /// Persists the completion flag and resets the index so a future `reset()` + re-present
    /// always starts from the beginning.
    func complete() {
        isCompleted = true
        currentIndex = 0
        defaults.set(true, forKey: Self.completedKey)
    }

    /// Clears the completion flag so the intro will be shown again on the next `shouldPresent` check.
    /// Intended for Settings or debug flows.
    func reset() {
        isCompleted = false
        currentIndex = 0
        defaults.removeObject(forKey: Self.completedKey)
    }
}
