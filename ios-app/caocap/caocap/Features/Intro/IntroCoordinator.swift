import Foundation
import Observation

@MainActor
@Observable
final class IntroCoordinator {
    var currentIndex: Int = 0
    private(set) var isCompleted: Bool

    @ObservationIgnored
    private let defaults: UserDefaults

    private static let completedKey = "intro_completed_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isCompleted = defaults.bool(forKey: Self.completedKey)
    }

    var shouldPresent: Bool {
        !isCompleted
    }

    var isFirstPage: Bool {
        currentIndex == 0
    }

    var isLastPage: Bool {
        currentIndex >= IntroManifest.lastIndex
    }

    func next() {
        guard !isLastPage else {
            complete()
            return
        }

        currentIndex = min(currentIndex + 1, IntroManifest.lastIndex)
    }

    func back() {
        currentIndex = max(currentIndex - 1, 0)
    }

    func skip() {
        complete()
    }

    func complete() {
        isCompleted = true
        currentIndex = 0
        defaults.set(true, forKey: Self.completedKey)
    }

    func reset() {
        isCompleted = false
        currentIndex = 0
        defaults.removeObject(forKey: Self.completedKey)
    }
}
