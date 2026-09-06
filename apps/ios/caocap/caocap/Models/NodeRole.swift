import Foundation

public enum NodeRole: String, CaseIterable, Hashable {
    case subCanvas
    case custom

    public static let editableCanonicalRoles: [NodeRole] = []

    public var displayName: String {
        switch self {
        case .subCanvas: return "Sub-Canvas"
        case .custom: return "Custom"
        }
    }

    public var localizedDisplayName: String {
        LocalizationManager.shared.localizedString(displayName)
    }

    public var isEditableCanonicalRole: Bool {
        Self.editableCanonicalRoles.contains(self)
    }

    public func matches(node: SpatialNode) -> Bool {
        node.role == self
    }
}

extension NodeRole: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case NodeRole.subCanvas.rawValue:
            self = .subCanvas
        default:
            // Leftover "miniApp" and unknown roles become ordinary cards.
            self = .custom
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public extension SpatialNode {
    var role: NodeRole {
        switch type {
        case .subCanvas:
            return .subCanvas
        default:
            return .custom
        }
    }

    var isProtected: Bool {
        action != nil
    }
}
