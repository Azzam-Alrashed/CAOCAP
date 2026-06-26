import Foundation

/// Serializes the current canvas state into a structured plain-text block
/// suitable for injection into the LLM prompt context.
///
/// Both methods produce a snapshot of the project's node graph; the
/// node-scoped variant additionally highlights the selected node and its
/// immediate neighbors so the agent can reason more precisely about a
/// single Mini-App without losing awareness of the broader canvas.
public struct ProjectContextBuilder {
    /// Maximum characters allowed for the Firebase config section of a prompt.
    /// Config objects can be large JSON; truncation keeps the prompt within model limits.
    private static let maxFirebaseConfigChars = 4_000

    public init() {}

    /// Builds a full-project context string from every node on the canvas.
    ///
    /// The returned string includes a node inventory listing, per-Mini-App
    /// SRS + code sections (with character budgets), and the Firebase wiring
    /// rules so the agent always has them in context.
    @MainActor
    public func buildPromptContext(from store: ProjectStore) -> String {
        let miniApps = store.nodes.filter { $0.type == .miniApp }
        let inventory = nodeInventory(store.nodes)
        let miniAppSections = miniApps.map { miniAppContext(for: $0, selected: false) }

        return [
            "Project Name: \(store.projectName)",
            "Workspace ID: \(store.fileName)",
            "Node Count: \(store.nodes.count)",
            "Mini-App Count: \(miniApps.count)",
            "Node Graph:\n\(inventory)",
            miniAppSections.isEmpty ? nil : "Mini-Apps:\n\n" + miniAppSections.joined(separator: "\n\n---\n\n"),
            ProjectContextBuilder.firebaseWiringRulesBulletList()
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")
    }

    /// Builds a node-scoped context string that emphasises a specific node.
    ///
    /// The selected node is rendered with expanded character budgets (3 000 for
    /// SRS, 6 000 for code) while linked neighbors are shown at a reduced budget
    /// to stay within prompt limits. Falls back to the full-project context if
    /// the requested `nodeID` is not found.
    @MainActor
    public func buildNodePromptContext(from store: ProjectStore, nodeID: UUID) -> String {
        guard let selectedNode = store.nodes.first(where: { $0.id == nodeID }) else {
            return buildPromptContext(from: store)
        }

        let linkedNodes = linkedNeighbors(of: selectedNode, in: store.nodes)
        let linkedSections = linkedNodes.map { miniAppContext(for: $0, selected: false) }

        return [
            "Project Name: \(store.projectName)",
            "Workspace ID: \(store.fileName)",
            "Node Agent Scope: \(selectedNode.title)",
            selectedNode.agentProfile.systemPrompt.map { "Agent System Prompt:\n\($0)" },
            "Selected Node ID: \(selectedNode.id.uuidString)",
            "Selected Node Type: \(selectedNode.type.rawValue)",
            "Selected Node Role: \(selectedNode.role.rawValue)",
            selectedNode.agentState.memorySummary.map { "Node Agent Memory:\n\($0)" },
            "Selected Node Context:\n\(miniAppContext(for: selectedNode, selected: true))",
            linkedSections.isEmpty ? nil : "Linked Neighbor Nodes:\n\n\(linkedSections.joined(separator: "\n\n"))",
            "Project Inventory:\n\(nodeInventory(store.nodes))",
            ProjectContextBuilder.firebaseWiringRulesBulletList()
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")
    }

    /// A one-liner inventory of all canvas nodes showing title, type, ID, and
    /// number of outgoing and incoming connections.
    private func nodeInventory(_ nodes: [SpatialNode]) -> String {
        nodes.map { node in
            let linkCount = (node.connectedNodeIds?.count ?? 0) + (node.nextNodeId == nil ? 0 : 1)
            return "- \(node.title) [\(node.type.rawValue)] id: \(node.id.uuidString) links: \(linkCount)"
        }.joined(separator: "\n")
    }

    /// Renders a context block for a single node.
    ///
    /// `selected` controls the character budget: the focused node gets a larger
    /// window so the agent can read its full SRS and enough code to reason about
    /// it, while neighbor nodes are capped to a brief summary to save prompt space.
    private func miniAppContext(for node: SpatialNode, selected: Bool) -> String {
        guard node.type == .miniApp, let miniApp = node.miniApp else {
            if node.type == .subCanvas {
                return "- \(node.title) [subCanvas] links to file: \(node.linkedCanvasFileName ?? "[None]")"
            }
            return "- \(node.title) [\(node.type.rawValue)]"
        }

        let srsLimit = selected ? 3_000 : 1_000
        let codeLimit = selected ? 6_000 : 1_600
        let firebaseConfig = miniApp.firebaseConfigText.trimmingCharacters(in: .whitespacesAndNewlines)
        let firebaseStatus = FirebasePreviewBootstrap.injectableFirebaseConfig(for: miniApp) == nil ? "not ready" : "ready"
        let firestorePath = miniApp.firebaseFirestorePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return """
        - \(node.title) [miniApp] id: \(node.id.uuidString)
          SRS Readiness: \(miniApp.srsReadinessState.contextLabel)
          Firebase: \(firebaseStatus)
          Firestore Default Path: \(firestorePath.isEmpty ? "(none set)" : firestorePath)
          SRS:
        \(Self.indent(Self.trimmed(miniApp.srsText, limit: srsLimit), spaces: 4))

          Code:
        \(Self.indent(Self.trimmed(miniApp.codeText, limit: codeLimit), spaces: 4))

          Firebase Config:
        \(Self.indent(firebaseConfig.isEmpty ? "(empty)" : Self.formatFirebaseConfigForPrompt(firebaseConfig), spaces: 4))
        """
    }

    /// Collects all nodes that are directly linked to `selectedNode` in either
    /// direction — outgoing (`nextNodeId`, `connectedNodeIds`) and incoming (any
    /// node whose links point at `selectedNode`'s ID).
    private func linkedNeighbors(of selectedNode: SpatialNode, in nodes: [SpatialNode]) -> [SpatialNode] {
        var ids = Set<UUID>()
        if let nextNodeId = selectedNode.nextNodeId {
            ids.insert(nextNodeId)
        }
        for id in selectedNode.connectedNodeIds ?? [] {
            ids.insert(id)
        }
        for node in nodes where node.nextNodeId == selectedNode.id || node.connectedNodeIds?.contains(selectedNode.id) == true {
            ids.insert(node.id)
        }
        return nodes.filter { ids.contains($0.id) }
    }

    /// Attempts to pretty-print raw Firebase config JSON so it's easier for
    /// the model to read; falls back to the raw string if parsing fails.
    private static func formatFirebaseConfigForPrompt(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8) else {
            return trimmed(raw, limit: maxFirebaseConfigChars)
        }
        if let obj = try? JSONSerialization.jsonObject(with: data),
           JSONSerialization.isValidJSONObject(obj),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) {
            return trimmed(str, limit: maxFirebaseConfigChars)
        }
        return trimmed(raw, limit: maxFirebaseConfigChars)
    }

    private static func firebaseWiringRulesBulletList() -> String {
        """
        Mini-App Firebase wiring rules for CoCaptain:
        - Firebase config lives inside each Mini-App, not in a separate Firebase node.
        - The Mini-App preview injects valid config and sets `window.__caocapFirestore` plus `window.__caocapFirestoreDefaultPath`.
        - Do not call `initializeApp` again in Mini-App code; use `window.__caocapFirestore` after null checks.
        - For code edits, emit `node_edit` with `role="miniApp"` and `section="code"` targeting the Mini-App nodeId.
        - For SRS edits, emit `node_edit` with `role="miniApp"` and `section="srs"` targeting the Mini-App nodeId.
        - Firestore compat: `db.collection('segment')` accepts one collection id. For nested paths, chain `collection().doc().collection()`.
        - Remind the user that Firestore Security Rules must allow intended client reads/writes.
        """
    }

    private static func trimmed(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "\n[TRUNCATED]"
    }

    private static func indent(_ text: String, spaces: Int) -> String {
        let prefix = String(repeating: " ", count: spaces)
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { prefix + String($0) }
            .joined(separator: "\n")
    }
}
