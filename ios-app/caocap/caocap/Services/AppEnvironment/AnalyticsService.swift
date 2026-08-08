import Foundation
import FirebaseAnalytics

/// Abstraction over analytics backends for testability.
protocol AnalyticsTracking: Sendable {
    func logEvent(_ name: String, parameters: [String: String]?)
}

/// Thin wrapper around Firebase Analytics for onboarding and product events.
struct AnalyticsService: AnalyticsTracking {
    static let shared = AnalyticsService()

    func logEvent(_ name: String, parameters: [String: String]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
}

/// No-op analytics for unit tests.
struct NoOpAnalyticsService: AnalyticsTracking {
    func logEvent(_ name: String, parameters: [String: String]?) {}
}

/// Stable event names and parameter keys for interactive onboarding analytics.
enum OnboardingAnalytics {
    static let lessonStarted = "onboarding_lesson_started"
    static let lessonCompleted = "onboarding_lesson_completed"
    static let lessonSkipped = "onboarding_lesson_skipped"
    static let stepCompleted = "onboarding_step_completed"

    static let lessonID = "lesson_id"
    static let stepID = "step_id"
}

/// Stable event names and parameter keys for the personalization survey.
enum PersonalizationSurveyAnalytics {
    static let started = "personalization_survey_started"
    static let answered = "personalization_survey_answered"
    static let completed = "personalization_survey_completed"
    static let skipped = "personalization_survey_skipped"
    static let back = "personalization_survey_back"
    static let copilotSelected = "personalization_copilot_selected"

    static let surveyVersion = "survey_version"
    static let copilotID = "copilot_id"
    static let questionID = "question_id"
    static let answerID = "answer_id"
    static let stepIndex = "step_index"
    static let lastStepIndex = "last_step_index"
    static let answersProvidedCount = "answers_provided_count"
}
