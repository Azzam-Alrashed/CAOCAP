import Foundation

/// Static catalogue of every intro step shown during the first-launch product tour.
/// Adding, removing, or reordering steps here automatically updates `IntroCoordinator`
/// and `IntroView` without touching any other file.
enum IntroManifest {
    static let steps: [IntroStepContent] = [
        IntroStepContent(
            id: 0,
            title: "Your ideas can become real apps.",
            message: "Start with a small Mini-App, shape it on the canvas, and see it run as you build.",
            systemImage: "lightbulb",
            accentHex: "2563EB",
            secondaryAccentHex: "38BDF8",
            tertiaryAccentHex: "DBEAFE",
            ctaLabel: "Continue"
        ),
        IntroStepContent(
            id: 1,
            title: "Software should not feel locked away.",
            message: "CAOCAP gives creative builders a way into software without making them passive passengers.",
            systemImage: "lock.open",
            accentHex: "F59E0B",
            secondaryAccentHex: "EC4899",
            tertiaryAccentHex: "38BDF8",
            ctaLabel: "Continue"
        ),
        IntroStepContent(
            id: 2,
            title: "See the shape of what you are making.",
            message: "Arrange ideas, requirements, code, previews, and notes on one spatial canvas.",
            systemImage: "square.grid.3x3",
            accentHex: "10B981",
            secondaryAccentHex: "06B6D4",
            tertiaryAccentHex: "A3E635",
            ctaLabel: "Continue"
        ),
        IntroStepContent(
            id: 3,
            title: "Build with an AI mentor beside you.",
            message: "CoCaptain can explain, suggest changes, and stage edits for your review so you stay in control.",
            systemImage: "sparkles",
            accentHex: "8B5CF6",
            secondaryAccentHex: "3B82F6",
            tertiaryAccentHex: "F472B6",
            ctaLabel: "Continue"
        ),
        IntroStepContent(
            id: 4,
            title: "Start with one small mission.",
            message: "Run a Mini-App, change something meaningful, preview it instantly, and leave more capable.",
            systemImage: "flag.checkered",
            accentHex: "EF4444",
            secondaryAccentHex: "F59E0B",
            tertiaryAccentHex: "84CC16",
            ctaLabel: "Start first mission"
        )
    ]

    /// Convenience for bounds-safe access when computing the last valid `TabView` page.
    static var lastIndex: Int {
        max(steps.count - 1, 0)
    }
}
