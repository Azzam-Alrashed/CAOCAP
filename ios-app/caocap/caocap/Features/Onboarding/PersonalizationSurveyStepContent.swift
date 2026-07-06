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
                    .foregroundStyle(PersonalizationTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? Color(hex: "2563EB") : PersonalizationTheme.textMuted.opacity(0.45))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(PersonalizationTheme.cardFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color(hex: "2563EB").opacity(0.65) : PersonalizationTheme.cardStroke,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .shadow(color: PersonalizationTheme.cardShadow, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isSelected)
    }
}

/// Survey question and answer list for steps 2–6.
struct PersonalizationSurveyStepContent: View {
    let question: PersonalizationSurveyQuestion
    @Bindable var coordinator: PersonalizationOnboardingCoordinator
    let showsCompanionHero: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(LocalizedStringKey(stringLiteral: question.titleKey))
                        .font(.system(size: titleSize, weight: .black, design: .rounded))
                        .foregroundStyle(PersonalizationTheme.textPrimary)
                        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(LocalizedStringKey(stringLiteral: question.subtitleKey))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(PersonalizationTheme.textSecondary)
                        .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 520, alignment: .leading)

                VStack(spacing: 12) {
                    ForEach(question.options) { option in
                        PersonalizationAnswerCard(
                            titleKey: option.titleKey,
                            isSelected: coordinator.isAnswered(questionID: question.id)
                                && coordinator.selectedAnswerID(for: question.id) == option.id
                        ) {
                            coordinator.select(answerID: option.id, for: question.id)
                        }
                    }
                }
                .frame(maxWidth: 520)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, showsCompanionHero ? PersonalizationTheme.companionHeroScrollClearance : 8)
        }
        .scrollIndicators(.hidden)
    }

    private var titleSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 34 : 28
    }
}
