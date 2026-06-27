import Foundation
import Testing
@testable import caocap

@MainActor
struct PersonalizationOnboardingCoordinatorTests {
    private func makeDefaults(suiteName: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func cannotContinueWithoutSelection() {
        let coordinator = PersonalizationOnboardingCoordinator(
            profileStore: UserProfileStore(defaults: makeDefaults(suiteName: "PersonalizationOnboardingCoordinatorTests.continue")),
            analytics: NoOpAnalyticsService()
        )

        #expect(!coordinator.canContinue)
    }

    @Test func nextRequiresSelectionAndAdvancesIndex() {
        let coordinator = PersonalizationOnboardingCoordinator(
            profileStore: UserProfileStore(defaults: makeDefaults(suiteName: "PersonalizationOnboardingCoordinatorTests.next")),
            analytics: NoOpAnalyticsService()
        )

        coordinator.select(answerID: "complete_beginner")
        coordinator.next()

        #expect(coordinator.currentIndex == 1)
    }

    @Test func lastQuestionShowsCompletionMoment() {
        let coordinator = PersonalizationOnboardingCoordinator(
            profileStore: UserProfileStore(defaults: makeDefaults(suiteName: "PersonalizationOnboardingCoordinatorTests.completion")),
            analytics: NoOpAnalyticsService()
        )

        coordinator.currentIndex = PersonalizationOnboardingManifest.lastIndex
        coordinator.select(answerID: "short_missions")
        coordinator.next()

        #expect(coordinator.showCompletionMoment)
        #expect(coordinator.shouldPresent)
    }

    @Test func finishAfterCompletionMomentPersistsAnswers() {
        let defaults = makeDefaults(suiteName: "PersonalizationOnboardingCoordinatorTests.finish")
        let store = UserProfileStore(defaults: defaults)
        let coordinator = PersonalizationOnboardingCoordinator(
            profileStore: store,
            analytics: NoOpAnalyticsService()
        )

        coordinator.select(answerID: "complete_beginner")
        coordinator.finishAfterCompletionMoment()

        #expect(!coordinator.shouldPresent)
        #expect(store.isSurveyCompleted)

        let saved = store.loadAnswers()
        #expect(saved?.wasSkipped == false)
        #expect(saved?.selections["coding_level"] == "complete_beginner")
    }

    @Test func confirmSkipMarksSurveyCompleteWithPartialAnswers() {
        let defaults = makeDefaults(suiteName: "PersonalizationOnboardingCoordinatorTests.skip")
        let store = UserProfileStore(defaults: defaults)
        let coordinator = PersonalizationOnboardingCoordinator(
            profileStore: store,
            analytics: NoOpAnalyticsService()
        )

        coordinator.select(answerID: "some_basics")
        coordinator.confirmSkip()

        #expect(!coordinator.shouldPresent)
        #expect(store.isSurveyCompleted)

        let saved = store.loadAnswers()
        #expect(saved?.wasSkipped == true)
        #expect(saved?.selections["coding_level"] == "some_basics")
    }

    @Test func backDecrementsIndexWhenNotOnFirstPage() {
        let coordinator = PersonalizationOnboardingCoordinator(
            profileStore: UserProfileStore(defaults: makeDefaults(suiteName: "PersonalizationOnboardingCoordinatorTests.back")),
            analytics: NoOpAnalyticsService()
        )

        coordinator.currentIndex = 2
        coordinator.back()

        #expect(coordinator.currentIndex == 1)
    }
}
