import Foundation

/// Static catalogue of every intro step shown during the first-launch product tour.
/// Adding, removing, or reordering steps here automatically updates `IntroCoordinator`
/// and `IntroView` without touching any other file.
enum IntroManifest {
    static let steps: [IntroStepContent] = [
        IntroStepContent(
            id: 0,
            title: "Countdown to launch.",
            message: "Every mission begins in a quiet moment—when you decide you are ready. That moment is now.",
            systemImage: "paperplane.fill",
            backgroundImageName: "intro1",
            usesIllustrationBackground: true,
            textPlacement: .intro1,
            topBarStyle: .leadingChrome,
            accentHex: "5F8FD4",
            secondaryAccentHex: "D4845C",
            tertiaryAccentHex: "0B1220",
            ctaGradientStartHex: "6B96D9",
            ctaGradientEndHex: "E8A574",
            ctaLabel: "Continue"
        ),
        IntroStepContent(
            id: 1,
            title: "Break atmosphere.",
            message: "Fear is heaviest on the ground. Push through—the sky belongs to anyone willing to rise.",
            systemImage: "lock.open",
            backgroundImageName: "intro2",
            usesIllustrationBackground: true,
            textPlacement: .intro2,
            topBarStyle: .splitChrome,
            accentHex: "7885CF",
            secondaryAccentHex: "B088B8",
            tertiaryAccentHex: "1E1B4B",
            ctaGradientStartHex: "8491D6",
            ctaGradientEndHex: "C898B8",
            ctaLabel: "Continue"
        ),
        IntroStepContent(
            id: 2,
            title: "Find your bearing.",
            message: "Learning is a long arc across open sky. Trust each step—you are already on your way.",
            systemImage: "square.grid.3x3",
            backgroundImageName: "intro3",
            usesIllustrationBackground: true,
            textPlacement: .intro3,
            topBarStyle: .leadingChrome,
            accentHex: "8578C4",
            secondaryAccentHex: "CC8368",
            tertiaryAccentHex: "312E81",
            ctaGradientStartHex: "9488C8",
            ctaGradientEndHex: "D99278",
            ctaLabel: "Continue"
        ),
        IntroStepContent(
            id: 3,
            title: "The view changes everything.",
            message: "From orbit, old limits look small. What felt impossible is only farther than you have traveled yet.",
            systemImage: "sparkles",
            backgroundImageName: "intro4",
            usesIllustrationBackground: true,
            textPlacement: .intro4,
            topBarStyle: .leadingChrome,
            accentHex: "8274C9",
            secondaryAccentHex: "6B93D4",
            tertiaryAccentHex: "1E1B4B",
            ctaGradientStartHex: "9084D0",
            ctaGradientEndHex: "78A4DC",
            ctaLabel: "Continue"
        ),
        IntroStepContent(
            id: 4,
            title: "One small step.",
            message: "The moon is not reserved for heroes. It waits for anyone brave enough to try. Your mission starts now.",
            systemImage: "flag.checkered",
            backgroundImageName: "intro5",
            usesIllustrationBackground: true,
            textPlacement: .intro5,
            topBarStyle: .leadingChrome,
            accentHex: "6B93D4",
            secondaryAccentHex: "8B74C9",
            tertiaryAccentHex: "1A1033",
            ctaGradientStartHex: nil,
            ctaGradientEndHex: nil,
            ctaLabel: "Begin your mission"
        )
    ]

    /// Convenience for bounds-safe access when computing the last valid `TabView` page.
    static var lastIndex: Int {
        max(steps.count - 1, 0)
    }
}
