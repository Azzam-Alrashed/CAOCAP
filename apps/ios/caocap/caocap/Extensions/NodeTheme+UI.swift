import SwiftUI

/// Rendering properties that map each `NodeTheme` to concrete SwiftUI colors.
extension NodeTheme {
    /// The primary representative color of this theme — the first gradient stop.
    /// Falls back to `.blue` if `gradientColors` is ever unexpectedly empty.
    public var color: Color {
        gradientColors.first ?? .blue
    }

    /// Two-stop gradient pair used for node card backgrounds and glow effects.
    /// Colors are defined in sRGB hex for design-system consistency.
    public var gradientColors: [Color] {
        switch self {
        case .purple:
            return [Color(hex: "A855F7"), Color(hex: "6366F1")]
        case .blue:
            return [Color(hex: "3B82F6"), Color(hex: "06B6D4")]
        case .pink:
            return [Color(hex: "EC4899"), Color(hex: "F97316")]
        case .orange:
            return [Color(hex: "F97316"), Color(hex: "FACC15")]
        case .green:
            return [Color(hex: "22C55E"), Color(hex: "14B8A6")]
        case .indigo:
            return [Color(hex: "6366F1"), Color(hex: "8B5CF6")]
        case .cyan:
            return [Color(hex: "06B6D4"), Color(hex: "3B82F6")]
        case .secondary:
            return [Color(hex: "94A3B8"), Color(hex: "64748B")]
        }
    }

    /// Opacity used for the ambient glow rendered behind a node card.
    /// `.secondary` uses a much lower opacity because its muted greys
    /// would look heavy at the standard 0.15 level.
    public var glowOpacity: Double {
        switch self {
        case .secondary: return 0.05
        default: return 0.15
        }
    }
}

/// Canvas-level gradient convenience for `NodeType`.
extension NodeType {
    /// Gradient colors for this node type's canonical theme, used when rendering
    /// canvas backgrounds or type-picker swatches.
    public var canvasGradientColors: [Color] {
        defaultTheme.gradientColors
    }
}
