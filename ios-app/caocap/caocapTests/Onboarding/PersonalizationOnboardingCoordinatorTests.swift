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

    @Test func copilotStepDefaultsToCocaptain() {
        let coordinator = PersonalizationOnboardingCoordinator(
            profileStore: UserProfileStore(defaults: makeDefaults(suiteName: "PersonalizationOnboardingCoordinatorTests.continue")),
            analytics: NoOpAnalyticsService()
        )

        #expect(coordinator.selectedCopilot == .cocaptain)
    }

    @Test func nextAdvancesFromCopilotStepToSurvey() {
        let coordinator = PersonalizationOnboardingCoordinator(
            profileStore: UserProfileStore(defaults: makeDefaults(suiteName: "PersonalizationOnboardingCoordinatorTests.next")),
            analytics: NoOpAnalyticsService()
        )

        coordinator.next()

        #expect(coordinator.currentIndex == 1)
    }

    @Test func surveyStepAllowsContinueWithoutSelectionAndMarksUnanswered() {
        let coordinator = PersonalizationOnboardingCoordinator(
            profileStore: UserProfileStore(defaults: makeDefaults(suiteName: "PersonalizationOnboardingCoordinatorTests.survey")),
            analytics: NoOpAnalyticsService()
        )

        coordinator.currentIndex = 1

        coordinator.next()

        #expect(coordinator.currentIndex == 2)
        #expect(
            coordinator.selections["coding_level"] == PersonalizationSurveyAnswers.unansweredAnswerID
        )
        #expect(!coordinator.isAnswered(questionID: "coding_level"))
    }

    @Test func surveyStepStillAcceptsExplicitSelection() {
        let coordinator = PersonalizationOnboardingCoordinator(
            profileStore: UserProfileStore(defaults: makeDefaults(suiteName: "PersonalizationOnboardingCoordinatorTests.surveySelect")),
            analytics: NoOpAnalyticsService()
        )

        coordinator.currentIndex = 1
        coordinator.select(answerID: "complete_beginner", for: "coding_level")
        #expect(coordinator.isAnswered(questionID: "coding_level"))
    }

    @Test func lastStepShowsCompletionMoment() {
        let coordinator = PersonalizationOnboardingCoordinator(
            profileStore: UserProfileStore(defaults: makeDefaults(suiteName: "PersonalizationOnboardingCoordinatorTests.completion")),
            analytics: NoOpAnalyticsService()
        )

        coordinator.currentIndex = PersonalizationOnboardingManifest.lastIndex
        coordinator.select(answerID: "experiment_with_help", for: "learning_style")
        coordinator.next()

        #expect(coordinator.showCompletionMoment)
        #expect(coordinator.shouldPresent)
    }

    @Test func finishAfterCompletionMomentPersistsAnswersAndCopilot() {
        let defaults = makeDefaults(suiteName: "PersonalizationOnboardingCoordinatorTests.finish")
        let store = UserProfileStore(defaults: defaults)
        let coordinator = PersonalizationOnboardingCoordinator(
            profileStore: store,
            analytics: NoOpAnalyticsService()
        )

        coordinator.selectCopilot(.costar)
        coordinator.select(answerID: "complete_beginner", for: "coding_level")
        coordinator.finishAfterCompletionMoment()

        #expect(!coordinator.shouldPresent)
        #expect(store.isSurveyCompleted)

        let saved = store.loadAnswers()
        #expect(saved?.wasSkipped == false)
        #expect(saved?.selections["coding_level"] == "complete_beginner")
        #expect(saved?.selectedCopilot == .costar)
        #expect(saved?.surveyVersion == "v2")
    }

    @Test func confirmSkipMarksSurveyCompleteWithPartialAnswers() {
        let defaults = makeDefaults(suiteName: "PersonalizationOnboardingCoordinatorTests.skip")
        let store = UserProfileStore(defaults: defaults)
        let coordinator = PersonalizationOnboardingCoordinator(
            profileStore: store,
            analytics: NoOpAnalyticsService()
        )

        coordinator.currentIndex = 1
        coordinator.select(answerID: "some_basics", for: "coding_level")
        coordinator.confirmSkip()

        #expect(!coordinator.shouldPresent)
        #expect(store.isSurveyCompleted)

        let saved = store.loadAnswers()
        #expect(saved?.wasSkipped == true)
        #expect(saved?.selections["coding_level"] == "some_basics")
        #expect(saved?.selectedCopilot == .cocaptain)
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

    @Test func v1CompletedUserNeedsPresentationAgain() {
        let defaults = makeDefaults(suiteName: "PersonalizationOnboardingCoordinatorTests.v1")
        let store = UserProfileStore(defaults: defaults)
        store.isSurveyCompleted = true
        store.saveAnswers(
            PersonalizationSurveyAnswers(
                selections: ["coding_level": "experienced"],
                surveyVersion: "v1"
            )
        )

        let coordinator = PersonalizationOnboardingCoordinator(
            profileStore: store,
            analytics: NoOpAnalyticsService()
        )

        #expect(coordinator.shouldPresent)
        #expect(coordinator.selections["coding_level"] == "experienced")
    }
}
