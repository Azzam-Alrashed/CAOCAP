import SwiftUI

/// A single selectable answer tile in the personalization survey.
struct PersonalizationAnswerCard: View {
    let titleKey: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(LocalizedStringKey(stringLiteral: titleKey))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(labelColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? Color(hex: "2563EB") : labelColor.opacity(0.35))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(cardFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color(hex: "2563EB").opacity(0.55) : Color.white.opacity(strokeOpacity),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isSelected)
    }

    private var labelColor: Color {
        Color(uiColor: .label)
    }

    private var strokeOpacity: CGFloat {
        colorScheme == .dark ? 0.38 : 0.62
    }

    private var cardFill: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color(hex: "2563EB").opacity(colorScheme == .dark ? 0.22 : 0.12))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }
}
