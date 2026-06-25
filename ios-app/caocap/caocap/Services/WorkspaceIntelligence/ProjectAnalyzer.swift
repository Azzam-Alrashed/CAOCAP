import Foundation

/// Represents a potential improvement or action identified by analyzing the project nodes.
public struct ProjectSuggestion: Identifiable, Equatable {
    public let id: UUID
    /// Short title for the suggestion (e.g., "Code node is empty").
    public let title: String
    /// More detailed explanation for the user.
    public let detail: String
    /// The prompt that will be sent to CoCaptain if the user applies this suggestion.
    public let suggestedPrompt: String
    public let severity: Severity

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

        let code = nodes.first(where: { $0.role == .code })
        let srs = nodes.first(where: { $0.role == .srs })

        // Rule: SRS is empty or blank
        if let srs, srs.textContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            suggestions.append(ProjectSuggestion(
                title: "SRS is blank",
                detail: "Describe your app idea here so CoCaptain can help you build it.",
                suggestedPrompt: "I have a blank SRS. Can you help me brainstorm requirements for a simple web app?",
                severity: .info
            ))
        }

        // Rule: canonical Code exists but is empty
        if let code {
            let isCodeEmpty = code.textContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
            if isCodeEmpty {
                let detail = srs != nil ? "CoCaptain can generate a starter app from your SRS." : "Start by adding a small HTML/CSS/JS app."
                let prompt = srs != nil ? "Can you generate a starter single-file web app based on my SRS requirements?" : "Generate a basic single-file HTML/CSS/JS app for me."

                suggestions.append(ProjectSuggestion(
                    title: "Code is empty",
                    detail: detail,
                    suggestedPrompt: prompt,
                    severity: .warning
                ))
            }
        }

        return suggestions
    }
}
