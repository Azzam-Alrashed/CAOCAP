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
            backgroundImageName: "intro0",
            textPlacement: .intro0,
            ctaLabelKey: "Continue"
        ),
        IntroStepContent(
            id: 1,
            titleKey: "intro.step1.title",
            messageKey: "intro.step1.message",
            backgroundImageName: "intro1",
            textPlacement: .intro1,
            ctaLabelKey: "Continue"
        ),
        IntroStepContent(
            id: 2,
            titleKey: "intro.step2.title",
            messageKey: "intro.step2.message",
            backgroundImageName: "intro2",
            textPlacement: .intro2,
            ctaLabelKey: "Begin your mission"
        )
    ]

    /// Convenience for bounds-safe access when computing the last valid `TabView` page.
    static var lastIndex: Int {
        max(steps.count - 1, 0)
    }
}
