import SwiftUI

struct PersonalizationOnboardingView: View {
    @Bindable var coordinator: PersonalizationOnboardingCoordinator
    let onBackToIntro: () -> Void
    let onFinish: () -> Void

    @AppStorage(LocalizationManager.languageStorageKey) private var selectedLanguage = "English"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            personalizationBackground
            currentPage
        }
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, LocalizationManager.shared.locale(for: selectedLanguage))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var personalizationBackground: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            GeometryReader { geometry in
                Image("SpaceSketchBG")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .opacity(colorScheme == .dark ? 0.4 : 0.25)
            .blendMode(colorScheme == .dark ? .screen : .multiply)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var currentPage: some View {
        switch coordinator.currentPage {
        case .copilot:
            standardPage(
                titleKey: "personalization.copilot.title",
                continueTitle: copilotContinueTitle
            ) {
                copilotOrbitScene
            } bottomAccessory: {
                EmptyView()
            }

        case .codingLevel:
            standardPage(
                titleKey: "personalization.coding_level.title",
                continueTitle: "Continue"
            ) {
                codingLevelOrbitScene
            } bottomAccessory: {
                PersonalizationCodingLevelPicker(
                    selection: coordinator.selectedCodingLevel,
                    onSelect: { coordinator.selectCodingLevel($0) }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
            }

        case .final:
            PersonalizationLaunchScene(
                rocketImageName: launchRocketImageName
            ) {
                handle(coordinator.complete())
            }
        }
    }

    private func standardPage<Scene: View, BottomAccessory: View>(
        titleKey: LocalizedStringKey,
        continueTitle: String,
        @ViewBuilder scene: () -> Scene,
        @ViewBuilder bottomAccessory: () -> BottomAccessory
    ) -> some View {
        ZStack {
            OnboardingFlowTopBar(palette: .adaptiveSurface) {
                handle(coordinator.skip())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Text(titleKey)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(width: 240)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 140)

            orbitPaths
            scene()

            VStack {
                Spacer()
                bottomAccessory()
                navigationControls(continueTitle: continueTitle)
            }
            .padding(24)
        }
    }

    private var orbitPaths: some View {
        ZStack {
            Ellipse()
                .stroke(
                    Color(hex: "3157D5").opacity(colorScheme == .dark ? 0.28 : 0.12),
                    lineWidth: 1
                )
                .frame(width: 340, height: 220)
                .rotationEffect(.degrees(18))

            Ellipse()
                .stroke(
                    Color(hex: "3157D5").opacity(colorScheme == .dark ? 0.46 : 0.22),
                    lineWidth: 1
                )
                .frame(width: 260, height: 160)
                .rotationEffect(.degrees(-12))
        }
        .accessibilityHidden(true)
    }

    private var copilotOrbitScene: some View {
        ZStack {
            if reduceMotion {
                orbitingAvatars(angle: 3.7)
            } else {
                TimelineView(.animation) { context in
                    let angle = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 16) / 16 * .pi * 2
                    orbitingAvatars(angle: angle)
                }
            }

            Image(systemName: "sparkle")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(starColor)
                .animation(.easeInOut(duration: 0.3), value: coordinator.selectedCopilot)
                .accessibilityHidden(true)
        }
    }

    private var codingLevelOrbitScene: some View {
        ZStack {
            if reduceMotion {
                codingLevelOrbit(angle: 3.7)
            } else {
                TimelineView(.animation) { context in
                    let angle = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 12) / 12 * .pi * 2
                    codingLevelOrbit(angle: angle)
                }
            }

            selectedCopilotAvatar
        }
    }

    private func navigationControls(continueTitle: String) -> some View {
        HStack(spacing: 12) {
            Button {
                handle(coordinator.back())
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 54, height: 54)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .background(.ultraThinMaterial, in: Circle())
            .overlay {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .accessibilityLabel(Text(LocalizedStringKey("Back")))

            OnboardingPrimaryButton(
                titleKey: continueTitle,
                isLastStep: false
            ) {
                handle(coordinator.advance())
            }
            .opacity(coordinator.canAdvance ? 1 : 0.42)
            .disabled(!coordinator.canAdvance)
        }
    }

    private var copilotContinueTitle: String {
        switch coordinator.selectedCopilot {
        case .cocaptain:
            return "Choose CoCaptain"
        case .costar:
            return "Choose CoStar"
        case nil:
            return "Choose a co-pilot"
        }
    }

    private var starColor: Color {
        guard let selectedCopilot = coordinator.selectedCopilot else {
            return Color(hex: "F59E0B")
        }
        return Color(hex: selectedCopilot.accentHex)
    }

    private var launchRocketImageName: String {
        switch coordinator.selectedCopilot {
        case .costar:
            return "OnboardingLaunchRocketCoStar"
        case .cocaptain, nil:
            return "OnboardingLaunchRocketCoCaptain"
        }
    }

    private func handle(_ result: PersonalizationFlowResult) {
        switch result {
        case .continueInPersonalization:
            break
        case .returnToIntro:
            onBackToIntro()
        case .finished:
            onFinish()
        }
    }

    private func orbitAvatar(for persona: CopilotPersona) -> some View {
        let isSelected = coordinator.selectedCopilot == persona
        let hasSelection = coordinator.selectedCopilot != nil

        return Button {
            coordinator.toggleCopilot(persona)
            HapticsManager.shared.selectionChanged()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .systemBackground).opacity(0.92))
                        .frame(width: 76, height: 76)

                    Image(persona.avatarImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)

                    Circle()
                        .stroke(
                            Color(hex: persona.accentHex).opacity(isSelected ? 0.95 : 0),
                            lineWidth: 3
                        )
                        .frame(width: 80, height: 80)
                }
                .shadow(
                    color: Color(hex: persona.accentHex).opacity(isSelected ? 0.35 : 0.12),
                    radius: isSelected ? 16 : 10,
                    y: 5
                )

                Text(LocalizedStringKey(persona.nameKey))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.12 : 1)
        .opacity(hasSelection && !isSelected ? 0.5 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: coordinator.selectedCopilot)
        .accessibilityLabel(Text(LocalizedStringKey(persona.nameKey)))
        .accessibilityValue(Text(isSelected ? "Selected" : "Not selected"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func orbitingAvatars(angle: Double) -> some View {
        ZStack {
            orbitAvatar(for: .cocaptain)
                .offset(orbitOffset(for: angle))

            orbitAvatar(for: .costar)
                .offset(orbitOffset(for: angle + .pi))
        }
    }

    private var selectedCopilotAvatar: some View {
        Group {
            if let selectedCopilot = coordinator.selectedCopilot {
                Image(selectedCopilot.avatarImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 94, height: 94)
                    .background(Color(uiColor: .systemBackground).opacity(0.92), in: Circle())
                    .shadow(
                        color: Color(hex: selectedCopilot.accentHex).opacity(0.24),
                        radius: 16,
                        y: 6
                    )
                    .accessibilityHidden(true)
            }
        }
    }

    private func codingLevelOrbit(angle: Double) -> some View {
        ZStack {
            codingAsset("HTML")
                .offset(orbitOffset(for: angle))

            codingAsset("CSS")
                .offset(orbitOffset(for: angle + (.pi * 2 / 3)))

            codingAsset("JS")
                .offset(orbitOffset(for: angle + (.pi * 4 / 3)))
        }
    }

    private func codingAsset(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: 58, height: 58)
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.1),
                radius: 8,
                y: 4
            )
            .accessibilityHidden(true)
    }

    private func orbitOffset(for angle: Double) -> CGSize {
        let horizontalRadius = 130.0
        let verticalRadius = 80.0
        let rotation = -12.0 * Double.pi / 180
        let ellipseX = horizontalRadius * cos(angle)
        let ellipseY = verticalRadius * sin(angle)

        return CGSize(
            width: ellipseX * cos(rotation) - ellipseY * sin(rotation),
            height: ellipseX * sin(rotation) + ellipseY * cos(rotation)
        )
    }
}

#Preview {
    PersonalizationOnboardingView(
        coordinator: PersonalizationOnboardingCoordinator(),
        onBackToIntro: {},
        onFinish: {}
    )
}
