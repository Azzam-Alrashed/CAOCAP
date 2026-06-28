import Foundation

/// Static catalogue of every intro step shown during the first-launch product tour.
/// Adding, removing, or reordering steps here automatically updates `IntroCoordinator`
/// and `IntroView` without touching any other file.
enum IntroManifest {
    static let steps: [IntroStepContent] = [
        IntroStepContent(
            id: 0,
            titleKey: "intro.step0.title",
            messageKey: "intro.step0.message",
            backgroundImageName: "intro1",
            textPlacement: .intro1,
            accentHex: "5F8FD4",
            secondaryAccentHex: "D4845C",
            tertiaryAccentHex: "0B1220",
            ctaGradientStartHex: "6B96D9",
            ctaGradientEndHex: "E8A574",
            ctaLabelKey: "Continue"
        ),
        IntroStepContent(
            id: 1,
            titleKey: "intro.step1.title",
            messageKey: "intro.step1.message",
            backgroundImageName: "intro2",
            textPlacement: .intro2,
            accentHex: "7885CF",
            secondaryAccentHex: "B088B8",
            tertiaryAccentHex: "1E1B4B",
            ctaGradientStartHex: "8491D6",
            ctaGradientEndHex: "C898B8",
            ctaLabelKey: "Continue"
        ),
        IntroStepContent(
            id: 2,
            titleKey: "intro.step2.title",
            messageKey: "intro.step2.message",
            backgroundImageName: "intro3",
            textPlacement: .intro3,
            accentHex: "8578C4",
            secondaryAccentHex: "CC8368",
            tertiaryAccentHex: "312E81",
            ctaGradientStartHex: "9488C8",
            ctaGradientEndHex: "D99278",
            ctaLabelKey: "Continue"
        ),
        IntroStepContent(
            id: 3,
            titleKey: "intro.step3.title",
            messageKey: "intro.step3.message",
            backgroundImageName: "intro4",
            textPlacement: .intro4,
            accentHex: "8274C9",
            secondaryAccentHex: "6B93D4",
            tertiaryAccentHex: "1E1B4B",
            ctaGradientStartHex: "9084D0",
            ctaGradientEndHex: "78A4DC",
            ctaLabelKey: "Continue"
        ),
        IntroStepContent(
            id: 4,
            titleKey: "intro.step4.title",
            messageKey: "intro.step4.message",
            backgroundImageName: "intro5",
            textPlacement: .intro5,
            accentHex: "6B93D4",
            secondaryAccentHex: "8B74C9",
            tertiaryAccentHex: "1A1033",
            ctaGradientStartHex: nil,
            ctaGradientEndHex: nil,
            ctaLabelKey: "Begin your mission"
        )
    ]

    /// Convenience for bounds-safe access when computing the last valid `TabView` page.
    static var lastIndex: Int {
        max(steps.count - 1, 0)
    }
}
