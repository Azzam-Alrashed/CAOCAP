import SwiftUI

/// Temporary handoff screen shown while the new personalization experience is designed.
struct PersonalizationOnboardingView: View {
    @Bindable var coordinator: PersonalizationOnboardingCoordinator
    let onBackToIntro: () -> Void
    let onFinish: () -> Void

    @AppStorage(LocalizationManager.languageStorageKey) private var selectedLanguage = "English"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color(hex: "F7F5F2")
                .ignoresSafeArea()

            GeometryReader { geometry in
                Image("SpaceSketchBG")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .opacity(0.2)
            .blendMode(.multiply)
            .accessibilityHidden(true)

            OnboardingFlowTopBar(palette: .lightSurface) {
                coordinator.skip()
                onFinish()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Text(pageTitle)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "17213D"))
                .multilineTextAlignment(.center)
                .frame(width: 240)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 140)

            Ellipse()
                .stroke(Color(hex: "3157D5").opacity(0.12), lineWidth: 1)
                .frame(width: 340, height: 220)
                .rotationEffect(.degrees(18))
                .accessibilityHidden(true)

            Ellipse()
                .stroke(Color(hex: "3157D5").opacity(0.22), lineWidth: 1)
                .frame(width: 260, height: 160)
                .rotationEffect(.degrees(-12))
                .accessibilityHidden(true)

            if isCodingLevelPage {
                if reduceMotion {
                    codingLevelOrbit(angle: 3.7)
                } else {
                    TimelineView(.animation) { context in
                        let angle = context.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: 12) / 12 * .pi * 2
                        codingLevelOrbit(angle: angle)
                    }
                }
            } else {
                if reduceMotion {
                    orbitingAvatars(angle: 3.7)
                } else {
                    TimelineView(.animation) { context in
                        let angle = context.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: 16) / 16 * .pi * 2
                        orbitingAvatars(angle: angle)
                    }
                }
            }

            if isCodingLevelPage {
                selectedCopilotAvatar
            } else {
                Image(systemName: "sparkle")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(starColor)
                    .animation(.easeInOut(duration: 0.3), value: coordinator.selectedCopilot)
                    .accessibilityHidden(true)
            }

            VStack {
                Spacer()

                if isCodingLevelPage {
                    codingLevelTrack
                        .padding(.horizontal, 20)
                        .padding(.bottom, 22)
                }

                HStack(spacing: 12) {
                    Button(action: handleBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 54, height: 54)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(hex: "17213D"))
                    .background(Color.white, in: Circle())
                    .accessibilityLabel(Text(LocalizedStringKey("Back")))

                    Button {
                        handleContinue()
                    } label: {
                        Text(continueButtonTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(Color(hex: "17213D"), in: Capsule())
                    .opacity(canContinue ? 1 : 0.42)
                    .disabled(!canContinue)
                }
            }
            .padding(24)
        }
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, LocalizationManager.shared.locale(for: selectedLanguage))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var continueButtonTitle: LocalizedStringKey {
        if isCodingLevelPage {
            return "Continue"
        }

        switch coordinator.selectedCopilot {
        case .cocaptain: return "Choose CoCaptain"
        case .costar: return "Choose CoStar"
        case nil: return "Choose a co-pilot"
        }
    }

    private var pageTitle: LocalizedStringKey {
        isCodingLevelPage
            ? "personalization.coding_level.title"
            : "personalization.copilot.title"
    }

    private var isCodingLevelPage: Bool {
        switch coordinator.currentPage {
        case .copilot: return false
        case .codingLevel: return true
        }
    }

    private var canContinue: Bool {
        isCodingLevelPage || coordinator.selectedCopilot != nil
    }

    private func handleBack() {
        if isCodingLevelPage {
            coordinator.showCopilot()
        } else {
            onBackToIntro()
        }
    }

    private func handleContinue() {
        if isCodingLevelPage {
            coordinator.complete()
            onFinish()
        } else {
            coordinator.showCodingLevel()
        }
    }

    private var starColor: Color {
        guard let selectedCopilot = coordinator.selectedCopilot else {
            return Color(hex: "F59E0B")
        }
        return Color(hex: selectedCopilot.accentHex)
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
                        .fill(Color.white.opacity(0.92))
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
                    .foregroundStyle(Color(hex: "17213D"))
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
                    .background(Color.white.opacity(0.92), in: Circle())
                    .shadow(color: Color(hex: selectedCopilot.accentHex).opacity(0.24), radius: 16, y: 6)
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

    private var codingLevelTrack: some View {
        VStack(spacing: 10) {
            Text(coordinator.selectedCodingLevel.title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "17213D"))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: coordinator.selectedCodingLevel.rawValue)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.25))
                        .frame(height: 48)

                    if coordinator.selectedCodingLevel != .zero {
                        liquidCodingLevelFill(
                            width: codingLevelPosition(
                                for: coordinator.selectedCodingLevel,
                                width: geometry.size.width
                            )
                        )
                            .animation(
                                .spring(response: 0.24, dampingFraction: 0.82),
                                value: coordinator.selectedCodingLevel.rawValue
                            )
                    }

                    ForEach(PersonalizationCodingLevel.allCases, id: \.rawValue) { level in
                        Circle()
                            .fill(Color.white.opacity(0.32))
                            .frame(width: 8, height: 8)
                            .position(
                                x: codingLevelPosition(for: level, width: geometry.size.width),
                                y: 24
                            )
                    }

                    Circle()
                        .fill(.white)
                        .frame(width: 48, height: 48)
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                        .position(
                            x: codingLevelPosition(
                                for: coordinator.selectedCodingLevel,
                                width: geometry.size.width
                            ),
                            y: 24
                        )
                        .animation(
                            .spring(response: 0.24, dampingFraction: 0.82),
                            value: coordinator.selectedCodingLevel.rawValue
                        )
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateCodingLevel(
                                for: value.location.x,
                                trackWidth: geometry.size.width
                            )
                        }
                )
                .accessibilityElement()
                .accessibilityLabel(Text("Coding level"))
                .accessibilityValue(Text(coordinator.selectedCodingLevel.title))
                .accessibilityAdjustableAction { direction in
                    adjustCodingLevel(direction)
                }
            }
            .frame(height: 48)
        }
        .padding(16)
    }

    private func liquidCodingLevelFill(width: CGFloat) -> some View {
        ZStack {
            Color(hex: "3B9AF5")

            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                    GeometryReader { geometry in
                        ForEach(0..<3, id: \.self) { index in
                            let time = context.date.timeIntervalSinceReferenceDate
                            let duration = 3.8 + (Double(index) * 0.7)
                            let phase = (
                                (time / duration) + (Double(index) * 0.31)
                            ).truncatingRemainder(dividingBy: 1)
                            let size = bubbleSize(for: index)
                            let baseX = geometry.size.width * bubbleHorizontalPosition(for: index)
                            let drift = CGFloat(sin((time * 0.8) + Double(index))) * 2.5
                            let y = geometry.size.height + size
                                - (CGFloat(phase) * (geometry.size.height + (size * 2)))

                            Circle()
                                .fill(Color.white.opacity(0.13))
                                .overlay {
                                    Circle()
                                        .stroke(Color.white.opacity(0.14), lineWidth: 0.75)
                                }
                                .frame(width: size, height: size)
                                .position(
                                    x: min(max(baseX + drift, size), geometry.size.width - size),
                                    y: y
                                )
                        }
                    }
                }
            }
        }
        .frame(width: width, height: 48)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
    }

    private func bubbleSize(for index: Int) -> CGFloat {
        [5, 7, 4][index]
    }

    private func bubbleHorizontalPosition(for index: Int) -> CGFloat {
        [0.28, 0.58, 0.8][index]
    }

    private func codingLevelPosition(
        for level: PersonalizationCodingLevel,
        width: CGFloat
    ) -> CGFloat {
        let thumbRadius = 24.0
        let availableWidth = max(width - (thumbRadius * 2), 0)
        let progress = CGFloat(level.rawValue) / CGFloat(PersonalizationCodingLevel.allCases.count - 1)
        return thumbRadius + (availableWidth * progress)
    }

    private func updateCodingLevel(for locationX: CGFloat, trackWidth: CGFloat) {
        let thumbRadius = 24.0
        let availableWidth = max(trackWidth - (thumbRadius * 2), 1)
        let clampedX = min(max(locationX - thumbRadius, 0), availableWidth)
        let progress = clampedX / availableWidth
        let step = Int(
            (progress * CGFloat(PersonalizationCodingLevel.allCases.count - 1)).rounded()
        )
        guard let level = PersonalizationCodingLevel(rawValue: step),
              level != coordinator.selectedCodingLevel else { return }

        coordinator.selectCodingLevel(level)
        HapticsManager.shared.selectionChanged()
    }

    private func adjustCodingLevel(_ direction: AccessibilityAdjustmentDirection) {
        let currentStep = coordinator.selectedCodingLevel.rawValue
        let nextStep: Int

        switch direction {
        case .increment:
            nextStep = min(currentStep + 1, PersonalizationCodingLevel.allCases.count - 1)
        case .decrement:
            nextStep = max(currentStep - 1, 0)
        @unknown default:
            return
        }

        guard let level = PersonalizationCodingLevel(rawValue: nextStep),
              level != coordinator.selectedCodingLevel else { return }

        coordinator.selectCodingLevel(level)
        HapticsManager.shared.selectionChanged()
    }

    private func codingAsset(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: 58, height: 58)
            .shadow(color: Color(hex: "17213D").opacity(0.1), radius: 8, y: 4)
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
