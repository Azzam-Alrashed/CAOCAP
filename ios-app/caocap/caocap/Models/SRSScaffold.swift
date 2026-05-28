import Foundation

public enum SRSScaffoldSection: String, CaseIterable, Hashable {
    case intent
    case whyItMatters
    case people
    case coreFlow
    case requirements
    case acceptanceChecks
    case constraints

    public var title: String {
        switch self {
        case .intent:
            return "Intent"
        case .whyItMatters:
            return "Why"
        case .people:
            return "People"
        case .coreFlow:
            return "Flow"
        case .requirements:
            return "Requirements"
        case .acceptanceChecks:
            return "Acceptance"
        case .constraints:
            return "Constraints"
        }
    }

    public var icon: String {
        switch self {
        case .intent:
            return "scope"
        case .whyItMatters:
            return "sparkles"
        case .people:
            return "person.2.fill"
        case .coreFlow:
            return "arrow.triangle.branch"
        case .requirements:
            return "list.bullet.rectangle"
        case .acceptanceChecks:
            return "checklist"
        case .constraints:
            return "lock.fill"
        }
    }

    public var headingMarkers: [String] {
        switch self {
        case .intent:
            return ["# intent", "## intent"]
        case .whyItMatters:
            return ["## why it matters", "## why", "## problem"]
        case .people:
            return ["## people", "## users", "## audience"]
        case .coreFlow:
            return ["## core flow", "## flow", "## user flow"]
        case .requirements:
            return ["## requirements", "## functional requirements"]
        case .acceptanceChecks:
            return ["## acceptance checks", "## acceptance criteria", "## done when"]
        case .constraints:
            return ["## constraints", "## guardrails"]
        }
    }

    public var templateBlock: String {
        switch self {
        case .intent:
            return """
            # Intent
            Build a focused web app that turns one clear idea into a working preview.
            """
        case .whyItMatters:
            return """
            ## Why It Matters
            - Developer pain or user need:
            - Future this points toward:
            """
        case .people:
            return """
            ## People
            - Primary user:
            - Moment of use:
            """
        case .coreFlow:
            return """
            ## Core Flow
            1. The user lands on:
            2. The user can:
            3. The experience responds by:
            """
        case .requirements:
            return """
            ## Requirements
            - The interface must make the main action obvious.
            - The live preview should communicate the idea without extra explanation.
            - The app should work in a single HTML/CSS/JS bundle.
            """
        case .acceptanceChecks:
            return """
            ## Acceptance Checks
            - [ ] A first-time user understands the purpose in under 5 seconds.
            - [ ] The main action works without setup.
            - [ ] Visual feedback confirms every important interaction.
            - [ ] CoCaptain has enough context to make safe, specific edits.
            """
        case .constraints:
            return """
            ## Constraints
            - Keep the first version small enough to ship today.
            - Avoid external dependencies unless the idea requires them.
            """
        }
    }

    public func isPresent(in normalizedText: String) -> Bool {
        headingMarkers.contains { normalizedText.contains($0) }
    }
}

public enum SRSScaffold {
    public static let defaultText: String = SRSScaffoldSection.allCases
        .map(\.templateBlock)
        .joined(separator: "\n\n") + "\n"

    public static func missingSections(in text: String) -> [SRSScaffoldSection] {
        let normalizedText = text.lowercased()
        return SRSScaffoldSection.allCases.filter { !$0.isPresent(in: normalizedText) }
    }

    public static func structuredText(from text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return defaultText
        }

        let missingBlocks = missingSections(in: trimmedText).map(\.templateBlock)
        guard !missingBlocks.isEmpty else {
            return trimmedText + "\n"
        }

        return ([trimmedText] + missingBlocks).joined(separator: "\n\n") + "\n"
    }
}
