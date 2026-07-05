import SwiftUI

/// Shared moon stage with both co-pilot heroes standing on the lunar surface.
struct PersonalizationCopilotStage: View {
    @Bindable var coordinator: PersonalizationOnboardingCoordinator

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let moonHeight = moonDisplayHeight(for: geometry.size.height)
            let heroMaxHeight = heroMaxHeight(for: geometry.size.height)

            ZStack(alignment: .bottom) {
                moonSurface(displayHeight: moonHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                HStack(alignment: .bottom, spacing: columnSpacing) {
                    ForEach(CopilotPersona.allCases) { persona in
                        CopilotPickerColumn(
                            persona: persona,
                            isSelected: coordinator.selectedCopilot == persona,
                            heroMaxHeight: heroMaxHeight,
                            reduceMotion: reduceMotion
                        ) {
                            coordinator.selectCopilot(persona)
                        }
                    }
                }
                .padding(.horizontal, isPad ? 28 : 12)
                .padding(.bottom, heroBottomInset(moonHeight: moonHeight))
            }
        }
        .frame(minHeight: isPad ? 360 : 300)
        .padding(.horizontal, -PersonalizationLayout.horizontalInset)
        .animation(selectionAnimation, value: coordinator.selectedCopilot)
    }

    private func moonSurface(displayHeight: CGFloat) -> some View {
        Image("PersonalizationMoonStage")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: displayHeight)
            .scaleEffect(x: isPad ? 1.14 : 1.18, y: 1.0, anchor: .bottom)
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [
                        PersonalizationMoonTheme.skyMid.opacity(0.95),
                        PersonalizationMoonTheme.skyMid.opacity(0.40),
                        PersonalizationMoonTheme.skyMid.opacity(0.08),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: displayHeight * 0.52)
            }
    }

    private func moonDisplayHeight(for stageHeight: CGFloat) -> CGFloat {
        let ratio: CGFloat = isPad ? 0.44 : 0.48
        let cap: CGFloat = isPad ? 188 : 168
        return min(stageHeight * ratio, cap)
    }

    private func heroMaxHeight(for stageHeight: CGFloat) -> CGFloat {
        let ratio: CGFloat = isPad ? 0.40 : 0.38
        let cap: CGFloat = isPad ? 156 : 136
        return min(stageHeight * ratio, cap)
    }

    private func heroBottomInset(moonHeight: CGFloat) -> CGFloat {
        moonHeight * (isPad ? 0.30 : 0.28)
    }

    private var columnSpacing: CGFloat {
        isPad ? 22 : 10
    }

    private var selectionAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.74)
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

enum PersonalizationLayout {
    static let horizontalInset: CGFloat = 24
}

// MARK: - Hero + card column

private struct CopilotPickerColumn: View {
    let persona: CopilotPersona
    let isSelected: Bool
    let heroMaxHeight: CGFloat
    let reduceMotion: Bool
    let action: () -> Void

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        VStack(spacing: isPad ? 2 : 0) {
            CopilotHeroSlot(
                persona: persona,
                isSelected: isSelected,
                maxHeight: heroMaxHeight,
                reduceMotion: reduceMotion,
                action: action
            )

            CopilotPickerCard(
                persona: persona,
                isSelected: isSelected,
                action: action
            )
            .offset(y: isSelected ? -2 : 0)
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.74), value: isSelected)
    }
}

// MARK: - Hero slot

private struct CopilotHeroSlot: View {
    let persona: CopilotPersona
    let isSelected: Bool
    let maxHeight: CGFloat
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                if isSelected {
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: persona.accentHex).opacity(0.55),
                                    Color(hex: persona.accentHex).opacity(0.14),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 6,
                                endRadius: 84
                            )
                        )
                        .frame(width: 156, height: 40)
                        .offset(y: 12)
                        .blur(radius: 1)
                }

                Image(persona.heroImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: maxHeight)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.06 : 1.0, anchor: .bottom)
        .offset(y: isSelected ? -12 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.74), value: isSelected)
        .accessibilityLabel(Text(LocalizedStringKey(stringLiteral: persona.nameKey)))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
