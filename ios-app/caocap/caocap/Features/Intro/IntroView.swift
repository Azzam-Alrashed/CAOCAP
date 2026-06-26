import SwiftUI

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
            .padding(.horizontal, 24)
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

    /// Clamps the coordinator index to valid manifest bounds before deriving
    /// step-specific colors, guarding against a briefly out-of-range index during animation.
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

    private var topBar: some View {
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
        .frame(height: 44)
    }

    private var bottomBar: some View {
        VStack(spacing: 22) {
            IntroProgressDots(
                count: IntroManifest.steps.count,
                currentIndex: coordinator.currentIndex,
                accent: currentAccent,
                secondaryAccent: secondaryAccent
            )

            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        coordinator.back()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary.opacity(coordinator.isFirstPage ? 0.25 : 0.75))
                        .frame(width: 48, height: 52)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), lineWidth: 1)
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
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [currentAccent, secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(color: currentAccent.opacity(colorScheme == .dark ? 0.38 : 0.28), radius: 18, x: 0, y: 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 14)
    }

    /// Calls the appropriate coordinator method depending on whether the user
    /// tapped Skip vs reached the end naturally, then invokes the parent callback.
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
/// Combines a solid base, a linear color wash derived from the step's accent palette,
/// a semi-transparent spatial sketch texture, and a radial vignette that breathes.
private struct IntroBackdrop: View {
    let step: IntroStepContent
    let isBreathing: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

/// Scrollable page content for a single intro step: hero icon above, title and body below.
private struct IntroPageView: View {
    let step: IntroStepContent
    let isBreathing: Bool

    var body: some View {
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
        UIDevice.current.userInterfaceIdiom == .pad ? 40 : 34
    }

    private var heroHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 260 : 220
    }
}

/// Glassmorphic icon card used as the hero visual on each intro page.
/// The SF Symbol is rendered with a gradient fill and optionally breathes when
/// the parent passes `isBreathing: true`.
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
/// The active dot is wider and filled with the step's accent gradient;
/// inactive dots use a muted primary color.
private struct IntroProgressDots: View {
    let count: Int
    let currentIndex: Int
    let accent: Color
    let secondaryAccent: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(dotFill(for: index))
                    .frame(width: index == currentIndex ? 28 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.84), value: currentIndex)
            }
        }
        .frame(height: 12)
    }

    /// Returns the gradient fill for the active dot and a flat muted fill for all others.
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
