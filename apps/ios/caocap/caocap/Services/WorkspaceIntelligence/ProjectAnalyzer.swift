import Foundation

/// Represents a potential improvement or action identified by analyzing the project nodes.
public struct ProjectSuggestion: Identifiable, Equatable {
    public let id: UUID
    /// Short title for the suggestion.
    public let title: String
    /// More detailed explanation for the user.
    public let detail: String
    /// The prompt that will be sent to CoCaptain if the user applies this suggestion.
    public let suggestedPrompt: String
    public let severity: Severity

    /// The urgency or impact level of the suggestion.
    public enum Severity {
        case info
        case warning
    }

    public init(id: UUID = UUID(), title: String, detail: String, suggestedPrompt: String, severity: Severity = .info) {
        self.id = id
        self.title = title
        self.detail = detail
        self.suggestedPrompt = suggestedPrompt
        self.severity = severity
    }
}

/// A pure service that inspects the current node graph and surfaces structural recommendations.
public struct ProjectAnalyzer {
    public init() {}

    /// Analyzes the given nodes and returns a list of actionable suggestions.
    public func analyze(nodes: [SpatialNode]) -> [ProjectSuggestion] {
        var suggestions: [ProjectSuggestion] = []

        for node in nodes {
            if CoCaptainReviewLifecycle.hasUnresolvedPersistedRecords(
                in: node.agentState
            ) {
                suggestions.append(ProjectSuggestion(
                    title: "\(node.title) has pending CoCaptain reviews",
                    detail: "Open this node's CoCaptain panel to approve or reject staged changes.",
                    suggestedPrompt: "Summarize the pending review items for \(node.title).",
                    severity: .warning
                ))
            }
        }

        return suggestions
    }
}
