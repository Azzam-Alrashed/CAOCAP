import SwiftUI

/// Full-screen intro tour that wraps an `IntroCoordinator`.
/// Steps are displayed in a paged `TabView` and the user can navigate forwards,
/// backwards, or skip entirely. A continuous "breathing" scale animation runs on
/// the backdrop when reduce-motion is not active.
struct IntroView: View {
    @Bindable var coordinator: IntroCoordinator
    let onFinish: () -> Void

    @AppStorage(LocalizationManager.languageStorageKey) private var selectedLanguage = "English"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false
    @State private var progress: Double = 0.0
    @State private var isPaused = false

    private let timerDuration: Double = 3.5

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            IntroBackdrop(
                backgroundImageName: currentStep.backgroundImageName,
                isBreathing: isBreathing && !reduceMotion
            )

            VStack(spacing: 0) {
                OnboardingFlowTopBar(palette: .introIllustration, onSkip: finishIntro)

                TabView(selection: $coordinator.currentIndex) {
                    ForEach(IntroManifest.steps) { step in
                        IntroPageView(step: step)
                            .tag(step.id)
                    }
                }
                .id(selectedLanguage)
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomBar
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPaused {
                        isPaused = true
                        triggerHaptic(.soft)
                    }
                }
                .onEnded { _ in
                    isPaused = false
                    triggerHaptic(.light)
                }
        )
        .onChange(of: coordinator.currentIndex) { _, _ in
            triggerHaptic(.medium)
        }
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, LocalizationManager.shared.locale(for: selectedLanguage))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
        .task(id: coordinator.currentIndex) {
            progress = 0.0
            let start = Date()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if Task.isCancelled { break }
                guard !isPaused else { continue }

                let elapsed = Date().timeIntervalSince(start)
                let current = min(elapsed / timerDuration, 1.0)
                withAnimation(.linear(duration: 0.1)) {
                    progress = current
                }

                if current >= 1.0 {
                    if !coordinator.isLastPage {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            coordinator.next()
                        }
                    }
                    break
                }
            }
        }
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    private var currentStep: IntroStepContent {
        IntroManifest.steps[
            min(max(coordinator.currentIndex, 0), IntroManifest.lastIndex)
        ]
    }

    private var bottomBar: some View {
        VStack(spacing: 22) {
            IntroProgressDots(
                count: IntroManifest.steps.count,
                currentIndex: coordinator.currentIndex,
                currentProgress: progress
            )

            HStack(spacing: 12) {
                OnboardingFlowBackButton(
                    foregroundOpacity: coordinator.isFirstPage ? 0.28 : 0.88,
                    isEnabled: !coordinator.isFirstPage
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        coordinator.back()
                    }
                }

                OnboardingPrimaryButton(
                    titleKey: currentStep.ctaLabelKey,
                    isLastStep: coordinator.isLastPage
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        if coordinator.isLastPage {
                            finishIntro()
                        } else {
                            coordinator.next()
                        }
                    }
                }
                .shadow(
                    color: coordinator.isLastPage ? Color.blue.opacity(0.6) : .clear,
                    radius: coordinator.isLastPage ? 16 : 0
                )
            }
        }
        .padding(.bottom, 6)
    }

    private func finishIntro() {
        coordinator.complete()
        onFinish()
    }
}

/// Full-bleed illustration background for each intro step.
private struct IntroBackdrop: View {
    let backgroundImageName: String?
    let isBreathing: Bool

    var body: some View {
        Group {
            if let backgroundImageName {
                illustrationBackground(imageName: backgroundImageName)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func illustrationBackground(imageName: String) -> some View {
        GeometryReader { geometry in
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .scaleEffect(isBreathing ? 1.025 : 1.0)
                .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: isBreathing)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Page content for a single intro step.
/// Copy is placed in each illustration's open sky band; the middle stays clear for artwork.
private struct IntroPageView: View {
    let step: IntroStepContent

    var body: some View {
        GeometryReader { geometry in
            let placement = step.resolvedTextPlacement
            let textWidth = placement.maxWidthFraction.map { geometry.size.width * $0 } ?? placement.maxWidth
            let hAlignment: HorizontalAlignment = placement.horizontalAlignment == .center ? .center : .leading
            let frameAlignment = resolvedFrameAlignment(for: placement)
            let yOffset = resolvedVerticalOffset(for: placement, in: geometry)

            VStack(alignment: hAlignment, spacing: 10) {
                Text(LocalizedStringKey(stringLiteral: step.titleKey))
                    .font(.system(size: titleSize, weight: .black, design: .rounded))
                    .multilineTextAlignment(placement.horizontalAlignment == .center ? .center : .leading)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 2)

                Text(LocalizedStringKey(stringLiteral: step.messageKey))
                    .font(.system(size: 16, weight: .medium))
                    .lineSpacing(4)
                    .multilineTextAlignment(placement.horizontalAlignment == .center ? .center : .leading)
                    .foregroundStyle(.white.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 2)
            }
            .frame(maxWidth: textWidth, alignment: placement.horizontalAlignment == .center ? .center : .leading)
            .padding(.top, placement.verticalAlignment == .top ? placement.topInset : 0)
            .offset(y: yOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
        }
    }

    private func resolvedFrameAlignment(for placement: IntroIllustrationTextPlacement) -> Alignment {
        let horizontal: HorizontalAlignment = placement.horizontalAlignment == .center ? .center : .leading
        let vertical: VerticalAlignment = placement.verticalAlignment == .top ? .top : .center
        return Alignment(horizontal: horizontal, vertical: vertical)
    }

    private func resolvedVerticalOffset(
        for placement: IntroIllustrationTextPlacement,
        in geometry: GeometryProxy
    ) -> CGFloat {
        switch placement.verticalAlignment {
        case .top:
            return 0
        case .center:
            return placement.verticalOffset
        case .aboveCenter:
            return -(geometry.size.height * 0.10) + placement.verticalOffset
        }
    }

    private var titleSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 38 : 32
    }
}

/// A row of capsule dots that track the current page and show real-time progress for the active dot.
private struct IntroProgressDots: View {
    let count: Int
    let currentIndex: Int
    let currentProgress: Double

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                glassDot(
                    isActive: index == currentIndex,
                    isCompleted: index < currentIndex,
                    progress: index == currentIndex ? currentProgress : (index < currentIndex ? 1.0 : 0.0)
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.84), value: currentIndex)
            }
        }
        .frame(height: 12)
    }

    private func glassDot(isActive: Bool, isCompleted: Bool, progress: Double) -> some View {
        let dotWidth: CGFloat = isActive ? 32 : 8
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.ultraThinMaterial)

                if isCompleted || isActive {
                    let fillRatio = max(0.0, min(progress, 1.0))
                    Capsule()
                        .fill(.white.opacity(0.95))
                        .frame(width: geo.size.width * CGFloat(fillRatio))
                }
            }
            .overlay {
                Capsule()
                    .stroke(
                        isActive ? OnboardingGlassChrome.stroke : OnboardingGlassChrome.inactiveStroke,
                        lineWidth: 1
                    )
            }
        }
        .frame(width: dotWidth, height: 8)
    }
}

#Preview {
    IntroView(coordinator: IntroCoordinator(), onFinish: {})
}
