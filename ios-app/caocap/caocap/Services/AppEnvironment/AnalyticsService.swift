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
