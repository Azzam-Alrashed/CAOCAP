import Foundation
import CoreGraphics

public enum NodeAction: String, Codable, Equatable {
    case navigateRoot
    case openSettings
    case openProfile
    case summonCoCaptain
    case proSubscription
}

public enum NodeType: String, Codable, Equatable, Hashable, CaseIterable {
    case standard
    case webView
    case srs
    case code
    case firebase
    case subCanvas
    
    public var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .webView: return "Web View"
        case .srs: return "SRS"
        case .code: return "Code"
        case .firebase: return "Firebase"
        case .subCanvas: return "Sub-Canvas"
        }
    }

    /// Default palette theme for each workflow node type on the canvas.
    public var defaultTheme: NodeTheme {
        switch self {
        case .webView: return .blue
        case .srs: return .purple
        case .code: return .orange
        case .firebase: return .pink
        case .subCanvas: return .cyan
        case .standard: return .indigo
        }
    }

    public var defaultTitle: String {
        switch self {
        case .webView: return "Live Preview"
        case .srs: return "Software Requirements (SRS)"
        case .code: return "Code"
        case .firebase: return "Firebase"
        case .subCanvas: return "New Canvas"
        case .standard: return "Standard"
        }
    }

    public var defaultSubtitle: String? {
        switch self {
        case .webView: return "Your current build renders here."
        case .srs: return "Define intent, people, flow, and success."
        case .code: return "HTML, CSS, and JavaScript in one file."
        case .firebase: return "Project settings → Your apps → Web app config"
        case .subCanvas: return "Tap to open this canvas"
        case .standard: return nil
        }
    }

    public var defaultIcon: String {
        switch self {
        case .webView: return "play.display"
        case .srs: return "doc.text.fill"
        case .code: return "chevron.left.slash.chevron.right"
        case .firebase: return "flame.fill"
        case .subCanvas: return "folder.fill"
        case .standard: return "square.grid.2x2"
        }
    }
}

public struct NodeAgentMessage: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var text: String
    public var isUser: Bool
    public var createdAt: Date

    public init(id: UUID = UUID(), text: String, isUser: Bool, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.createdAt = createdAt
    }
}

public struct NodeAgentState: Codable, Equatable, Hashable {
    public var messages: [NodeAgentMessage]
    public var memorySummary: String?

    public init(messages: [NodeAgentMessage] = [], memorySummary: String? = nil) {
        self.messages = messages
        self.memorySummary = memorySummary
    }
}

public struct AgentProfile: Codable, Equatable, Hashable {
    public var systemPrompt: String?
    public var roleName: String
    public var isAutoTriggerEnabled: Bool

    public init(systemPrompt: String? = nil, roleName: String = "Assistant", isAutoTriggerEnabled: Bool = false) {
        self.systemPrompt = systemPrompt
        self.roleName = roleName
        self.isAutoTriggerEnabled = isAutoTriggerEnabled
    }
}

public struct SpatialNode: Identifiable, Codable, Equatable {
    public let id: UUID
    public var type: NodeType
    public var position: CGPoint
    public var title: String
    public var subtitle: String?
    public var icon: String?
    public var theme: NodeTheme
    public var nextNodeId: UUID?
    public var connectedNodeIds: [UUID]?
    public var action: NodeAction?
    public var htmlContent: String?
    public var textContent: String?
    /// Persisted readiness state for .srs nodes. Derived by SRSReadinessEvaluator
    /// and stored so the canvas can display it without re-parsing text.
    public var srsReadinessState: SRSReadinessState?
    
    /// Persisted node-scoped CoCaptain transcript and compact memory.
    public var agentState: NodeAgentState
    
    /// Programmable identity and behavior rules for this node's agent.
    public var agentProfile: AgentProfile

    /// Optional default Firestore path for preview JS (`window.__caocapFirestoreDefaultPath`).
    public var firebaseFirestorePath: String?
    
    /// The filename of the linked canvas for `.subCanvas` nodes.
    public var linkedCanvasFileName: String?
    
    public init(id: UUID = UUID(), type: NodeType = .standard, position: CGPoint, title: String, subtitle: String? = nil, icon: String? = nil, theme: NodeTheme = .blue, nextNodeId: UUID? = nil, connectedNodeIds: [UUID]? = nil, action: NodeAction? = nil, htmlContent: String? = nil, textContent: String? = nil, srsReadinessState: SRSReadinessState? = nil, agentState: NodeAgentState = NodeAgentState(), agentProfile: AgentProfile = AgentProfile(), firebaseFirestorePath: String? = nil, linkedCanvasFileName: String? = nil) {
        self.id = id
        self.type = type
        self.position = position
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.theme = theme
        self.nextNodeId = nextNodeId
        self.connectedNodeIds = connectedNodeIds
        self.action = action
        self.htmlContent = htmlContent
        self.textContent = textContent
        self.srsReadinessState = srsReadinessState
        self.agentState = agentState
        self.agentProfile = agentProfile
        self.firebaseFirestorePath = firebaseFirestorePath
        self.linkedCanvasFileName = linkedCanvasFileName
    }

    public var displayTitle: String {
        LocalizationManager.shared.localizedNodeTitle(title)
    }

    public var displaySubtitle: String? {
        subtitle.map { LocalizationManager.shared.localizedNodeSubtitle($0) }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case position
        case title
        case subtitle
        case icon
        case theme
        case nextNodeId
        case connectedNodeIds
        case action
        case htmlContent
        case textContent
        case srsReadinessState
        case agentState
        case agentProfile
        case firebaseFirestorePath
        case linkedCanvasFileName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.type = try container.decode(NodeType.self, forKey: .type)
        self.position = try container.decode(CGPoint.self, forKey: .position)
        self.title = try container.decode(String.self, forKey: .title)
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon)
        self.theme = try container.decode(NodeTheme.self, forKey: .theme)
        self.nextNodeId = try container.decodeIfPresent(UUID.self, forKey: .nextNodeId)
        self.connectedNodeIds = try container.decodeIfPresent([UUID].self, forKey: .connectedNodeIds)
        if let actionString = try container.decodeIfPresent(String.self, forKey: .action) {
            self.action = NodeAction(rawValue: actionString)
        } else {
            self.action = nil
        }
        self.htmlContent = try container.decodeIfPresent(String.self, forKey: .htmlContent)
        self.textContent = try container.decodeIfPresent(String.self, forKey: .textContent)
        self.srsReadinessState = try container.decodeIfPresent(SRSReadinessState.self, forKey: .srsReadinessState)
        self.agentState = try container.decodeIfPresent(NodeAgentState.self, forKey: .agentState) ?? NodeAgentState()
        self.agentProfile = try container.decodeIfPresent(AgentProfile.self, forKey: .agentProfile) ?? AgentProfile()
        self.firebaseFirestorePath = try container.decodeIfPresent(String.self, forKey: .firebaseFirestorePath)
        self.linkedCanvasFileName = try container.decodeIfPresent(String.self, forKey: .linkedCanvasFileName)
    }

    /// Repairs legacy saves where workflow nodes kept outdated titles, icons, or themes.
    public func applyingCanonicalThemeIfNeeded() -> SpatialNode {
        guard action == nil, type != .standard else { return self }

        var updated = self
        if theme == .blue, type != .webView {
            updated.theme = type.defaultTheme
        }

        if updated.type == .code, updated.title == "New Logic" {
            updated.title = NodeType.code.defaultTitle
            updated.subtitle = NodeType.code.defaultSubtitle
            updated.icon = NodeType.code.defaultIcon
        }

        return updated
    }
}
