import SwiftUI

/// Co-pilot heroes positioned on the moon horizon.
struct PersonalizationHeroLayer: View {
    enum Mode {
        case picker
        case companion
    }

    @Bindable var coordinator: PersonalizationOnboardingCoordinator
    let mode: Mode
    let standLineY: CGFloat
    let screenWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            switch mode {
            case .picker:
                pickerHeroes
            case .companion:
                companionHero
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(mode == .picker)
    }

    private var pickerHeroes: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(CopilotPersona.allCases) { persona in
                let isSelected = coordinator.selectedCopilot == persona
                let isDimmed = coordinator.hasUserSelectedCopilot && !isSelected

                CopilotHeroView(
                    persona: persona,
                    isSelected: isSelected,
                    maxHeight: pickerHeroMaxHeight,
                    reduceMotion: reduceMotion
                ) {
                    coordinator.selectCopilot(persona)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, isPad ? 8 : 4)
                .opacity(isDimmed ? 0.22 : 1)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: standLineY, alignment: .bottom)
        .animation(selectionAnimation, value: coordinator.selectedCopilot)
        .animation(selectionAnimation, value: coordinator.hasUserSelectedCopilot)
    }

    private var companionHero: some View {
        CopilotHeroView(
            persona: coordinator.selectedCopilot,
            isSelected: true,
            maxHeight: companionHeroMaxHeight,
            reduceMotion: reduceMotion,
            action: {}
        )
        .frame(maxWidth: .infinity)
        .frame(height: standLineY, alignment: .bottom)
        .allowsHitTesting(false)
    }

    private var pickerHeroMaxHeight: CGFloat {
        let cap: CGFloat = isPad ? 156 : 136
        return min(standLineY * 0.42, cap)
    }

    private var companionHeroMaxHeight: CGFloat {
        let cap: CGFloat = isPad ? 140 : 120
        return min(standLineY * 0.36, cap)
    }

    private var selectionAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.74)
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

// MARK: - Hero view

private struct CopilotHeroView: View {
    let persona: CopilotPersona
    let isSelected: Bool
    let maxHeight: CGFloat
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                footShadow

                Image(persona.heroImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: maxHeight)
                    .offset(y: MoonStageLayout.heroFeetTrim)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.06 : 1.0, anchor: .bottom)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.74), value: isSelected)
        .accessibilityLabel(Text(LocalizedStringKey(stringLiteral: persona.nameKey)))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var footShadow: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hex: persona.accentHex).opacity(isSelected ? 0.50 : 0.28),
                        Color(hex: persona.accentHex).opacity(isSelected ? 0.12 : 0.06),
                        .clear
                    ],
                    center: .center,
                    startRadius: 4,
                    endRadius: isSelected ? 84 : 68
                )
            )
            .frame(width: isSelected ? 156 : 132, height: isSelected ? 40 : 32)
            .offset(y: 10)
            .blur(radius: 1)
    }
}
