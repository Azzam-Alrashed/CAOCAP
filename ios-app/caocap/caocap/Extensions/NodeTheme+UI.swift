import SwiftUI

extension NodeTheme {
    public var color: Color {
        gradientColors.first ?? .blue
    }

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

    public var glowOpacity: Double {
        switch self {
        case .secondary: return 0.05
        default: return 0.15
        }
    }
}

extension NodeType {
    public var canvasGradientColors: [Color] {
        defaultTheme.gradientColors
    }
}
