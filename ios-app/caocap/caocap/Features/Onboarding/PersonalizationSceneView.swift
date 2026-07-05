import SwiftUI

/// Single-scene compositor: backdrop, moon, heroes, content, and chrome share one coordinate space.
struct PersonalizationSceneView: View {
    @Bindable var coordinator: PersonalizationOnboardingCoordinator
    let selectedLanguage: String
    let reduceMotion: Bool
    let onContinue: () -> Void
    let onFinish: () -> Void

    @State private var bottomChromeHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let totalBottomChrome = bottomChromeHeight
                + PersonalizationTheme.verticalInset
            let standLineY = MoonStageLayout.heroStandLineY(
                screenWidth: geometry.size.width,
                screenHeight: geometry.size.height,
                bottomChromeHeight: totalBottomChrome
            )
            let heroMode: PersonalizationHeroLayer.Mode = coordinator.isCopilotPickerStep ? .picker : .companion
            let showsHeroLayer = coordinator.isCopilotPickerStep || coordinator.showsCompanionCopilotHero

            ZStack {
                PersonalizationSpaceBackdrop()
                PersonalizationMoonStage()

                if showsHeroLayer {
                    PersonalizationHeroLayer(
                        coordinator: coordinator,
                        mode: heroMode,
                        standLineY: standLineY,
                        screenWidth: geometry.size.width
                    )
                }

                if coordinator.isCopilotPickerStep
                    && !coordinator.showCompletionMoment
                    && coordinator.hasUserSelectedCopilot {
                    PersonalizationSelectedCopilotInfo(coordinator: coordinator)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .transition(PersonalizationSelectedCopilotInfo.appearTransition(reduceMotion: reduceMotion))
                        .allowsHitTesting(false)
                }

                if coordinator.showCompletionMoment {
                    PersonalizationChrome.CompletionMoment {
                        coordinator.finishAfterCompletionMoment()
                        onFinish()
                    }
                } else {
                    questionFlow
                }
            }
            .animation(copilotPickerAnimation, value: coordinator.hasUserSelectedCopilot)
            .animation(copilotPickerAnimation, value: coordinator.selectedCopilot)
        }
    }

    private var copilotPickerAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.44, dampingFraction: 0.78)
    }

    private var questionFlow: some View {
        VStack(spacing: 0) {
            PersonalizationChrome.TopBar {
                coordinator.requestSkip()
            }

            PersonalizationChrome.ProgressBar(
                stepLabel: coordinator.stepLabel,
                currentIndex: coordinator.currentIndex,
                stepCount: PersonalizationOnboardingManifest.steps.count
            )
            .padding(.top, 8)
            .id(selectedLanguage)

            TabView(selection: $coordinator.currentIndex) {
                ForEach(Array(PersonalizationOnboardingManifest.steps.enumerated()), id: \.offset) { index, step in
                    stepContent(step)
                        .tag(index)
                }
            }
            .id(selectedLanguage)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86), value: coordinator.currentIndex)
            .allowsHitTesting(!coordinator.isCopilotPickerStep)

            Spacer(minLength: 0)
                .allowsHitTesting(!coordinator.isCopilotPickerStep)

            bottomChrome
        }
        .padding(.horizontal, PersonalizationTheme.horizontalInset)
        .padding(.vertical, PersonalizationTheme.verticalInset)
    }

    @ViewBuilder
    private func stepContent(_ step: PersonalizationStepKind) -> some View {
        switch step {
        case .copilotPicker(let content):
            PersonalizationCopilotStepContent(content: content)
        case .surveyQuestion(let question):
            PersonalizationSurveyStepContent(
                question: question,
                coordinator: coordinator,
                showsCompanionHero: coordinator.showsCompanionCopilotHero
            )
        }
    }

    private var bottomChrome: some View {
        VStack(spacing: 0) {
            if coordinator.isCopilotPickerStep {
                PersonalizationChrome.CopilotFootnote(
                    footnoteKey: PersonalizationOnboardingManifest.copilotPickerContent.footnoteKey
                )
            }

            PersonalizationChrome.BottomBar(
                isFirstPage: coordinator.isFirstPage,
                canContinue: coordinator.canContinue,
                reduceMotion: reduceMotion,
                onBack: { coordinator.back() },
                onContinue: onContinue
            )
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: PersonalizationBottomChromeHeightKey.self, value: proxy.size.height)
            }
        }
        .onPreferenceChange(PersonalizationBottomChromeHeightKey.self) { height in
            bottomChromeHeight = height
        }
    }
}
