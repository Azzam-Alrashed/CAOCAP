import Foundation

public enum NodeRole: String, CaseIterable, Codable, Hashable {
    case srs
    case code
    case livePreview
    case firebase
    case subCanvas
    case custom

    public static let editableCanonicalRoles: [NodeRole] = [
        .srs,
        .code
    ]

    public var displayName: String {
        switch self {
        case .srs: return "SRS"
        case .code: return "Code"
        case .livePreview: return "Live Preview"
        case .firebase: return "Firebase"
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

public extension SpatialNode {
    var role: NodeRole {
        switch type {
        case .webView:
            return .livePreview
        case .srs:
            return .srs
        case .code:
            return .code
        case .firebase:
            return .firebase
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
