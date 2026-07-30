import Foundation

/// Horizontal alignment for copy on illustration-backed intro pages.
enum IntroTextHorizontalAlignment: Equatable {
    case leading
    case center
}

/// Vertical placement for copy on illustration-backed intro pages.
enum IntroTextVerticalAlignment: Equatable {
    case top
    case center
    /// Slightly above vertical center — keeps copy clear of lower artwork.
    case aboveCenter
}

/// Per-step copy placement tuned to each background illustration's open areas.
struct IntroIllustrationTextPlacement: Equatable {
    var horizontalAlignment: IntroTextHorizontalAlignment = .leading
    var verticalAlignment: IntroTextVerticalAlignment = .top
    /// Space below the top chrome when `verticalAlignment` is `.top`.
    var topInset: CGFloat = 4
    /// Fixed max width when `maxWidthFraction` is nil.
    var maxWidth: CGFloat = 340
    /// When set, overrides `maxWidth` as a fraction of the page content width.
    var maxWidthFraction: CGFloat?
    /// Extra vertical nudge applied after `verticalAlignment` is resolved.
    var verticalOffset: CGFloat = 0

    static let intro0 = IntroIllustrationTextPlacement(
        horizontalAlignment: .leading,
        verticalAlignment: .top,
        topInset: 4,
        maxWidth: 340
    )

    /// Top-left open space above the Earth horizon.
    static let intro1 = IntroIllustrationTextPlacement(
        horizontalAlignment: .leading,
        verticalAlignment: .top,
        topInset: 8,
        maxWidthFraction: 0.62
    )

    /// Upper sky band above the lander — centered, clear of Earth and the galaxy sweep.
    static let intro2 = IntroIllustrationTextPlacement(
        horizontalAlignment: .center,
        verticalAlignment: .top,
        topInset: 10,
        maxWidth: 300
    )
}

/// Data model for a single page in the first-launch intro tour.
struct IntroStepContent: Equatable, Identifiable {
    /// Stable index that doubles as the `TabView` tag; must match position in `IntroManifest.steps`.
    let id: Int
    /// Localization key for the bold headline (`Localizable.xcstrings`).
    let titleKey: String
    /// Localization key for the supporting body copy (`Localizable.xcstrings`).
    let messageKey: String
    /// When set, fills the screen as a full-bleed background; copy and chrome are laid out around it.
    let backgroundImageName: String?
    /// Copy placement tuned to each background illustration's open areas.
    let textPlacement: IntroIllustrationTextPlacement?
    /// Localization key for the CTA button label (`Localizable.xcstrings`).
    let ctaLabelKey: String

    var resolvedTextPlacement: IntroIllustrationTextPlacement {
        textPlacement ?? .intro0
    }
}
