import Foundation

/// The user's chosen co-pilot persona from personalization onboarding.
enum CopilotPersona: String, Codable, CaseIterable, Equatable, Identifiable {
    case cocaptain
    case costar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cocaptain: return "CoCaptain"
        case .costar: return "CoStar"
        }
    }

    var avatarImageName: String {
        switch self {
        case .cocaptain: return "CopilotAvatarCocaptain"
        case .costar: return "CopilotAvatarCostar"
        }
    }

    var accentHex: String {
        switch self {
        case .cocaptain: return "4DB6FF"
        case .costar: return "A78BFA"
        }
    }

    var nameKey: String {
        switch self {
        case .cocaptain: return "personalization.copilot.cocaptain.name"
        case .costar: return "personalization.copilot.costar.name"
        }
    }

    var roleKey: String {
        switch self {
        case .cocaptain: return "personalization.copilot.cocaptain.role"
        case .costar: return "personalization.copilot.costar.role"
        }
    }

    var taglineKey: String {
        switch self {
        case .cocaptain: return "personalization.copilot.cocaptain.tagline"
        case .costar: return "personalization.copilot.costar.tagline"
        }
    }

    var mantra: String {
        switch self {
        case .cocaptain:
            return "Code without fear. Build without limits. Orbit the impossible."
        case .costar:
            return "Dream it in your mind. Map it on the canvas. Launch it to the world."
        }
    }
}
