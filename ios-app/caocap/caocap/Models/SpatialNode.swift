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

public enum NodeType: String, Codable, Equatable, Hashable, CaseIterable {
    case standard
    case webView
    case srs
    case code
    case art
    case text
    case number
    case table
    case calculation
    case display
    case aiAgent
    case chart
    
    public var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .webView: return "Web View"
        case .srs: return "SRS"
        case .code: return "Code"
        case .art: return "Art"
        case .text: return "Text"
        case .number: return "Number"
        case .table: return "Table"
        case .calculation: return "Calculation"
        case .display: return "Display"
        case .aiAgent: return "AI Agent"
        case .chart: return "Chart"
        }
    }
}

public enum ChartStyle: String, Codable, Equatable, CaseIterable {
    case bar
    case line
    case area

    public var displayName: String {
        switch self {
        case .bar: return "Bar Chart"
        case .line: return "Line Trend"
        case .area: return "Area Graph"
        }
    }

    public var icon: String {
        switch self {
        case .bar: return "chart.bar.fill"
        case .line: return "chart.line.uptrend.xyaxis"
        case .area: return "chart.xyaxis.line"
        }
    }
}

public enum ArithmeticOperation: String, Codable, Equatable, CaseIterable {
    case add = "+"
    case subtract = "-"
    case multiply = "×"
    case divide = "÷"
    
    public var icon: String {
        switch self {
        case .add: return "plus"
        case .subtract: return "minus"
        case .multiply: return "multiply"
        case .divide: return "divide"
        }
    }
}

public enum DisplayStyle: String, Codable, CaseIterable {
    case number
    case percentage
    case progress
    case gauge
    
    public var displayName: String {
        switch self {
        case .number: return "Big Number"
        case .percentage: return "Percentage"
        case .progress: return "Progress Bar"
        case .gauge: return "Gauge"
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
    
    /// Persisted PencilKit drawing data for .art nodes.
    public var drawingData: Data?

    /// Persisted node-scoped CoCaptain transcript and compact memory.
    public var agentState: NodeAgentState
    
    /// Programmable identity and behavior rules for this node's agent.
    public var agentProfile: AgentProfile
    
    /// The arithmetic operation to perform for calculation nodes.
    public var operation: ArithmeticOperation?
    
    /// The display style for display nodes.
    public var displayStyle: DisplayStyle?
    
    /// The computed result for calculation/display nodes.
    public var outputValue: Double?
    
    /// The computed text result for AI/Text nodes.
    public var aiResponse: String?
    
    /// The AI prompt template for AI-processing nodes.
    public var promptTemplate: String?

    /// The chart style for chart nodes.
    public var chartStyle: ChartStyle?

    /// The selected table column index for X-axis labels.
    public var chartXColumnIndex: Int?

    /// The selected table column index for Y-axis values.
    public var chartYColumnIndex: Int?

    /// Whether the source table's first row should be treated as headers.
    public var chartHasHeaderRow: Bool?
    
    /// IDs of nodes providing input data to this node.
    public var inputNodeIds: [UUID]?
    
    public init(id: UUID = UUID(), type: NodeType = .standard, position: CGPoint, title: String, subtitle: String? = nil, icon: String? = nil, theme: NodeTheme = .blue, nextNodeId: UUID? = nil, connectedNodeIds: [UUID]? = nil, action: NodeAction? = nil, htmlContent: String? = nil, textContent: String? = nil, srsReadinessState: SRSReadinessState? = nil, drawingData: Data? = nil, agentState: NodeAgentState = NodeAgentState(), agentProfile: AgentProfile = AgentProfile(), operation: ArithmeticOperation? = nil, displayStyle: DisplayStyle? = nil, outputValue: Double? = nil, aiResponse: String? = nil, promptTemplate: String? = nil, chartStyle: ChartStyle? = nil, chartXColumnIndex: Int? = nil, chartYColumnIndex: Int? = nil, chartHasHeaderRow: Bool? = nil, inputNodeIds: [UUID]? = nil) {
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
        self.agentProfile = agentProfile
        self.operation = operation
        self.displayStyle = displayStyle
        self.outputValue = outputValue
        self.aiResponse = aiResponse
        self.promptTemplate = promptTemplate
        self.chartStyle = chartStyle
        self.chartXColumnIndex = chartXColumnIndex
        self.chartYColumnIndex = chartYColumnIndex
        self.chartHasHeaderRow = chartHasHeaderRow
        self.inputNodeIds = inputNodeIds
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
        case agentProfile
        case operation
        case displayStyle
        case outputValue
        case aiResponse
        case promptTemplate
        case chartStyle
        case chartXColumnIndex
        case chartYColumnIndex
        case chartHasHeaderRow
        case inputNodeIds
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
        self.agentProfile = try container.decodeIfPresent(AgentProfile.self, forKey: .agentProfile) ?? AgentProfile()
        self.operation = try container.decodeIfPresent(ArithmeticOperation.self, forKey: .operation)
        self.displayStyle = try container.decodeIfPresent(DisplayStyle.self, forKey: .displayStyle)
        self.outputValue = try container.decodeIfPresent(Double.self, forKey: .outputValue)
        self.aiResponse = try container.decodeIfPresent(String.self, forKey: .aiResponse)
        self.promptTemplate = try container.decodeIfPresent(String.self, forKey: .promptTemplate)
        self.chartStyle = try container.decodeIfPresent(ChartStyle.self, forKey: .chartStyle)
        self.chartXColumnIndex = try container.decodeIfPresent(Int.self, forKey: .chartXColumnIndex)
        self.chartYColumnIndex = try container.decodeIfPresent(Int.self, forKey: .chartYColumnIndex)
        self.chartHasHeaderRow = try container.decodeIfPresent(Bool.self, forKey: .chartHasHeaderRow)
        self.inputNodeIds = try container.decodeIfPresent([UUID].self, forKey: .inputNodeIds)
    }
}
