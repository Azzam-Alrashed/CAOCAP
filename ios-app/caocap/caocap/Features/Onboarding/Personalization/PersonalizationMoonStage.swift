import SwiftUI

/// Full-bleed moon horizon pinned to the screen bottom.
struct PersonalizationMoonStage: View {
    var body: some View {
        GeometryReader { geometry in
            Image("PersonalizationMoonStage")
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width)
                .scaleEffect(MoonStageLayout.displayScale, anchor: .bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea(edges: .bottom)
    }
}
