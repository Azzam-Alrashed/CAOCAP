import CoreGraphics

/// Asset-derived geometry for `PersonalizationMoonStage` (612×408 PNG).
enum MoonStageLayout {
    static let assetAspectRatio: CGFloat = 612.0 / 408.0
    /// Terrain meets transparent sky in `personalization_moon_stage.png`.
    static let horizonFractionFromImageBottom: CGFloat = 0.38
    static let displayScale: CGFloat = 1.78
    /// Trims transparent padding baked into hero PNG feet.
    static let heroFeetTrim: CGFloat = 6
    /// Nudges hero feet down onto the visible moon terrain.
    static let heroStandDownOffset: CGFloat = 40

    static func renderedHeight(screenWidth: CGFloat) -> CGFloat {
        (screenWidth / assetAspectRatio) * displayScale
    }

    /// Moon horizon Y measured from the top of the screen.
    static func standLineY(screenWidth: CGFloat, screenHeight: CGFloat) -> CGFloat {
        screenHeight - renderedHeight(screenWidth: screenWidth) * horizonFractionFromImageBottom
    }

    /// Keeps hero feet on the visible moon rim when bottom chrome overlaps the horizon.
    static func heroStandLineY(
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        bottomChromeHeight: CGFloat
    ) -> CGFloat {
        let raw = standLineY(screenWidth: screenWidth, screenHeight: screenHeight) + heroStandDownOffset
        let chromeClearance = screenHeight - bottomChromeHeight - 8
        return min(raw, chromeClearance)
    }
}
