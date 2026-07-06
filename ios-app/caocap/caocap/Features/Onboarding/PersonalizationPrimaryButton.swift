import SwiftUI

/// Primary CTA button styling shared across personalization steps.
struct PersonalizationPrimaryButton: View {
    let titleKey: String
    let isEnabled: Bool
    var isLastStep: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(LocalizedStringKey(stringLiteral: titleKey))
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Image(systemName: isLastStep ? "arrow.right.circle.fill" : "arrow.right")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(Color(uiColor: .label))
            .opacity(isEnabled ? 1 : 0.55)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(OnboardingGlassChrome.stroke, lineWidth: 1)
            }
            .shadow(
                color: OnboardingGlassChrome.shadow,
                radius: 12,
                x: 0,
                y: 6
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
