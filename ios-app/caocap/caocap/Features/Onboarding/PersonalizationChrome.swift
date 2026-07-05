import SwiftUI

/// Measured height of bottom chrome (footnote + navigation bar) for hero alignment.
struct PersonalizationBottomChromeHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Top bar, progress, footnote, and bottom navigation for personalization.
enum PersonalizationChrome {
    // MARK: - Top bar

    struct TopBar: View {
        let onSkip: () -> Void

        var body: some View {
            HStack(alignment: .top) {
                Text("CAOCAP")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(PersonalizationTheme.textPrimary.opacity(0.82))

                Spacer(minLength: 0)

                Button(action: onSkip) {
                    Text(LocalizedStringKey("Skip"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PersonalizationTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 56, alignment: .top)
        }
    }

    // MARK: - Progress

    struct ProgressBar: View {
        let stepLabel: String
        let currentIndex: Int
        let stepCount: Int

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(stepLabel)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(PersonalizationTheme.textSecondary)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(PersonalizationTheme.trackFill)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "2563EB"), Color(hex: "4DB6FF")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: progressWidth(for: geometry.size.width))
                    }
                }
                .frame(height: 6)
            }
        }

        private func progressWidth(for totalWidth: CGFloat) -> CGFloat {
            guard stepCount > 0 else { return 0 }
            let progress = CGFloat(currentIndex + 1) / CGFloat(stepCount)
            return max(totalWidth * progress, 6)
        }
    }

    // MARK: - Footnote

    struct CopilotFootnote: View {
        let footnoteKey: String

        var body: some View {
            Text(LocalizedStringKey(stringLiteral: footnoteKey))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PersonalizationTheme.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Bottom bar

    struct BottomBar: View {
        let isFirstPage: Bool
        let canContinue: Bool
        let reduceMotion: Bool
        let onBack: () -> Void
        let onContinue: () -> Void

        var body: some View {
            HStack(spacing: 12) {
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86)) {
                        onBack()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(PersonalizationTheme.textPrimary.opacity(isFirstPage ? 0.28 : 0.88))
                        .frame(width: 48, height: 52)
                        .background(PersonalizationTheme.cardFill, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(PersonalizationTheme.cardStroke, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(isFirstPage)

                PersonalizationPrimaryButton(titleKey: "Continue", isEnabled: canContinue) {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86)) {
                        onContinue()
                    }
                }
            }
            .padding(.bottom, 6)
        }
    }

    // MARK: - Completion moment

    struct CompletionMoment: View {
        let onEnter: () -> Void

        var body: some View {
            VStack(spacing: 28) {
                Spacer(minLength: 0)

                Image(systemName: "sparkles")
                    .font(.system(size: 54, weight: .black))
                    .foregroundStyle(Color(hex: "4DB6FF"))
                    .symbolEffect(.bounce, value: true)

                VStack(spacing: 12) {
                    Text(LocalizedStringKey("Your mission profile is ready"))
                        .font(.system(size: titleSize, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(PersonalizationTheme.textPrimary)

                    Text(LocalizedStringKey("We’ll use this to shape your journey from here."))
                        .font(.system(size: 17, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(PersonalizationTheme.textSecondary)
                }
                .frame(maxWidth: 420)

                Spacer(minLength: 0)

                PersonalizationPrimaryButton(titleKey: "Enter mission control", isEnabled: true, action: onEnter)
                    .padding(.bottom, 6)
            }
            .padding(.horizontal, PersonalizationTheme.horizontalInset)
            .padding(.vertical, PersonalizationTheme.verticalInset)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }

        private var titleSize: CGFloat {
            UIDevice.current.userInterfaceIdiom == .pad ? 34 : 28
        }
    }
}
