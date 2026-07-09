import Foundation
import Observation

/// Drives the first-run personalization survey between intro and interactive tutorial.
@MainActor
@Observable
final class PersonalizationOnboardingCoordinator {
    var currentIndex: Int = 0
    var selections: [String: String] = [:]
    var selectedCopilot: CopilotPersona = .cocaptain
    var hasUserSelectedCopilot = false
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
        isCompleted = !Self.needsPresentation(profileStore: profileStore)

        if let saved = profileStore.loadAnswers() {
            selections = saved.selections
            selectedCopilot = saved.selectedCopilot ?? .cocaptain
        }
    }

    var shouldPresent: Bool {
        !isCompleted
    }

    var currentStep: PersonalizationStepKind {
        PersonalizationOnboardingManifest.step(at: currentIndex)
    }

    var currentQuestion: PersonalizationSurveyQuestion? {
        currentStep.surveyQuestion
    }

    var isFirstPage: Bool {
        currentIndex == 0
    }

    var isCopilotPickerStep: Bool {
        PersonalizationOnboardingManifest.isCopilotPickerStep(at: currentIndex)
    }

    var isLastStep: Bool {
        currentIndex >= PersonalizationOnboardingManifest.lastIndex
    }

    func isAnswered(questionID: String) -> Bool {
        guard let answerID = selections[questionID] else { return false }
        return answerID != PersonalizationSurveyAnswers.unansweredAnswerID
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

    func selectCopilot(_ persona: CopilotPersona) {
        selectedCopilot = persona
        hasUserSelectedCopilot = true
    }

    func select(answerID: String, for questionID: String? = nil) {
        let questionKey = questionID ?? currentQuestion?.id
        guard let questionKey else { return }
        selections[questionKey] = answerID
    }

    func next() {
        if PersonalizationOnboardingManifest.isCopilotPickerStep(at: currentIndex) {
            analytics.logEvent(
                PersonalizationSurveyAnalytics.copilotSelected,
                parameters: [
                    PersonalizationSurveyAnalytics.copilotID: selectedCopilot.rawValue,
                    PersonalizationSurveyAnalytics.surveyVersion: PersonalizationOnboardingManifest.surveyVersion
                ]
            )
        } else if let question = currentQuestion {
            if selections[question.id] == nil {
                selections[question.id] = PersonalizationSurveyAnswers.unansweredAnswerID
            }
            logAnsweredEvent(for: question, stepIndex: currentIndex)
        }

        if isLastStep {
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
        if currentIndex == 0 {
            hasUserSelectedCopilot = false
        }
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
                PersonalizationSurveyAnalytics.answersProvidedCount: String(PersonalizationSurveyAnswers(selections: selections).answeredSelectionCount),
                PersonalizationSurveyAnalytics.surveyVersion: PersonalizationOnboardingManifest.surveyVersion,
                PersonalizationSurveyAnalytics.copilotID: selectedCopilot.rawValue
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
                PersonalizationSurveyAnalytics.answersProvidedCount: String(PersonalizationSurveyAnswers(selections: selections).answeredSelectionCount),
                PersonalizationSurveyAnalytics.copilotID: selectedCopilot.rawValue
            ]
        )
        markCompleted()
    }

    func reset() {
        isCompleted = false
        currentIndex = 0
        selections = [:]
        selectedCopilot = .cocaptain
        hasUserSelectedCopilot = false
        showSkipConfirmation = false
        showCompletionMoment = false
        didLogSurveyStart = false
        profileStore.resetSurvey()
    }

    private static func needsPresentation(profileStore: UserProfileStore) -> Bool {
        guard profileStore.isSurveyCompleted else { return true }
        guard let answers = profileStore.loadAnswers() else { return true }
        return answers.surveyVersion != PersonalizationSurveyAnswers.currentSurveyVersion
    }

    private func persistAnswers(wasSkipped: Bool) {
        let answers = PersonalizationSurveyAnswers(
            selections: selections,
            completedAt: Date(),
            wasSkipped: wasSkipped,
            surveyVersion: PersonalizationOnboardingManifest.surveyVersion,
            selectedCopilot: selectedCopilot
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
