import Foundation

enum HelpTutorialAction: Hashable {
    case restartInteractiveTutorial
}

struct HelpTutorialItem: Identifiable, Hashable {
    let id: HelpTutorialAction
    let titleKey: String
    let subtitleKey: String
    let icon: String
    let colorName: String
}

struct HelpArticle: Identifiable, Hashable {
    let id: String
    let titleKey: String
    let subtitleKey: String
    let icon: String
    let bodyParagraphKeys: [String]
}

/// Static catalogue for the in-app help center.
enum HelpManifest {
    static let supportURL = URL(string: "https://www.azzam.ai/caocap/support")!

    static let tutorials: [HelpTutorialItem] = []

    static let articles: [HelpArticle] = [
        HelpArticle(
            id: "nextSteps",
            titleKey: "help.article.nextSteps.title",
            subtitleKey: "help.article.nextSteps.subtitle",
            icon: "flag.checkered",
            bodyParagraphKeys: [
                "help.article.nextSteps.body1",
                "help.article.nextSteps.body2",
                "help.article.nextSteps.body3"
            ]
        ),
        HelpArticle(
            id: "canvas",
            titleKey: "help.article.canvas.title",
            subtitleKey: "help.article.canvas.subtitle",
            icon: "square.grid.2x2",
            bodyParagraphKeys: [
                "help.article.canvas.body1",
                "help.article.canvas.body2"
            ]
        ),
        HelpArticle(
            id: "cocaptain",
            titleKey: "help.article.cocaptain.title",
            subtitleKey: "help.article.cocaptain.subtitle",
            icon: "sparkles",
            bodyParagraphKeys: [
                "help.article.cocaptain.body1",
                "help.article.cocaptain.body2",
                "help.article.cocaptain.body3"
            ]
        )
    ]
}
