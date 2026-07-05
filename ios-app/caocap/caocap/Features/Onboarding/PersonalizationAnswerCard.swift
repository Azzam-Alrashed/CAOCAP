import SwiftUI

/// A single selectable answer tile in the personalization survey.
struct PersonalizationAnswerCard: View {
    let titleKey: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(LocalizedStringKey(stringLiteral: titleKey))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(PersonalizationMoonTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? Color(hex: "2563EB") : PersonalizationMoonTheme.textMuted.opacity(0.45))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(PersonalizationMoonTheme.cardFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color(hex: "2563EB").opacity(0.65) : PersonalizationMoonTheme.cardStroke,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .shadow(color: PersonalizationMoonTheme.cardShadow, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isSelected)
    }
}
