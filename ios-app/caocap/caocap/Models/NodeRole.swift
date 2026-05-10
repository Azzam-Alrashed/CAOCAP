import Foundation

public enum NodeRole: String, CaseIterable, Codable, Hashable {
    case srs
    case code
    case html
    case css
    case javascript
    case livePreview
    case text
    case calculation
    case display
    case aiAgent
    case chart
    case custom

    public static let editableCanonicalRoles: [NodeRole] = [
        .srs,
        .code,
        .html,
        .css,
        .javascript,
        .text,
        .calculation
    ]

    public var displayName: String {
        switch self {
        case .srs: return "SRS"
        case .code: return "Code"
        case .html: return "HTML"
        case .css: return "CSS"
        case .javascript: return "JavaScript"
        case .livePreview: return "Live Preview"
        case .text: return "Text"
        case .calculation: return "Calculation"
        case .display: return "Display"
        case .aiAgent: return "AI Agent"
        case .chart: return "Chart"
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
        case .text:
            return .text
        case .calculation:
            return .calculation
        case .display:
            return .display
        case .chart:
            return .chart
        case .code:
            switch title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "html":
                return .html
            case "css":
                return .css
            case "javascript":
                return .javascript
            default:
                return .code
            }
        case .aiAgent:
            return .aiAgent
        default:
            return .custom
        }
    }

    var isProtected: Bool {
        action != nil
    }
}
