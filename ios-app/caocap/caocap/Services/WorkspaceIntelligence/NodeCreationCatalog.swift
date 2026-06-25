import Foundation

/// A creatable node type surfaced in the Omnibox when the user searches.
public struct NodeCreationOption: Identifiable, Equatable {
    public let id: NodeType
    public let title: String
    public let icon: String
    public let keywords: [String]

    public init(id: NodeType, title: String, icon: String, keywords: [String]) {
        self.id = id
        self.title = title
        self.icon = icon
        self.keywords = keywords
    }
}

/// Searchable catalog of node types the user can create from the command palette.
public struct NodeCreationCatalog {
    public static let options: [NodeCreationOption] = [
        NodeCreationOption(
            id: .code,
            title: "Create Code Node",
            icon: "chevron.left.slash.chevron.right",
            keywords: ["code", "source", "editor"]
        ),
        NodeCreationOption(
            id: .srs,
            title: "Create SRS Node",
            icon: "doc.text.fill",
            keywords: ["srs", "requirements", "spec"]
        ),
        NodeCreationOption(
            id: .webView,
            title: "Create Live Preview Node",
            icon: "play.display",
            keywords: ["preview", "live preview", "web view", "webview"]
        ),
        NodeCreationOption(
            id: .firebase,
            title: "Create Firebase Node",
            icon: "flame.fill",
            keywords: ["firebase", "backend", "firestore"]
        ),
        NodeCreationOption(
            id: .subCanvas,
            title: "Create Sub-Canvas",
            icon: "folder.fill",
            keywords: ["sub-canvas", "sub canvas", "nested", "workspace"]
        )
    ]

    public init() {}

    public func search(query: String) -> [NodeCreationOption] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }

        return Self.options.compactMap { option in
            var score = 0
            let titleLower = option.title.lowercased()

            if titleLower.contains(trimmed) {
                score += 40
            }
            if option.id.displayName.lowercased().contains(trimmed) {
                score += 30
            }
            if option.keywords.contains(where: { $0.contains(trimmed) || trimmed.contains($0) }) {
                score += 20
            }

            return score > 0 ? option : nil
        }
    }
}
