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
    /// Co-pilot chosen on the CDL picker step; nil for legacy v1 saves.
    var selectedCopilot: CopilotPersona?

    static let currentSurveyVersion = "v2"

    init(
        selections: [String: String] = [:],
        completedAt: Date = Date(),
        wasSkipped: Bool = false,
        surveyVersion: String = Self.currentSurveyVersion,
        selectedCopilot: CopilotPersona? = nil
    ) {
        self.selections = selections
        self.completedAt = completedAt
        self.wasSkipped = wasSkipped
        self.surveyVersion = surveyVersion
        self.selectedCopilot = selectedCopilot
    }
}
