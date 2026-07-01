import Foundation

enum HelpTutorialAction: Hashable {
    case openTutorialCanvas
    case restartInteractiveTutorial
    case openPacManCanvas
    case openXOCanvas
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
            id: .openTutorialCanvas,
            titleKey: "help.tutorial.openCanvas.title",
            subtitleKey: "help.tutorial.openCanvas.subtitle",
            icon: "graduationcap.fill",
            colorName: "green"
        ),
        HelpTutorialItem(
            id: .restartInteractiveTutorial,
            titleKey: "help.tutorial.restart.title",
            subtitleKey: "help.tutorial.restart.subtitle",
            icon: "arrow.counterclockwise",
            colorName: "blue"
        ),
        HelpTutorialItem(
            id: .openPacManCanvas,
            titleKey: "help.tutorial.pacman.title",
            subtitleKey: "help.tutorial.pacman.subtitle",
            icon: "gamecontroller.fill",
            colorName: "purple"
        ),
        HelpTutorialItem(
            id: .openXOCanvas,
            titleKey: "help.tutorial.xo.title",
            subtitleKey: "help.tutorial.xo.subtitle",
            icon: "square.grid.3x3.fill",
            colorName: "secondary"
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
        )
    ]
}
