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

        let miniApps = nodes.filter { $0.type == .miniApp }

        for miniAppNode in miniApps {
            let srsText = miniAppNode.miniApp?.srsText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if srsText.isEmpty {
                suggestions.append(ProjectSuggestion(
                    title: "\(miniAppNode.title) SRS is blank",
                    detail: "Describe this Mini-App idea so CoCaptain can help refine and build it.",
                    suggestedPrompt: "Help me write the SRS for \(miniAppNode.title).",
                    severity: .info
                ))
            }

            let isCodeEmpty = miniAppNode.miniApp?.codeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
            if isCodeEmpty {
                suggestions.append(ProjectSuggestion(
                    title: "\(miniAppNode.title) code is empty",
                    detail: "CoCaptain can generate a starter app from this Mini-App's SRS.",
                    suggestedPrompt: "Generate a starter single-file HTML/CSS/JS app for \(miniAppNode.title).",
                    severity: .warning
                ))
            }
        }

        return suggestions
    }
}
