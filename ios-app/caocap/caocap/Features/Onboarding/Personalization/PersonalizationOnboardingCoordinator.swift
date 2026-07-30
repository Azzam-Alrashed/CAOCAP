import Foundation
import Observation

/// Tracks whether the temporary personalization placeholder should be presented.
@MainActor
@Observable
final class PersonalizationOnboardingCoordinator {
    private(set) var isCompleted: Bool

    @ObservationIgnored
    private let profileStore: UserProfileStore

    init(profileStore: UserProfileStore = UserProfileStore()) {
        self.profileStore = profileStore
        isCompleted = profileStore.isSurveyCompleted
    }

    var shouldPresent: Bool {
        !isCompleted
    }

    func complete() {
        isCompleted = true
        profileStore.isSurveyCompleted = true
    }

    func reset() {
        isCompleted = false
        profileStore.resetSurvey()
    }
}
