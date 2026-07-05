import SwiftUI

/// Text-only selection card for the co-pilot picker step.
struct CopilotPickerCard: View {
    let persona: CopilotPersona
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { Color(hex: persona.accentHex) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(LocalizedStringKey(stringLiteral: persona.nameKey))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(PersonalizationMoonTheme.textPrimary)

                Text(LocalizedStringKey(stringLiteral: persona.roleKey))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)

                Text(LocalizedStringKey(stringLiteral: persona.taglineKey))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PersonalizationMoonTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)

                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? accent : PersonalizationMoonTheme.textMuted)
                    .modifier(BounceOnSelect(isActive: isSelected, reduceMotion: reduceMotion))
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isSelected ? 13 : 12)
            .padding(.horizontal, 10)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.35))

                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isSelected ? PersonalizationMoonTheme.cardFillSelected : PersonalizationMoonTheme.cardFill)

                    if isSelected {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        accent.opacity(0.16),
                                        accent.opacity(0.04),
                                        .clear
                                    ],
                                    center: .top,
                                    startRadius: 0,
                                    endRadius: 140
                                )
                            )
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isSelected ? accent.opacity(0.95) : PersonalizationMoonTheme.cardStroke,
                        lineWidth: isSelected ? 2.5 : 1
                    )
            }
            .shadow(color: PersonalizationMoonTheme.cardShadow, radius: 10, y: 5)
            .shadow(color: isSelected ? accent.opacity(0.42) : .clear, radius: 22, y: 2)
            .shadow(color: isSelected ? accent.opacity(0.22) : .clear, radius: 8, y: 0)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.74), value: isSelected)
    }
}

private struct BounceOnSelect: ViewModifier {
    let isActive: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.symbolEffect(.bounce, value: isActive)
        }
    }
}
