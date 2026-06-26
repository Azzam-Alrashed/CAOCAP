import Foundation

struct IntroStepContent: Equatable, Identifiable {
    let id: Int
    let title: String
    let message: String
    let systemImage: String
    let accentHex: String
    let secondaryAccentHex: String
    let tertiaryAccentHex: String
    let ctaLabel: String
}
