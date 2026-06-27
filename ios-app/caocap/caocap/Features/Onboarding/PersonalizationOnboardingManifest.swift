import Foundation

/// A selectable answer for a personalization survey question.
struct PersonalizationSurveyOption: Equatable, Identifiable {
    let id: String
    let title: String
}

/// One screen in the personalization onboarding survey.
struct PersonalizationSurveyQuestion: Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let options: [PersonalizationSurveyOption]
}

/// Static catalogue of personalization survey questions.
enum PersonalizationOnboardingManifest {
    static let surveyVersion = PersonalizationSurveyAnswers.currentSurveyVersion

    static let questions: [PersonalizationSurveyQuestion] = [
        PersonalizationSurveyQuestion(
            id: "coding_level",
            title: "What's your coding level?",
            subtitle: "Before we launch, help us chart your course.",
            options: [
                PersonalizationSurveyOption(id: "complete_beginner", title: "Complete beginner"),
                PersonalizationSurveyOption(id: "some_basics", title: "I know some basics"),
                PersonalizationSurveyOption(id: "comfortable_fundamentals", title: "Comfortable with fundamentals"),
                PersonalizationSurveyOption(id: "experienced", title: "Experienced developer")
            ]
        ),
        PersonalizationSurveyQuestion(
            id: "build_target",
            title: "What do you want to build?",
            subtitle: "Every mission needs a destination.",
            options: [
                PersonalizationSurveyOption(id: "mobile_apps", title: "Mobile apps"),
                PersonalizationSurveyOption(id: "web_apps", title: "Web apps"),
                PersonalizationSurveyOption(id: "games", title: "Games and interactive experiences"),
                PersonalizationSurveyOption(id: "personal_tools", title: "Tools for myself"),
                PersonalizationSurveyOption(id: "exploring", title: "Not sure yet — I want to explore")
            ]
        ),
        PersonalizationSurveyQuestion(
            id: "motivation",
            title: "Why are you here?",
            subtitle: "Your reason shapes the journey ahead.",
            options: [
                PersonalizationSurveyOption(id: "learn_from_scratch", title: "Learn to code from scratch"),
                PersonalizationSurveyOption(id: "build_without_devs", title: "Build my ideas without hiring a developer"),
                PersonalizationSurveyOption(id: "creative_skills", title: "Level up my creative skills"),
                PersonalizationSurveyOption(id: "teach_others", title: "Teach or mentor others"),
                PersonalizationSurveyOption(id: "curious", title: "Just curious")
            ]
        ),
        PersonalizationSurveyQuestion(
            id: "main_goal",
            title: "What's your main goal?",
            subtitle: "Keep your north star in sight.",
            options: [
                PersonalizationSurveyOption(id: "ship_something_real", title: "Ship something real I can show people"),
                PersonalizationSurveyOption(id: "understand_software", title: "Understand how software works"),
                PersonalizationSurveyOption(id: "build_confidence", title: "Become confident enough to keep building"),
                PersonalizationSurveyOption(id: "have_fun", title: "Have fun while learning"),
                PersonalizationSurveyOption(id: "career_prep", title: "Prepare for a career change")
            ]
        ),
        PersonalizationSurveyQuestion(
            id: "learning_style",
            title: "How do you prefer to learn?",
            subtitle: "We'll match the pace to your style.",
            options: [
                PersonalizationSurveyOption(id: "build_first", title: "By doing — build first, understand later"),
                PersonalizationSurveyOption(id: "step_by_step", title: "Step-by-step guidance"),
                PersonalizationSurveyOption(id: "big_picture", title: "Seeing the big picture, then details"),
                PersonalizationSurveyOption(id: "experiment_with_help", title: "Experimenting freely with help when I'm stuck"),
                PersonalizationSurveyOption(id: "short_missions", title: "Short focused missions")
            ]
        )
    ]

    static var lastIndex: Int {
        max(questions.count - 1, 0)
    }

    static func question(at index: Int) -> PersonalizationSurveyQuestion {
        questions[min(max(index, 0), lastIndex)]
    }

    static func stepLabel(for index: Int) -> String {
        "Question \(index + 1) of \(questions.count)"
    }
}
