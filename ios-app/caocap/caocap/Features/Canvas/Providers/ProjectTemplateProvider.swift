import Foundation

public struct ProjectTemplateProvider {

    /// Returns a new set of interconnected nodes for the default project template.
    public static var defaultNodes: [SpatialNode] {
        let webViewId = UUID()
        let srsId = UUID()
        let codeId = UUID()

        return [
            SpatialNode(
                id: webViewId,
                type: .webView,
                position: CGPoint(x: 360, y: 0),
                title: "Live Preview",
                subtitle: "Your current build renders here.",
                icon: "play.circle.fill",
                theme: .blue
            ),
            SpatialNode(
                id: srsId,
                type: .srs,
                position: CGPoint(x: -420, y: 0),
                title: "Software Requirements (SRS)",
                subtitle: "Define intent, people, flow, and success.",
                icon: "doc.text.fill",
                theme: .purple,
                connectedNodeIds: [codeId],
                textContent: SRSScaffold.defaultText
            ),
            SpatialNode(
                id: codeId,
                type: .code,
                position: CGPoint(x: -30, y: 0),
                title: "Code",
                subtitle: "HTML, CSS, and JavaScript in one file.",
                icon: "chevron.left.slash.chevron.right",
                theme: .orange,
                connectedNodeIds: [webViewId],
                textContent: defaultCode
            )
        ]
    }

    private static let defaultCode = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>My App</title>
        <style>
            body {
                background-color: #0d0d0d;
                color: #ffffff;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                overflow: hidden;
            }

            h1 {
                font-size: 3rem;
                background: linear-gradient(90deg, #00C9FF 0%, #92FE9D 100%);
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
                cursor: pointer;
                transition: transform 0.1s ease-out, filter 0.3s ease;
            }

            h1:hover {
                filter: drop-shadow(0 0 10px rgba(0, 201, 255, 0.5));
            }
        </style>
    </head>
    <body>
        <h1>Hello World!</h1>

        <script>
            document.addEventListener('DOMContentLoaded', () => {
                const text = document.querySelector('h1');

                document.addEventListener('mousemove', (e) => {
                    const x = (window.innerWidth / 2 - e.pageX) / 25;
                    const y = (window.innerHeight / 2 - e.pageY) / 25;
                    text.style.transform = `translate(${x}px, ${y}px)`;
                });

                text.addEventListener('click', () => {
                    text.style.transform = 'scale(1.2)';
                    setTimeout(() => {
                        text.style.transform = 'scale(1)';
                    }, 150);
                });
            });
        </script>
    </body>
    </html>
    """
}

enum SRSScaffoldSection: String, CaseIterable, Hashable {
    case intent
    case whyItMatters
    case people
    case coreFlow
    case requirements
    case acceptanceChecks
    case constraints

    var title: String {
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

    var icon: String {
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

    var headingMarkers: [String] {
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

    var templateBlock: String {
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

    func isPresent(in normalizedText: String) -> Bool {
        headingMarkers.contains { normalizedText.contains($0) }
    }
}

enum SRSScaffold {
    static let defaultText: String = SRSScaffoldSection.allCases
        .map(\.templateBlock)
        .joined(separator: "\n\n") + "\n"

    static func missingSections(in text: String) -> [SRSScaffoldSection] {
        let normalizedText = text.lowercased()
        return SRSScaffoldSection.allCases.filter { !$0.isPresent(in: normalizedText) }
    }

    static func structuredText(from text: String) -> String {
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
