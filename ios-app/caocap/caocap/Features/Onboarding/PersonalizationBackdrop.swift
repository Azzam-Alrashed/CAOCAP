import SwiftUI

/// Dark starry sky backdrop for personalization onboarding.
struct PersonalizationBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var galaxyPulse = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PersonalizationMoonTheme.skyTop,
                    PersonalizationMoonTheme.skyMid,
                    PersonalizationMoonTheme.skyBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            galaxyLayer
                .ignoresSafeArea()
                .allowsHitTesting(false)

            TwinklingStarField(reduceMotion: reduceMotion)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ShootingStarLayer(reduceMotion: reduceMotion)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                galaxyPulse = true
            }
        }
    }

    private var galaxyLayer: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(hex: "6366F1").opacity(galaxyPulse ? 0.28 : 0.18),
                    Color(hex: "4DB6FF").opacity(galaxyPulse ? 0.12 : 0.06),
                    Color.clear
                ],
                center: UnitPoint(x: 0.72, y: 0.22),
                startRadius: 20,
                endRadius: 480
            )

            AngularGradient(
                colors: [
                    Color(hex: "A78BFA").opacity(0.14),
                    Color(hex: "4DB6FF").opacity(0.10),
                    Color(hex: "6366F1").opacity(0.16),
                    Color(hex: "EC4899").opacity(0.08),
                    Color(hex: "A78BFA").opacity(0.14)
                ],
                center: UnitPoint(x: 0.68, y: 0.28)
            )
            .blur(radius: 48)
            .scaleEffect(1.35)
            .rotationEffect(.degrees(galaxyPulse ? 12 : -6))
            .opacity(galaxyPulse ? 0.55 : 0.40)
        }
    }
}

// MARK: - Star field

private struct TwinklingStarField: View {
    let reduceMotion: Bool

    private struct Star: Identifiable {
        let id: Int
        let x: CGFloat
        let y: CGFloat
        let diameter: CGFloat
        let phase: Double
        let opacity: Double
    }

    private static let stars: [Star] = {
        var rng = SeededRandomNumberGenerator(seed: 42)
        return (0..<72).map { index in
            Star(
                id: index,
                x: CGFloat.random(in: 0...1, using: &rng),
                y: CGFloat.random(in: 0...0.78, using: &rng),
                diameter: CGFloat.random(in: 1...2.4, using: &rng),
                phase: Double.random(in: 0...(Double.pi * 2), using: &rng),
                opacity: Double.random(in: 0.35...0.95, using: &rng)
            )
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 60 : 1 / 20)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for star in Self.stars {
                    let twinkle = reduceMotion
                        ? star.opacity
                        : star.opacity * (0.55 + 0.45 * sin(time * 1.4 + star.phase))
                    let rect = CGRect(
                        x: star.x * size.width,
                        y: star.y * size.height,
                        width: star.diameter,
                        height: star.diameter
                    )
                    let tint = star.id.isMultiple(of: 5) ? Color(hex: "4DB6FF") : Color.white
                    context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(twinkle)))
                }
            }
        }
    }
}

// MARK: - Shooting stars

private struct ShootingStarLayer: View {
    let reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    drawShootingStar(context: context, size: size, time: time, slot: 0, period: 5.2, seed: 11)
                    drawShootingStar(context: context, size: size, time: time, slot: 1, period: 6.8, seed: 29)
                }
            }
        }
    }

    private func drawShootingStar(
        context: GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        slot: Int,
        period: Double,
        seed: Int
    ) {
        let cycle = time.truncatingRemainder(dividingBy: period)
        let travelDuration = 0.42
        guard cycle < travelDuration else { return }

        let progress = cycle / travelDuration
        let startX = size.width * (0.15 + 0.35 * Double((seed * 17) % 100) / 100)
        let startY = size.height * (0.08 + 0.22 * Double((seed * 31) % 100) / 100)
        let length: CGFloat = 72 + CGFloat((seed * 7) % 40)
        let endX = startX + length * 0.85
        let endY = startY + length * 0.55

        let x = startX + (endX - startX) * progress
        let y = startY + (endY - startY) * progress
        let fade = 1 - progress

        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x - length * 0.35, y: y - length * 0.22))

        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    Color.white.opacity(0.9 * fade),
                    Color(hex: "4DB6FF").opacity(0.5 * fade),
                    Color.clear
                ]),
                startPoint: CGPoint(x: x, y: y),
                endPoint: CGPoint(x: x - length * 0.35, y: y - length * 0.22)
            ),
            lineWidth: 1.6
        )
    }
}

// MARK: - RNG

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xDEADBEEF : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
