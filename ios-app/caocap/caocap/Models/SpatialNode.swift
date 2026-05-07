import Foundation
import CoreGraphics

public enum NodeAction: String, Codable, Equatable {
    case navigateHome
    case retryOnboarding
    case createNewProject
    case openSettings
    case openProfile
    case openProjectExplorer
    case resumeLastProject
    case summonCoCaptain
}

public enum NodeType: String, Codable, Equatable, CaseIterable {
    case standard
    case webView
    case srs
    case code
    case art
    
    public var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .webView: return "Web View"
        case .srs: return "SRS"
        case .code: return "Code"
        case .art: return "Art"
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
    
    /// Persisted PencilKit drawing data for .art nodes.
    public var drawingData: Data?

    /// Persisted node-scoped CoCaptain transcript and compact memory.
    public var agentState: NodeAgentState
    
    public init(id: UUID = UUID(), type: NodeType = .standard, position: CGPoint, title: String, subtitle: String? = nil, icon: String? = nil, theme: NodeTheme = .blue, nextNodeId: UUID? = nil, connectedNodeIds: [UUID]? = nil, action: NodeAction? = nil, htmlContent: String? = nil, textContent: String? = nil, srsReadinessState: SRSReadinessState? = nil, drawingData: Data? = nil, agentState: NodeAgentState = NodeAgentState()) {
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
        self.drawingData = drawingData
        self.agentState = agentState
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
        case drawingData
        case agentState
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
        self.action = try container.decodeIfPresent(NodeAction.self, forKey: .action)
        self.htmlContent = try container.decodeIfPresent(String.self, forKey: .htmlContent)
        self.textContent = try container.decodeIfPresent(String.self, forKey: .textContent)
        self.srsReadinessState = try container.decodeIfPresent(SRSReadinessState.self, forKey: .srsReadinessState)
        self.drawingData = try container.decodeIfPresent(Data.self, forKey: .drawingData)
        self.agentState = try container.decodeIfPresent(NodeAgentState.self, forKey: .agentState) ?? NodeAgentState()
    }
}
