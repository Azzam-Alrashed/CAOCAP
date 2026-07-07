import SwiftUI

/// A timeline card that politely asks the user one question with tappable
/// answer chips. Tapping a chip sends the answer as the user's next message;
/// the card then locks with the chosen option highlighted.
struct ClarifyingQuestionCardView: View {
    let item: CoCaptainClarifyingQuestionItem
    let onSelectOption: (String) -> Void

    private var isAnswered: Bool {
        item.answeredOption != nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CopilotAvatarView(size: 32)

            VStack(alignment: .leading, spacing: 10) {
                Text(item.question.prompt)
                    .font(.system(size: 14, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(item.question.options, id: \.self) { option in
                        optionChip(option)
                    }
                }

                if !isAnswered {
                    Text(LocalizationManager.shared.localizedString("Or type your own answer below."))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.blue.opacity(0.22), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: 420, alignment: .leading)

            Spacer(minLength: 0)
        }
        .transition(.asymmetric(insertion: .push(from: .bottom).combined(with: .opacity), removal: .opacity))
    }

    @ViewBuilder
    private func optionChip(_ option: String) -> some View {
        let isChosen = item.answeredOption == option

        Button {
            onSelectOption(option)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isChosen ? Color.green : Color.blue)
                Text(option)
                    .font(.system(size: 13, weight: .medium))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((isChosen ? Color.green : Color.blue).opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke((isChosen ? Color.green : Color.blue).opacity(0.22), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isAnswered)
        .opacity(isAnswered && !isChosen ? 0.45 : 1)
    }
}
