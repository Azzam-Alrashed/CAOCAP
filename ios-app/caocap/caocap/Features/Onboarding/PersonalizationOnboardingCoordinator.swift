import Foundation
import Observation

/// Drives the first-run personalization survey between intro and interactive tutorial.
@MainActor
@Observable
final class PersonalizationOnboardingCoordinator {
    var currentIndex: Int = 0
    var selections: [String: String] = [:]
    var showSkipConfirmation = false
    var showCompletionMoment = false

    private(set) var isCompleted: Bool
    private var didLogSurveyStart = false

    @ObservationIgnored
    private let profileStore: UserProfileStore

    @ObservationIgnored
    private let analytics: any AnalyticsTracking

    init(
        profileStore: UserProfileStore = UserProfileStore(),
        analytics: any AnalyticsTracking = AnalyticsService.shared
    ) {
        self.profileStore = profileStore
        self.analytics = analytics
        isCompleted = profileStore.isSurveyCompleted
    }

    var shouldPresent: Bool {
        !isCompleted
    }

    var currentQuestion: PersonalizationSurveyQuestion {
        PersonalizationOnboardingManifest.question(at: currentIndex)
    }

    var isFirstPage: Bool {
        currentIndex == 0
    }

    var isLastQuestionPage: Bool {
        currentIndex >= PersonalizationOnboardingManifest.lastIndex
    }

    var canContinue: Bool {
        selections[currentQuestion.id] != nil
    }

    var stepLabel: String {
        PersonalizationOnboardingManifest.stepLabel(for: currentIndex)
    }

    func selectedAnswerID(for questionID: String) -> String? {
        selections[questionID]
    }

    func onAppearIfNeeded() {
        guard shouldPresent, !didLogSurveyStart else { return }
        didLogSurveyStart = true
        analytics.logEvent(
            PersonalizationSurveyAnalytics.started,
            parameters: [PersonalizationSurveyAnalytics.surveyVersion: PersonalizationOnboardingManifest.surveyVersion]
        )
    }

    func select(answerID: String, for questionID: String? = nil) {
        let questionKey = questionID ?? currentQuestion.id
        selections[questionKey] = answerID
    }

    func next() {
        guard canContinue else { return }

        logAnsweredEvent(for: currentQuestion, stepIndex: currentIndex)

        if isLastQuestionPage {
            showCompletionMoment = true
            return
        }

        currentIndex = min(currentIndex + 1, PersonalizationOnboardingManifest.lastIndex)
    }

    func back() {
        guard !isFirstPage else { return }

        analytics.logEvent(
            PersonalizationSurveyAnalytics.back,
            parameters: [PersonalizationSurveyAnalytics.stepIndex: String(currentIndex)]
        )
        currentIndex = max(currentIndex - 1, 0)
    }

    func requestSkip() {
        showSkipConfirmation = true
    }

    func cancelSkip() {
        showSkipConfirmation = false
    }

    func confirmSkip() {
        showSkipConfirmation = false
        persistAnswers(wasSkipped: true)
        analytics.logEvent(
            PersonalizationSurveyAnalytics.skipped,
            parameters: [
                PersonalizationSurveyAnalytics.lastStepIndex: String(currentIndex),
                PersonalizationSurveyAnalytics.answersProvidedCount: String(selections.count),
                PersonalizationSurveyAnalytics.surveyVersion: PersonalizationOnboardingManifest.surveyVersion
            ]
        )
        markCompleted()
    }

    func finishAfterCompletionMoment() {
        showCompletionMoment = false
        persistAnswers(wasSkipped: false)
        analytics.logEvent(
            PersonalizationSurveyAnalytics.completed,
            parameters: [
                PersonalizationSurveyAnalytics.surveyVersion: PersonalizationOnboardingManifest.surveyVersion,
                PersonalizationSurveyAnalytics.answersProvidedCount: String(selections.count)
            ]
        )
        markCompleted()
    }

    func reset() {
        isCompleted = false
        currentIndex = 0
        selections = [:]
        showSkipConfirmation = false
        showCompletionMoment = false
        didLogSurveyStart = false
        profileStore.resetSurvey()
    }

    private func persistAnswers(wasSkipped: Bool) {
        let answers = PersonalizationSurveyAnswers(
            selections: selections,
            completedAt: Date(),
            wasSkipped: wasSkipped,
            surveyVersion: PersonalizationOnboardingManifest.surveyVersion
        )
        profileStore.saveAnswers(answers)
    }

    private func markCompleted() {
        isCompleted = true
        profileStore.isSurveyCompleted = true
        currentIndex = 0
        selections = [:]
    }

    private func logAnsweredEvent(for question: PersonalizationSurveyQuestion, stepIndex: Int) {
        guard let answerID = selections[question.id] else { return }
        analytics.logEvent(
            PersonalizationSurveyAnalytics.answered,
            parameters: [
                PersonalizationSurveyAnalytics.questionID: question.id,
                PersonalizationSurveyAnalytics.answerID: answerID,
                PersonalizationSurveyAnalytics.stepIndex: String(stepIndex),
                PersonalizationSurveyAnalytics.surveyVersion: PersonalizationOnboardingManifest.surveyVersion
            ]
        )
    }
}
