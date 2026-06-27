import Lottie
import SwiftUI

/// Full-screen confetti celebration for a successful publish.
struct PublishConfettiView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !reduceMotion, let animation = loadAnimation() {
            LottieView(animation: animation)
                .playbackMode(.playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce)))
                .animationSpeed(1)
                .configure(\.contentMode, to: .scaleAspectFill)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private func loadAnimation() -> LottieAnimation? {
        if let path = Bundle.main.path(forResource: "confetti", ofType: "json", inDirectory: "Lottie") {
            return LottieAnimation.filepath(path)
        }
        return LottieAnimation.named("confetti")
    }
}

struct PublishPrimaryButtonStyle: ButtonStyle {
    var tint: Color = .blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(tint.opacity(configuration.isPressed ? 0.85 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct PublishSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.blue)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color.blue.opacity(configuration.isPressed ? 0.22 : 0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension View {
    func publishPrimaryButton(tint: Color = .blue) -> some View {
        buttonStyle(PublishPrimaryButtonStyle(tint: tint))
    }

    func publishSecondaryButton() -> some View {
        buttonStyle(PublishSecondaryButtonStyle())
    }
}
