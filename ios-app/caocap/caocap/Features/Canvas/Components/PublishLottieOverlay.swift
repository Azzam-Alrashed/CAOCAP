import SwiftUI

/// Button styles shared by publish flows.
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
