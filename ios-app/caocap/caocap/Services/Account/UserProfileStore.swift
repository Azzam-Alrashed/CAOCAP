import Foundation

/// Local persistence for personalization survey answers and completion state.
final class UserProfileStore {
    private let defaults: UserDefaults

    private static let completedKey = "personalization_survey_completed_v1"
    private static let answersKey = "personalization_survey_answers_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isSurveyCompleted: Bool {
        get { defaults.bool(forKey: Self.completedKey) }
        set { defaults.set(newValue, forKey: Self.completedKey) }
    }

    func loadAnswers() -> PersonalizationSurveyAnswers? {
        guard let data = defaults.data(forKey: Self.answersKey) else { return nil }
        return try? JSONDecoder().decode(PersonalizationSurveyAnswers.self, from: data)
    }

    func saveAnswers(_ answers: PersonalizationSurveyAnswers) {
        guard let data = try? JSONEncoder().encode(answers) else { return }
        defaults.set(data, forKey: Self.answersKey)
    }

    func resetSurvey() {
        isSurveyCompleted = false
        defaults.removeObject(forKey: Self.answersKey)
    }
}
