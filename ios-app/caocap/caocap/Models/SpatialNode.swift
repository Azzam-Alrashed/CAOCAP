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
    case miniApp
    case subCanvas
    
    public var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .miniApp: return "Mini-App"
        case .subCanvas: return "Sub-Canvas"
        }
    }

    /// Default palette theme for each workflow node type on the canvas.
    public var defaultTheme: NodeTheme {
        switch self {
        case .miniApp: return .blue
        case .subCanvas: return .cyan
        case .standard: return .indigo
        }
    }

    public var defaultTitle: String {
        switch self {
        case .miniApp: return "Mini-App"
        case .subCanvas: return "New Canvas"
        case .standard: return "Standard"
        }
    }

    public var defaultSubtitle: String? {
        switch self {
        case .miniApp: return "Tap to run, build, and configure this mini-app."
        case .subCanvas: return "Tap to open this canvas"
        case .standard: return nil
        }
    }

    public var defaultIcon: String {
        switch self {
        case .miniApp: return "app.connected.to.app.below.fill"
        case .subCanvas: return "folder.fill"
        case .standard: return "square.grid.2x2"
        }
    }
}

public struct MiniAppState: Codable, Equatable, Hashable {
    public var srsText: String
    public var srsReadinessState: SRSReadinessState
    public var codeText: String
    public var compiledHTML: String?
    public var firebaseConfigText: String
    public var firebaseFirestorePath: String?

    public init(
        srsText: String = SRSScaffold.defaultText,
        srsReadinessState: SRSReadinessState? = nil,
        codeText: String = "",
        compiledHTML: String? = nil,
        firebaseConfigText: String = "",
        firebaseFirestorePath: String? = nil
    ) {
        self.srsText = srsText
        self.srsReadinessState = srsReadinessState ?? .empty
        self.codeText = codeText
        self.compiledHTML = compiledHTML
        self.firebaseConfigText = firebaseConfigText
        self.firebaseFirestorePath = firebaseFirestorePath
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
    public var miniApp: MiniAppState?
    
    /// Persisted node-scoped CoCaptain transcript and compact memory.
    public var agentState: NodeAgentState
    
    /// Programmable identity and behavior rules for this node's agent.
    public var agentProfile: AgentProfile

    /// The filename of the linked canvas for `.subCanvas` nodes.
    public var linkedCanvasFileName: String?
    
    public init(id: UUID = UUID(), type: NodeType = .standard, position: CGPoint, title: String, subtitle: String? = nil, icon: String? = nil, theme: NodeTheme = .blue, nextNodeId: UUID? = nil, connectedNodeIds: [UUID]? = nil, action: NodeAction? = nil, miniApp: MiniAppState? = nil, agentState: NodeAgentState = NodeAgentState(), agentProfile: AgentProfile = AgentProfile(), linkedCanvasFileName: String? = nil) {
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
        self.miniApp = type == .miniApp ? (miniApp ?? MiniAppState()) : miniApp
        self.agentState = agentState
        self.agentProfile = agentProfile
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
        case miniApp
        case agentState
        case agentProfile
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
        self.miniApp = try container.decodeIfPresent(MiniAppState.self, forKey: .miniApp)
        if self.type == .miniApp, self.miniApp == nil {
            self.miniApp = MiniAppState()
        }
        self.agentState = try container.decodeIfPresent(NodeAgentState.self, forKey: .agentState) ?? NodeAgentState()
        self.agentProfile = try container.decodeIfPresent(AgentProfile.self, forKey: .agentProfile) ?? AgentProfile()
        self.linkedCanvasFileName = try container.decodeIfPresent(String.self, forKey: .linkedCanvasFileName)
    }

    /// Repairs legacy saves where workflow nodes kept outdated titles, icons, or themes.
    public func applyingCanonicalThemeIfNeeded() -> SpatialNode {
        guard action == nil, type != .standard else { return self }

        var updated = self
        if theme == .blue, type != .miniApp {
            updated.theme = type.defaultTheme
        }

        return updated
    }
}
