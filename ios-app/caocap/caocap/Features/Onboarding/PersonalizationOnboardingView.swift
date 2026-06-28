import SwiftUI

/// Frosted-glass styling shared with intro bottom chrome.
private enum PersonalizationGlassChrome {
    static let stroke = Color.white.opacity(0.62)
    static let inactiveStroke = Color.white.opacity(0.38)
    static let shadow = Color.black.opacity(0.1)
}

/// Full-screen personalization survey shown after the motivational intro.
struct PersonalizationOnboardingView: View {
    @Bindable var coordinator: PersonalizationOnboardingCoordinator
    let onFinish: () -> Void

    @AppStorage(LocalizationManager.languageStorageKey) private var selectedLanguage = "English"
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            background

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

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(hex: "6366F1").opacity(colorScheme == .dark ? 0.18 : 0.12),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [Color(hex: "0B1220"), Color(hex: "1E1B4B"), Color(hex: "080A12")]
        }
        return [Color(hex: "EEF4FF"), Color(hex: "F8FAFC"), Color(hex: "EDE9FE")]
    }

    private var questionFlow: some View {
        VStack(spacing: 0) {
            topBar
            progressBar
                .padding(.top, 8)

            TabView(selection: $coordinator.currentIndex) {
                ForEach(Array(PersonalizationOnboardingManifest.questions.enumerated()), id: \.element.id) { index, question in
                    questionPage(question)
                        .tag(index)
                }
            }
            .id(selectedLanguage)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86), value: coordinator.currentIndex)

            bottomBar
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            Text("CAOCAP")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .tracking(2)
                .foregroundStyle(headerForeground)

            Spacer(minLength: 0)

            Button {
                coordinator.requestSkip()
            } label: {
                Text(LocalizedStringKey("Skip"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(headerForeground.opacity(0.78))
            }
            .buttonStyle(.plain)
        }
        .frame(height: 56, alignment: .top)
    }

    private var headerForeground: Color {
        colorScheme == .dark ? .white.opacity(0.9) : Color(hex: "1E3A5F").opacity(0.82)
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(coordinator.stepLabel)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(headerForeground.opacity(0.82))
                .id(selectedLanguage)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.45))
                    Capsule()
                        .fill(Color(hex: "2563EB"))
                        .frame(width: progressWidth(for: geometry.size.width))
                }
            }
            .frame(height: 6)
        }
    }

    private func progressWidth(for totalWidth: CGFloat) -> CGFloat {
        let count = PersonalizationOnboardingManifest.questions.count
        guard count > 0 else { return 0 }
        let progress = CGFloat(coordinator.currentIndex + 1) / CGFloat(count)
        return max(totalWidth * progress, 6)
    }

    private func questionPage(_ question: PersonalizationSurveyQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(LocalizedStringKey(stringLiteral: question.titleKey))
                        .font(.system(size: titleSize, weight: .black, design: .rounded))
                        .foregroundStyle(Color(uiColor: .label))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(LocalizedStringKey(stringLiteral: question.subtitleKey))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
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
                    .foregroundStyle(backButtonForeground)
                    .frame(width: 48, height: 52)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(PersonalizationGlassChrome.inactiveStroke, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(coordinator.isFirstPage)

            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86)) {
                    coordinator.next()
                }
            } label: {
                HStack(spacing: 10) {
                    Text(LocalizedStringKey("Continue"))
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(Color(uiColor: .label))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AnyShapeStyle(.ultraThinMaterial))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PersonalizationGlassChrome.stroke, lineWidth: 1)
                }
                .shadow(color: PersonalizationGlassChrome.shadow, radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(!coordinator.canContinue)
            .opacity(coordinator.canContinue ? 1 : 0.55)
        }
        .padding(.bottom, 6)
    }

    private var backButtonForeground: Color {
        Color(uiColor: .label).opacity(coordinator.isFirstPage ? 0.28 : 0.88)
    }

    private var completionMoment: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            Image(systemName: "sparkles")
                .font(.system(size: 54, weight: .black))
                .foregroundStyle(Color(hex: "2563EB"))
                .symbolEffect(.bounce, value: coordinator.showCompletionMoment)

            VStack(spacing: 12) {
                Text(LocalizedStringKey("Your mission profile is ready"))
                    .font(.system(size: titleSize, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(uiColor: .label))

                Text(LocalizedStringKey("We’ll use this to shape your journey from here."))
                    .font(.system(size: 17, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
            .frame(maxWidth: 420)

            Spacer(minLength: 0)

            Button {
                coordinator.finishAfterCompletionMoment()
                onFinish()
            } label: {
                HStack(spacing: 10) {
                    Text(LocalizedStringKey("Enter mission control"))
                        .font(.system(size: 16, weight: .bold))

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(Color(uiColor: .label))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AnyShapeStyle(.ultraThinMaterial))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PersonalizationGlassChrome.stroke, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, 6)
        }
        .padding(.horizontal, 24)
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
