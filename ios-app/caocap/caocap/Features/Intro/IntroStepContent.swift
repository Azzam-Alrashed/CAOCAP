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

    static let intro1 = IntroIllustrationTextPlacement(
        horizontalAlignment: .leading,
        verticalAlignment: .top,
        topInset: 4,
        maxWidth: 340
    )

    /// Dead-center in the open nebula band between planets and clouds.
    static let intro2 = IntroIllustrationTextPlacement(
        horizontalAlignment: .center,
        verticalAlignment: .center,
        maxWidth: 300
    )

    /// Left-aligned, slightly above center — clear of the sunset and tower.
    static let intro3 = IntroIllustrationTextPlacement(
        horizontalAlignment: .leading,
        verticalAlignment: .aboveCenter,
        maxWidthFraction: 0.58,
        verticalOffset: -8
    )

    /// Top-left open space above the Earth horizon.
    static let intro4 = IntroIllustrationTextPlacement(
        horizontalAlignment: .leading,
        verticalAlignment: .top,
        topInset: 8,
        maxWidthFraction: 0.62
    )

    /// Upper sky band above the lander — centered, clear of Earth and the galaxy sweep.
    static let intro5 = IntroIllustrationTextPlacement(
        horizontalAlignment: .center,
        verticalAlignment: .top,
        topInset: 10,
        maxWidth: 300
    )
}

/// Top chrome layout for illustration pages.
enum IntroTopBarStyle: Equatable {
    /// CAOCAP and Skip stacked on the leading edge (intro1, intro3, intro4, intro5).
    case leadingChrome
    /// CAOCAP leading, Skip trailing — keeps the left illustration clear (intro2).
    case splitChrome
}

/// Data model for a single page in the first-launch intro tour.
/// Colors are expressed as hex strings so `IntroManifest` stays plain data with no SwiftUI dependency.
struct IntroStepContent: Equatable, Identifiable {
    /// Stable index that doubles as the `TabView` tag; must match position in `IntroManifest.steps`.
    let id: Int
    /// Bold headline displayed prominently at the top of the page.
    let title: String
    /// Supporting body copy shown below the title.
    let message: String
    /// SF Symbol name for the hero icon rendered inside the glassmorphic card.
    let systemImage: String
    /// When set, fills the screen as a full-bleed background; copy and chrome are laid out around it.
    let backgroundImageName: String?
    /// Layout tuned for illustration backgrounds: headline in the sky, controls in the clear lower band.
    let usesIllustrationBackground: Bool
    /// Copy placement when `usesIllustrationBackground` is true.
    let textPlacement: IntroIllustrationTextPlacement?
    /// Top bar layout when `usesIllustrationBackground` is true.
    let topBarStyle: IntroTopBarStyle?
    /// Primary brand accent hex for this step (progress dots, chrome tint).
    let accentHex: String
    /// Secondary accent hex paired with the primary for chrome and fallbacks.
    let secondaryAccentHex: String
    /// Tertiary accent hex used for the backdrop radial gradient.
    let tertiaryAccentHex: String
    /// Soft CTA gradient start; defaults to `accentHex` when nil.
    let ctaGradientStartHex: String?
    /// Soft CTA gradient end; defaults to `secondaryAccentHex` when nil.
    let ctaGradientEndHex: String?
    /// Label shown on the CTA button; the last step uses a distinct action phrase.
    let ctaLabel: String

    var resolvedTextPlacement: IntroIllustrationTextPlacement {
        textPlacement ?? .intro1
    }

    var resolvedTopBarStyle: IntroTopBarStyle {
        topBarStyle ?? .leadingChrome
    }

    var resolvedCTAGradientStartHex: String {
        ctaGradientStartHex ?? accentHex
    }

    var resolvedCTAGradientEndHex: String {
        ctaGradientEndHex ?? secondaryAccentHex
    }
}
