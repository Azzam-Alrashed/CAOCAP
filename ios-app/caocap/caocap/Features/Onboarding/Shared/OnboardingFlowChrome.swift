import SwiftUI

/// Visual palette for first-run flow chrome.
enum OnboardingFlowChromePalette {
    case introIllustration

    var logoForeground: Color {
        .white.opacity(0.9)
    }

    var skipForeground: Color {
        .white.opacity(0.78)
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

/// Shared circular back control used in onboarding bottom bars.
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
