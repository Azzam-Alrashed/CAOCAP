import Foundation

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
    /// Primary brand accent hex for this step (button gradient, glow).
    let accentHex: String
    /// Secondary accent hex blended into gradients alongside the primary.
    let secondaryAccentHex: String
    /// Tertiary accent hex used for the backdrop radial gradient.
    let tertiaryAccentHex: String
    /// Label shown on the CTA button; the last step uses a distinct action phrase.
    let ctaLabel: String
}
