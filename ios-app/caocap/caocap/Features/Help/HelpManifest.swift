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

struct HelpShortcutItem: Identifiable, Hashable {
    let id: String
    let titleKey: String
    let examplePhraseKey: String
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

    static let tutorials: [HelpTutorialItem] = [
        HelpTutorialItem(
            id: .restartInteractiveTutorial,
            titleKey: "help.tutorial.restart.title",
            subtitleKey: "help.tutorial.restart.subtitle",
            icon: "arrow.counterclockwise",
            colorName: "blue"
        )
    ]

    static let omniboxShortcuts: [HelpShortcutItem] = [
        HelpShortcutItem(id: "settings", titleKey: "Settings", examplePhraseKey: "help.shortcut.settings"),
        HelpShortcutItem(id: "profile", titleKey: "Profile", examplePhraseKey: "help.shortcut.profile"),
        HelpShortcutItem(id: "cocaptain", titleKey: "Summon Co-Captain", examplePhraseKey: "help.shortcut.cocaptain"),
        HelpShortcutItem(id: "help", titleKey: "Help & Documentation", examplePhraseKey: "help.shortcut.help"),
        HelpShortcutItem(id: "activity", titleKey: "Activity", examplePhraseKey: "help.shortcut.activity"),
        HelpShortcutItem(id: "daily", titleKey: "Daily", examplePhraseKey: "help.shortcut.daily"),
        HelpShortcutItem(id: "grid", titleKey: "Toggle Grid", examplePhraseKey: "help.shortcut.grid"),
        HelpShortcutItem(id: "organize", titleKey: "Organize Nodes", examplePhraseKey: "help.shortcut.organize"),
        HelpShortcutItem(id: "pendingReviews", titleKey: "Pending CoCaptain Reviews", examplePhraseKey: "help.shortcut.pendingReviews")
    ]

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
            id: "miniapps",
            titleKey: "help.article.miniapps.title",
            subtitleKey: "help.article.miniapps.subtitle",
            icon: "app.connected.to.app.below.fill",
            bodyParagraphKeys: [
                "help.article.miniapps.body1",
                "help.article.miniapps.body2"
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
        ),
        HelpArticle(
            id: "omnibox",
            titleKey: "help.article.omnibox.title",
            subtitleKey: "help.article.omnibox.subtitle",
            icon: "command",
            bodyParagraphKeys: [
                "help.article.omnibox.body1",
                "help.article.omnibox.body2"
            ]
        ),
        HelpArticle(
            id: "videoCall",
            titleKey: "help.article.videoCall.title",
            subtitleKey: "help.article.videoCall.subtitle",
            icon: "video.fill",
            bodyParagraphKeys: [
                "help.article.videoCall.body1",
                "help.article.videoCall.body2",
                "help.article.videoCall.body3"
            ]
        )
    ]
}
