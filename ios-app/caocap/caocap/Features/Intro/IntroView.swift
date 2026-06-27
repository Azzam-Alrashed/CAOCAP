import SwiftUI

/// Frosted-glass styling for illustration intro bottom chrome (CTA + pagination).
private enum IntroGlassChrome {
    static let foreground = Color(hex: "1E3A5F")
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

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    var body: some View {
        ZStack {
            IntroBackdrop(step: currentStep, isBreathing: isBreathing && !reduceMotion)

            VStack(spacing: 0) {
                topBar

                TabView(selection: $coordinator.currentIndex) {
                    ForEach(IntroManifest.steps) { step in
                        IntroPageView(
                            step: step,
                            isBreathing: isBreathing && !reduceMotion
                        )
                        .tag(step.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomBar
            }
            .padding(.horizontal, currentStep.usesIllustrationBackground ? 20 : 24)
            .padding(.vertical, 18)
        }
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
        Group {
            if currentStep.usesIllustrationBackground {
                switch currentStep.resolvedTopBarStyle {
                case .leadingChrome:
                    illustrationLeadingChrome
                case .splitChrome:
                    illustrationSplitChrome
                }
            } else {
                standardTopBar
            }
        }
        .frame(height: currentStep.usesIllustrationBackground ? 56 : 44, alignment: .top)
    }

    private var illustrationLeadingChrome: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text("CAOCAP")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.9))

                Button {
                    finishIntro(skipping: true)
                } label: {
                    Text("Skip")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
    }

    private var illustrationSplitChrome: some View {
        HStack(alignment: .top) {
            Text("CAOCAP")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.9))

            Spacer(minLength: 0)

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

    private var standardTopBar: some View {
        HStack {
            Text("CAOCAP")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.primary.opacity(0.78))

            Spacer()

            Button {
                finishIntro(skipping: true)
            } label: {
                Text("Skip")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 22) {
            IntroProgressDots(
                count: IntroManifest.steps.count,
                currentIndex: coordinator.currentIndex,
                accent: currentAccent,
                secondaryAccent: secondaryAccent,
                usesLightBottomChrome: currentStep.usesIllustrationBackground
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
                        Text(currentStep.ctaLabel)
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
                        if currentStep.usesIllustrationBackground {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(IntroGlassChrome.stroke, lineWidth: 1)
                        }
                    }
                    .shadow(
                        color: ctaShadowColor,
                        radius: currentStep.usesIllustrationBackground ? 12 : 18,
                        x: 0,
                        y: currentStep.usesIllustrationBackground ? 6 : 10
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, currentStep.usesIllustrationBackground ? 6 : 14)
    }

    private var backButtonForeground: Color {
        if currentStep.usesIllustrationBackground {
            return Color(hex: "1E3A5F").opacity(coordinator.isFirstPage ? 0.28 : 0.88)
        }
        return .primary.opacity(coordinator.isFirstPage ? 0.25 : 0.75)
    }

    private var backButtonBackground: some ShapeStyle {
        if currentStep.usesIllustrationBackground {
            return AnyShapeStyle(Color.white.opacity(0.82))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    private var backButtonStroke: Color {
        if currentStep.usesIllustrationBackground {
            return IntroGlassChrome.inactiveStroke
        }
        return Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06)
    }

    private var ctaForeground: Color {
        currentStep.usesIllustrationBackground ? IntroGlassChrome.foreground : .white
    }

    private var ctaFillStyle: AnyShapeStyle {
        if currentStep.usesIllustrationBackground {
            return AnyShapeStyle(.ultraThinMaterial)
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [currentAccent, secondaryAccent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var ctaShadowColor: Color {
        if currentStep.usesIllustrationBackground {
            return IntroGlassChrome.shadow
        }
        return currentAccent.opacity(colorScheme == .dark ? 0.38 : 0.28)
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

/// Full-bleed background layer for each intro step.
private struct IntroBackdrop: View {
    let step: IntroStepContent
    let isBreathing: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if let imageName = step.backgroundImageName {
                illustrationBackground(imageName: imageName)
            } else {
                standardBackground
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

    @ViewBuilder
    private var standardBackground: some View {
        baseColor
            .ignoresSafeArea()

        LinearGradient(
            colors: gradientWashColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        GeometryReader { geometry in
            Image("SpaceSketchBG")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .opacity(colorScheme == .dark ? 0.16 : 0.09)
                .blendMode(colorScheme == .dark ? .screen : .multiply)
        }
        .ignoresSafeArea()

        RadialGradient(
            colors: [
                Color(hex: step.tertiaryAccentHex).opacity(colorScheme == .dark ? 0.22 : 0.2),
                Color.clear
            ],
            center: .bottomTrailing,
            startRadius: 20,
            endRadius: 520
        )
        .ignoresSafeArea()
        .scaleEffect(isBreathing ? 1.08 : 0.98)
    }

    private var baseColor: Color {
        colorScheme == .dark ? Color(hex: "080A12") : Color(hex: "FBFCFF")
    }

    private var gradientWashColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(hex: step.accentHex).opacity(0.26),
                Color(hex: step.secondaryAccentHex).opacity(0.16),
                Color(hex: "080A12"),
                Color(hex: step.tertiaryAccentHex).opacity(0.13)
            ]
        }

        return [
            Color.white,
            Color(hex: step.accentHex).opacity(0.16),
            Color(hex: step.secondaryAccentHex).opacity(0.14),
            Color(hex: step.tertiaryAccentHex).opacity(0.12)
        ]
    }
}

/// Page content for a single intro step.
private struct IntroPageView: View {
    let step: IntroStepContent
    let isBreathing: Bool

    var body: some View {
        if step.usesIllustrationBackground {
            illustrationLayout
        } else {
            standardLayout
        }
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
                Text(step.title)
                    .font(.system(size: titleSize, weight: .black, design: .rounded))
                    .multilineTextAlignment(placement.horizontalAlignment == .center ? .center : .leading)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 2)

                Text(step.message)
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

    private var standardLayout: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 14)

            IntroSymbolHero(step: step, isBreathing: isBreathing)
                .frame(height: heroHeight)

            VStack(spacing: 16) {
                Text(step.title)
                    .font(.system(size: titleSize, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.74)
                    .fixedSize(horizontal: false, vertical: true)

                Text(step.message)
                    .font(.system(size: 18, weight: .medium))
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 590)

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 4)
    }

    private var titleSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 38 : 32
    }

    private var heroHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 260 : 220
    }
}

/// Glassmorphic icon card used as the hero visual on standard intro pages.
private struct IntroSymbolHero: View {
    let step: IntroStepContent
    let isBreathing: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color { Color(hex: step.accentHex) }
    private var secondaryAccent: Color { Color(hex: step.secondaryAccentHex) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: 136, height: 136)
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.24 : 0.84),
                                    accent.opacity(colorScheme == .dark ? 0.34 : 0.24)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: accent.opacity(colorScheme == .dark ? 0.32 : 0.2), radius: 28, x: 0, y: 16)

            Image(systemName: step.systemImage)
                .font(.system(size: 54, weight: .black))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(
                    LinearGradient(
                        colors: [accent, secondaryAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(isBreathing ? 1.04 : 0.98)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A row of capsule dots that track the current page.
private struct IntroProgressDots: View {
    let count: Int
    let currentIndex: Int
    let accent: Color
    let secondaryAccent: Color
    var usesLightBottomChrome: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                if usesLightBottomChrome {
                    glassDot(isActive: index == currentIndex)
                        .animation(.spring(response: 0.3, dampingFraction: 0.84), value: currentIndex)
                } else {
                    Capsule()
                        .fill(dotFill(for: index))
                        .frame(width: index == currentIndex ? 28 : 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.84), value: currentIndex)
                }
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

    private func dotFill(for index: Int) -> some ShapeStyle {
        if index == currentIndex {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [accent, secondaryAccent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }

        return AnyShapeStyle(Color.primary.opacity(0.16))
    }
}

#Preview {
    IntroView(coordinator: IntroCoordinator(), onFinish: {})
}
