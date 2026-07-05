import SwiftUI

/// Header copy for the co-pilot picker step.
struct PersonalizationCopilotStepContent: View {
    let content: CopilotPickerContent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 4)

            Spacer(minLength: 0)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: isCompactHeight ? 8 : 10) {
            Text(LocalizedStringKey(stringLiteral: content.titleKey))
                .font(.system(size: titleSize, weight: .black, design: .rounded))
                .foregroundStyle(PersonalizationTheme.textPrimary)
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 2)
                .fixedSize(horizontal: false, vertical: true)

            Text(LocalizedStringKey(stringLiteral: content.subtitleKey))
                .font(.system(size: isCompactHeight ? 15 : 16, weight: .medium))
                .foregroundStyle(PersonalizationTheme.textSecondary)
                .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private var titleSize: CGFloat {
        if isCompactHeight { return 26 }
        return UIDevice.current.userInterfaceIdiom == .pad ? 34 : 28
    }

    private var isCompactHeight: Bool {
        UIScreen.main.bounds.height < 700
    }
}

/// Floating selected co-pilot name, role, and tagline centered on screen.
struct PersonalizationSelectedCopilotInfo: View {
    @Bindable var coordinator: PersonalizationOnboardingCoordinator

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let persona = coordinator.selectedCopilot
        let accent = Color(hex: persona.accentHex)

        VStack(spacing: 5) {
            Text(LocalizedStringKey(stringLiteral: persona.nameKey))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(PersonalizationTheme.textPrimary)
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 2)
                .contentTransition(.interpolate)

            Text(LocalizedStringKey(stringLiteral: persona.roleKey))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 2)
                .contentTransition(.interpolate)

            Text(LocalizedStringKey(stringLiteral: persona.taglineKey))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PersonalizationTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
                .minimumScaleFactor(0.9)
                .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 2)
                .contentTransition(.interpolate)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 320)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(persona)
        .transition(Self.personaTransition(reduceMotion: reduceMotion))
    }

    static func appearTransition(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity
            .combined(with: .scale(scale: 0.88, anchor: .center))
            .combined(with: .offset(y: 18))
    }

    static func personaTransition(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.92, anchor: .center))
                .combined(with: .offset(y: 10)),
            removal: .opacity
                .combined(with: .scale(scale: 1.05, anchor: .center))
        )
    }
}
