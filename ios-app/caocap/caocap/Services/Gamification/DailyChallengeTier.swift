import Foundation

public enum DailyChallengeTier: String, Codable, CaseIterable, Sendable {
    case iron
    case gold
    case diamond

    public var xpReward: Int {
        switch self {
        case .iron: return 10
        case .gold: return 25
        case .diamond: return 50
        }
    }

    public var badgeImageName: String {
        switch self {
        case .iron: return "iron-badge"
        case .gold: return "gold-badge"
        case .diamond: return "diamond-badge"
        }
    }
}
