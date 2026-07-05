import SwiftUI

/// Dark space palette for personalization onboarding.
enum PersonalizationMoonTheme {
    static let skyTop = Color(hex: "050814")
    static let skyMid = Color(hex: "0D1B2A")
    static let skyBottom = Color(hex: "12082A")

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.86)
    static let textMuted = Color.white.opacity(0.58)

    static let cardFill = Color.white.opacity(0.07)
    static let cardFillSelected = Color.white.opacity(0.12)
    static let cardStroke = Color.white.opacity(0.28)
    static let cardShadow = Color.black.opacity(0.30)

    static let trackFill = Color.white.opacity(0.18)
}
