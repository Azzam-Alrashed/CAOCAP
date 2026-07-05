import SwiftUI

/// Primary CTA button styling shared across personalization steps.
struct PersonalizationPrimaryButton: View {
    let titleKey: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(LocalizedStringKey(stringLiteral: titleKey))
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)

                Image(systemName: "arrow.right")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "2563EB"), Color(hex: "4DB6FF")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(isEnabled ? 1 : 0.45)
            }
            .shadow(color: Color(hex: "2563EB").opacity(isEnabled ? 0.35 : 0), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
