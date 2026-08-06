import AudioToolbox
import SwiftUI
import UIKit

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
                        IntroPageView(
                            step: step,
                            isActive: step.id == coordinator.currentIndex
                        )
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

/// Page content for a single intro step with animated title and message typewriters.
private struct IntroPageView: View {
    let step: IntroStepContent
    let isActive: Bool

    @State private var isTitleFinished = false

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 12) {
                TypewriterText(
                    textKey: step.titleKey,
                    font: .system(size: titleSize, weight: .black, design: .rounded),
                    foregroundStyle: AnyShapeStyle(.white),
                    shadowRadius: 10,
                    delayNanoseconds: 0,
                    speedNanoseconds: 35_000_000,
                    playAudioHaptic: true,
                    isActive: isActive,
                    onFinished: {
                        isTitleFinished = true
                    }
                )

                TypewriterText(
                    textKey: step.messageKey,
                    font: .system(size: 17, weight: .medium),
                    foregroundStyle: AnyShapeStyle(.white.opacity(0.9)),
                    shadowRadius: 8,
                    delayNanoseconds: 120_000_000,
                    speedNanoseconds: 22_000_000,
                    playAudioHaptic: true,
                    isActive: isActive && isTitleFinished
                )
            }
            .frame(maxWidth: min(geometry.size.width - 40, 360), alignment: .center)
            .padding(.top, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onChange(of: isActive) { _, active in
            if !active {
                isTitleFinished = false
            }
        }
    }

    private var titleSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 38 : 32
    }
}

/// Character-by-character typewriter subtitle component with sound effects & haptics.
private struct TypewriterText: View {
    let textKey: String
    let font: Font
    let foregroundStyle: AnyShapeStyle
    let shadowRadius: CGFloat
    let delayNanoseconds: UInt64
    let speedNanoseconds: UInt64
    let playAudioHaptic: Bool
    let isActive: Bool
    let onFinished: (() -> Void)?

    @AppStorage(LocalizationManager.languageStorageKey) private var selectedLanguage = "English"
    @State private var visibleCount: Int = 0
    @State private var fullText: String = ""

    init(
        textKey: String,
        font: Font,
        foregroundStyle: AnyShapeStyle = AnyShapeStyle(.white),
        shadowRadius: CGFloat = 8,
        delayNanoseconds: UInt64 = 0,
        speedNanoseconds: UInt64 = 28_000_000,
        playAudioHaptic: Bool = true,
        isActive: Bool,
        onFinished: (() -> Void)? = nil
    ) {
        self.textKey = textKey
        self.font = font
        self.foregroundStyle = foregroundStyle
        self.shadowRadius = shadowRadius
        self.delayNanoseconds = delayNanoseconds
        self.speedNanoseconds = speedNanoseconds
        self.playAudioHaptic = playAudioHaptic
        self.isActive = isActive
        self.onFinished = onFinished
    }

    var body: some View {
        Text(displayedText)
            .font(font)
            .lineSpacing(4)
            .multilineTextAlignment(.center)
            .foregroundStyle(foregroundStyle)
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: .black.opacity(0.35), radius: shadowRadius, x: 0, y: 2)
            .task(id: isActive) {
                guard isActive else {
                    visibleCount = 0
                    return
                }
                let localized = LocalizationManager.shared.localizedString(
                    textKey,
                    language: selectedLanguage
                )
                fullText = localized
                visibleCount = 0

                if delayNanoseconds > 0 {
                    try? await Task.sleep(nanoseconds: delayNanoseconds)
                }

                let feedback = UISelectionFeedbackGenerator()
                feedback.prepare()

                for i in 1...localized.count {
                    if Task.isCancelled { break }
                    visibleCount = i

                    if playAudioHaptic && i % 2 == 0 {
                        feedback.selectionChanged()
                        AudioServicesPlaySystemSound(1104)
                    }

                    try? await Task.sleep(nanoseconds: speedNanoseconds)
                }

                if !Task.isCancelled {
                    onFinished?()
                }
            }
    }

    private var displayedText: String {
        guard !fullText.isEmpty else { return "" }
        let prefixEnd = fullText.index(fullText.startIndex, offsetBy: min(visibleCount, fullText.count))
        return String(fullText[..<prefixEnd])
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
