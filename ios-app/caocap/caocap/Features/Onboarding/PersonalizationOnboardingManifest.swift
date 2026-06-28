import Foundation

/// A selectable answer for a personalization survey question.
struct PersonalizationSurveyOption: Equatable, Identifiable {
    let id: String
    let titleKey: String
}

/// One screen in the personalization onboarding survey.
struct PersonalizationSurveyQuestion: Equatable, Identifiable {
    let id: String
    let titleKey: String
    let subtitleKey: String
    let options: [PersonalizationSurveyOption]
}

/// Static catalogue of personalization survey questions.
enum PersonalizationOnboardingManifest {
    static let surveyVersion = PersonalizationSurveyAnswers.currentSurveyVersion

    static let questions: [PersonalizationSurveyQuestion] = [
        PersonalizationSurveyQuestion(
            id: "coding_level",
            titleKey: "personalization.coding_level.title",
            subtitleKey: "personalization.coding_level.subtitle",
            options: [
                PersonalizationSurveyOption(id: "complete_beginner", titleKey: "personalization.coding_level.complete_beginner"),
                PersonalizationSurveyOption(id: "some_basics", titleKey: "personalization.coding_level.some_basics"),
                PersonalizationSurveyOption(id: "comfortable_fundamentals", titleKey: "personalization.coding_level.comfortable_fundamentals"),
                PersonalizationSurveyOption(id: "experienced", titleKey: "personalization.coding_level.experienced")
            ]
        ),
        PersonalizationSurveyQuestion(
            id: "build_target",
            titleKey: "personalization.build_target.title",
            subtitleKey: "personalization.build_target.subtitle",
            options: [
                PersonalizationSurveyOption(id: "mobile_apps", titleKey: "personalization.build_target.mobile_apps"),
                PersonalizationSurveyOption(id: "web_apps", titleKey: "personalization.build_target.web_apps"),
                PersonalizationSurveyOption(id: "games", titleKey: "personalization.build_target.games"),
                PersonalizationSurveyOption(id: "personal_tools", titleKey: "personalization.build_target.personal_tools"),
                PersonalizationSurveyOption(id: "exploring", titleKey: "personalization.build_target.exploring")
            ]
        ),
        PersonalizationSurveyQuestion(
            id: "motivation",
            titleKey: "personalization.motivation.title",
            subtitleKey: "personalization.motivation.subtitle",
            options: [
                PersonalizationSurveyOption(id: "learn_from_scratch", titleKey: "personalization.motivation.learn_from_scratch"),
                PersonalizationSurveyOption(id: "build_without_devs", titleKey: "personalization.motivation.build_without_devs"),
                PersonalizationSurveyOption(id: "creative_skills", titleKey: "personalization.motivation.creative_skills"),
                PersonalizationSurveyOption(id: "teach_others", titleKey: "personalization.motivation.teach_others"),
                PersonalizationSurveyOption(id: "curious", titleKey: "personalization.motivation.curious")
            ]
        ),
        PersonalizationSurveyQuestion(
            id: "main_goal",
            titleKey: "personalization.main_goal.title",
            subtitleKey: "personalization.main_goal.subtitle",
            options: [
                PersonalizationSurveyOption(id: "ship_something_real", titleKey: "personalization.main_goal.ship_something_real"),
                PersonalizationSurveyOption(id: "understand_software", titleKey: "personalization.main_goal.understand_software"),
                PersonalizationSurveyOption(id: "build_confidence", titleKey: "personalization.main_goal.build_confidence"),
                PersonalizationSurveyOption(id: "have_fun", titleKey: "personalization.main_goal.have_fun"),
                PersonalizationSurveyOption(id: "career_prep", titleKey: "personalization.main_goal.career_prep")
            ]
        ),
        PersonalizationSurveyQuestion(
            id: "learning_style",
            titleKey: "personalization.learning_style.title",
            subtitleKey: "personalization.learning_style.subtitle",
            options: [
                PersonalizationSurveyOption(id: "build_first", titleKey: "personalization.learning_style.build_first"),
                PersonalizationSurveyOption(id: "step_by_step", titleKey: "personalization.learning_style.step_by_step"),
                PersonalizationSurveyOption(id: "big_picture", titleKey: "personalization.learning_style.big_picture"),
                PersonalizationSurveyOption(id: "experiment_with_help", titleKey: "personalization.learning_style.experiment_with_help"),
                PersonalizationSurveyOption(id: "short_missions", titleKey: "personalization.learning_style.short_missions")
            ]
        )
    ]

    static var lastIndex: Int {
        max(questions.count - 1, 0)
    }

    static func question(at index: Int) -> PersonalizationSurveyQuestion {
        questions[min(max(index, 0), lastIndex)]
    }

    static func stepLabel(for index: Int, language: String? = nil) -> String {
        LocalizationManager.shared.localizedString(
            "personalization.stepLabel",
            arguments: [index + 1, questions.count],
            language: language
        )
    }
}
