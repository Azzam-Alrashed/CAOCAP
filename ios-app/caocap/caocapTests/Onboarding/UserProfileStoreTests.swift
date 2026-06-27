import Foundation
import Testing
@testable import caocap

struct UserProfileStoreTests {
    @Test func saveAndLoadAnswersRoundTrip() {
        let defaults = UserDefaults(suiteName: "UserProfileStoreTests.save")!
        defaults.removePersistentDomain(forName: "UserProfileStoreTests.save")
        let store = UserProfileStore(defaults: defaults)

        let answers = PersonalizationSurveyAnswers(
            selections: [
                "coding_level": "complete_beginner",
                "build_target": "mobile_apps"
            ],
            completedAt: Date(timeIntervalSince1970: 1_700_000_000),
            wasSkipped: false
        )

        store.saveAnswers(answers)
        store.isSurveyCompleted = true

        #expect(store.isSurveyCompleted)
        #expect(store.loadAnswers() == answers)
    }

    @Test func resetSurveyClearsCompletionAndAnswers() {
        let defaults = UserDefaults(suiteName: "UserProfileStoreTests.reset")!
        defaults.removePersistentDomain(forName: "UserProfileStoreTests.reset")
        let store = UserProfileStore(defaults: defaults)

        store.saveAnswers(PersonalizationSurveyAnswers(selections: ["coding_level": "experienced"]))
        store.isSurveyCompleted = true

        store.resetSurvey()

        #expect(!store.isSurveyCompleted)
        #expect(store.loadAnswers() == nil)
    }
}
