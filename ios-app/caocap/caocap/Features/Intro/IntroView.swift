import SwiftUI

/// Frosted-glass styling for illustration intro bottom chrome (CTA + pagination).
private enum IntroGlassChrome {
    static let stroke = Color.white.opacity(0.62)
    static let inactiveStroke = Color.white.opacity(0.38)
    static let shadow = Color.black.opacity(0.1)
}

/// Full-screen intro tour that wraps an `IntroCoordinator`.
/// Steps are displayed in a paged `TabView` and the user can navigate forwards,
/// backwards, or skip entirely. A continuous "breathing" scale animation runs on
/// the icon and backdrop provided reduce-motion is not active.
struct IntroView: View {
    @Bindable var coordinator: IntroCoordinator
    let onFinish: () -> Void

    @AppStorage(LocalizationManager.languageStorageKey) private var selectedLanguage = "English"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    var body: some View {
        ZStack {
            IntroBackdrop(step: currentStep, isBreathing: isBreathing && !reduceMotion)

            VStack(spacing: 0) {
                topBar

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
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.locale, LocalizationManager.shared.locale(for: selectedLanguage))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }

    private var currentStep: IntroStepContent {
        IntroManifest.steps[
            min(max(coordinator.currentIndex, 0), IntroManifest.lastIndex)
        ]
    }

    private var currentAccent: Color {
        Color(hex: currentStep.accentHex)
    }

    private var secondaryAccent: Color {
        Color(hex: currentStep.secondaryAccentHex)
    }

    /// Illustration pages position chrome and copy around each background artwork.
    private var topBar: some View {
        HStack(alignment: .top) {
            Text("CAOCAP")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.9))

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                IntroLanguageButton(usesLightChrome: true)

                Button {
                    finishIntro(skipping: true)
                } label: {
                    Text("Skip")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 56, alignment: .top)
    }

    private var bottomBar: some View {
        VStack(spacing: 22) {
            IntroProgressDots(
                count: IntroManifest.steps.count,
                currentIndex: coordinator.currentIndex
            )

            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        coordinator.back()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(backButtonForeground)
                        .frame(width: 48, height: 52)
                        .background(backButtonBackground, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(backButtonStroke, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(coordinator.isFirstPage)

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        if coordinator.isLastPage {
                            finishIntro(skipping: false)
                        } else {
                            coordinator.next()
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(LocalizedStringKey(stringLiteral: currentStep.ctaLabelKey))
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Image(systemName: coordinator.isLastPage ? "arrow.right.circle.fill" : "arrow.right")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundStyle(ctaForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(ctaFillStyle)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(IntroGlassChrome.stroke, lineWidth: 1)
                    }
                    .shadow(
                        color: IntroGlassChrome.shadow,
                        radius: 12,
                        x: 0,
                        y: 6
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 6)
    }

    private var backButtonForeground: Color {
        Color(hex: "1E3A5F").opacity(coordinator.isFirstPage ? 0.28 : 0.88)
    }

    private var backButtonBackground: some ShapeStyle {
        AnyShapeStyle(Color.white.opacity(0.82))
    }

    private var backButtonStroke: Color {
        IntroGlassChrome.inactiveStroke
    }

    private var ctaForeground: Color {
        Color(uiColor: .label)
    }

    private var ctaFillStyle: AnyShapeStyle {
        AnyShapeStyle(.ultraThinMaterial)
    }

    private var ctaShadowColor: Color {
        IntroGlassChrome.shadow
    }

    private func finishIntro(skipping: Bool) {
        if skipping {
            coordinator.skip()
        } else {
            coordinator.complete()
        }
        onFinish()
    }
}

/// Full-bleed illustration background for each intro step.
private struct IntroBackdrop: View {
    let step: IntroStepContent
    let isBreathing: Bool

    var body: some View {
        Group {
            if let imageName = step.backgroundImageName {
                illustrationBackground(imageName: imageName)
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
                .scaleEffect(isBreathing ? 1.015 : 1.0)
                .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: isBreathing)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Page content for a single intro step.
private struct IntroPageView: View {
    let step: IntroStepContent

    var body: some View {
        illustrationLayout
    }

    /// Copy is placed in each illustration's open sky band; the middle stays clear for artwork.
    private var illustrationLayout: some View {
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

/// A row of capsule dots that track the current page.
private struct IntroProgressDots: View {
    let count: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                glassDot(isActive: index == currentIndex)
                    .animation(.spring(response: 0.3, dampingFraction: 0.84), value: currentIndex)
            }
        }
        .frame(height: 12)
    }

    private func glassDot(isActive: Bool) -> some View {
        Capsule()
            .fill(isActive ? .thinMaterial : .ultraThinMaterial)
            .overlay {
                Capsule()
                    .stroke(
                        isActive ? IntroGlassChrome.stroke : IntroGlassChrome.inactiveStroke,
                        lineWidth: 1
                    )
            }
            .frame(width: isActive ? 28 : 8, height: 8)
    }
}

#Preview {
    IntroView(coordinator: IntroCoordinator(), onFinish: {})
}
