import Foundation

/// Saved responses from the first-run personalization survey.
struct PersonalizationSurveyAnswers: Codable, Equatable {
    /// Manifest question identifier → selected answer identifier.
    var selections: [String: String]
    var completedAt: Date
    /// `true` when the user confirmed skip before answering every question.
    var wasSkipped: Bool
    /// Manifest version for future survey redesigns.
    var surveyVersion: String

    static let currentSurveyVersion = "v1"

    init(
        selections: [String: String] = [:],
        completedAt: Date = Date(),
        wasSkipped: Bool = false,
        surveyVersion: String = Self.currentSurveyVersion
    ) {
        self.selections = selections
        self.completedAt = completedAt
        self.wasSkipped = wasSkipped
        self.surveyVersion = surveyVersion
    }
}
