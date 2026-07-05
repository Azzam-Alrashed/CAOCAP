import SwiftUI

/// Full-screen personalization flow shown after the motivational intro.
struct PersonalizationOnboardingView: View {
    @Bindable var coordinator: PersonalizationOnboardingCoordinator
    let onFinish: () -> Void

    @AppStorage(LocalizationManager.languageStorageKey) private var selectedLanguage = "English"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            PersonalizationBackdrop()

            if coordinator.showCompletionMoment {
                completionMoment
            } else {
                questionFlow
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, LocalizationManager.shared.locale(for: selectedLanguage))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            coordinator.onAppearIfNeeded()
        }
        .confirmationDialog(
            LocalizedStringKey("Continue without personalizing?"),
            isPresented: $coordinator.showSkipConfirmation,
            titleVisibility: .visible
        ) {
            Button(LocalizedStringKey("Skip anyway"), role: .destructive) {
                coordinator.confirmSkip()
                onFinish()
            }
            Button(LocalizedStringKey("Go back"), role: .cancel) {
                coordinator.cancelSkip()
            }
        } message: {
            Text(LocalizedStringKey("Personalization helps us tailor your journey."))
        }
    }

    private var questionFlow: some View {
        VStack(spacing: 0) {
            topBar
            progressBar
                .padding(.top, 8)

            TabView(selection: $coordinator.currentIndex) {
                ForEach(Array(PersonalizationOnboardingManifest.steps.enumerated()), id: \.offset) { index, step in
                    stepPage(step)
                        .tag(index)
                }
            }
            .id(selectedLanguage)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86), value: coordinator.currentIndex)

            bottomBar
        }
        .padding(.horizontal, PersonalizationLayout.horizontalInset)
        .padding(.vertical, 18)
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            Text("CAOCAP")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .tracking(2)
                .foregroundStyle(PersonalizationMoonTheme.textPrimary.opacity(0.82))

            Spacer(minLength: 0)

            Button {
                coordinator.requestSkip()
            } label: {
                Text(LocalizedStringKey("Skip"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PersonalizationMoonTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 56, alignment: .top)
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(coordinator.stepLabel)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(PersonalizationMoonTheme.textSecondary)
                .id(selectedLanguage)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PersonalizationMoonTheme.trackFill)
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
        let count = PersonalizationOnboardingManifest.steps.count
        guard count > 0 else { return 0 }
        let progress = CGFloat(coordinator.currentIndex + 1) / CGFloat(count)
        return max(totalWidth * progress, 6)
    }

    @ViewBuilder
    private func stepPage(_ step: PersonalizationStepKind) -> some View {
        switch step {
        case .copilotPicker(let content):
            PersonalizationCopilotPickerView(content: content, coordinator: coordinator)
        case .surveyQuestion(let question):
            surveyQuestionPage(question)
        }
    }

    private func surveyQuestionPage(_ question: PersonalizationSurveyQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(LocalizedStringKey(stringLiteral: question.titleKey))
                        .font(.system(size: titleSize, weight: .black, design: .rounded))
                        .foregroundStyle(PersonalizationMoonTheme.textPrimary)
                        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(LocalizedStringKey(stringLiteral: question.subtitleKey))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(PersonalizationMoonTheme.textSecondary)
                        .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 520, alignment: .leading)

                VStack(spacing: 12) {
                    ForEach(question.options) { option in
                        PersonalizationAnswerCard(
                            titleKey: option.titleKey,
                            isSelected: coordinator.selectedAnswerID(for: question.id) == option.id
                        ) {
                            coordinator.select(answerID: option.id, for: question.id)
                        }
                    }
                }
                .frame(maxWidth: 520)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86)) {
                    coordinator.back()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PersonalizationMoonTheme.textPrimary.opacity(coordinator.isFirstPage ? 0.28 : 0.88))
                    .frame(width: 48, height: 52)
                    .background(PersonalizationMoonTheme.cardFill, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(PersonalizationMoonTheme.cardStroke, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(coordinator.isFirstPage)

            PersonalizationPrimaryButton(
                titleKey: "Continue",
                isEnabled: coordinator.canContinue
            ) {
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86)) {
                    coordinator.next()
                }
            }
        }
        .padding(.bottom, 6)
    }

    private var completionMoment: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            Image(systemName: "sparkles")
                .font(.system(size: 54, weight: .black))
                .foregroundStyle(Color(hex: "4DB6FF"))
                .symbolEffect(.bounce, value: coordinator.showCompletionMoment)

            VStack(spacing: 12) {
                Text(LocalizedStringKey("Your mission profile is ready"))
                    .font(.system(size: titleSize, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PersonalizationMoonTheme.textPrimary)

                Text(LocalizedStringKey("We’ll use this to shape your journey from here."))
                    .font(.system(size: 17, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PersonalizationMoonTheme.textSecondary)
            }
            .frame(maxWidth: 420)

            Spacer(minLength: 0)

            PersonalizationPrimaryButton(titleKey: "Enter mission control", isEnabled: true) {
                coordinator.finishAfterCompletionMoment()
                onFinish()
            }
            .padding(.bottom, 6)
        }
        .padding(.horizontal, PersonalizationLayout.horizontalInset)
        .padding(.vertical, 18)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var titleSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 34 : 28
    }
}

#Preview {
    PersonalizationOnboardingView(coordinator: PersonalizationOnboardingCoordinator()) {}
}
