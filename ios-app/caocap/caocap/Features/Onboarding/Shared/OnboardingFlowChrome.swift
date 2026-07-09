import SwiftUI

/// Visual palette for first-run flow chrome shared by intro and personalization.
enum OnboardingFlowChromePalette {
    case introIllustration
    case personalizationSpace

    var logoForeground: Color {
        switch self {
        case .introIllustration:
            return .white.opacity(0.9)
        case .personalizationSpace:
            return PersonalizationTheme.textPrimary.opacity(0.82)
        }
    }

    var skipForeground: Color {
        switch self {
        case .introIllustration:
            return .white.opacity(0.78)
        case .personalizationSpace:
            return PersonalizationTheme.textSecondary
        }
    }
}

/// Shared top bar: CAOCAP wordmark, language toggle, and skip action.
struct OnboardingFlowTopBar: View {
    let palette: OnboardingFlowChromePalette
    let onSkip: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Text("CAOCAP")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .tracking(2)
                .foregroundStyle(palette.logoForeground)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                OnboardingLanguageButton(usesLightChrome: true)

                Button(action: onSkip) {
                    Text(LocalizedStringKey("Skip"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.skipForeground)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 56, alignment: .top)
    }
}

/// Shared circular back control used in intro and personalization bottom bars.
struct OnboardingFlowBackButton: View {
    let foregroundOpacity: CGFloat
    var isEnabled: Bool = true
    var accessibilityLabel: LocalizedStringKey?
    let action: () -> Void

    var body: some View {
        let button = Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: "1E3A5F").opacity(foregroundOpacity))
                .frame(width: 48, height: 52)
                .background(Color.white.opacity(0.82), in: Circle())
                .overlay {
                    Circle()
                        .stroke(OnboardingGlassChrome.inactiveStroke, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)

        if let accessibilityLabel {
            button.accessibilityLabel(Text(accessibilityLabel))
        } else {
            button
        }
    }
}
