import Testing
@testable import caocap

struct MoonStageLayoutTests {
    @Test func standLineYMovesDownAsScreenGrows() {
        let narrow = MoonStageLayout.standLineY(screenWidth: 390, screenHeight: 700)
        let tall = MoonStageLayout.standLineY(screenWidth: 390, screenHeight: 900)
        #expect(tall > narrow)
    }

    @Test func heroStandLineRespectsBottomChrome() {
        let width: CGFloat = 390
        let height: CGFloat = 844
        let raw = MoonStageLayout.standLineY(screenWidth: width, screenHeight: height)
        let adjusted = MoonStageLayout.heroStandLineY(
            screenWidth: width,
            screenHeight: height,
            bottomChromeHeight: 200
        )
        #expect(adjusted <= raw)
    }
}
