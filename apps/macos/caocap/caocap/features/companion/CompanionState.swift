import AppKit
import Foundation

/// Visual mood for the desktop companion. V1 only uses `idle`.
enum CompanionMood: String, Equatable {
    case idle
}

/// Desktop companion character. Persisted locally; not a product requirement.
enum CompanionPersona: String, CaseIterable, Identifiable, Equatable {
    case cocaptain
    case costar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cocaptain: return "CoCaptain"
        case .costar: return "CoStar"
        }
    }

    var idleImageName: String {
        switch self {
        case .cocaptain: return "CoCaptainIdle"
        case .costar: return "CoStarIdle"
        }
    }
}

enum CompanionLayout {
    static let spriteSize: CGFloat = 112
    static let panelSize = NSSize(width: 144, height: 168)
    static let screenInset: CGFloat = 24
    static let clickSlop: CGFloat = 8
}

enum CompanionDefaults {
    static let isAwake = "companion.isAwake"
    static let originX = "companion.originX"
    static let originY = "companion.originY"
    static let persona = "companion.persona"
}
