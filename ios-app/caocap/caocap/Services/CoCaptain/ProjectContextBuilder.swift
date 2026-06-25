import Foundation

public struct ProjectContextBuilder {
    /// Cap for Firebase Web config JSON in prompts (large values can break AI calls).
    private static let maxFirebaseConfigChars = 4_000

    public init() {}

    @MainActor
    public func buildPromptContext(from store: ProjectStore) -> String {
        let inventory = store.nodes.map { node in
            let linkCount = (node.connectedNodeIds?.count ?? 0) + (node.nextNodeId == nil ? 0 : 1)
            return "- \(node.title) [\(node.type.rawValue)] links: \(linkCount)"
        }.joined(separator: "\n")

        let sections = NodeRole.editableCanonicalRoles.compactMap { role -> String? in
            guard let node = node(for: role, in: store.nodes) else { return nil }
            // Keep context compact; large prompts can cause Firebase AI Logic calls
            // to fail with opaque errors (e.g. GenerateContentError error 0).
            let content = Self.trimmed(node.textContent ?? "", limit: 1000)
            guard !content.isEmpty else { return nil }
            return "\(role.displayName):\n\(content)"
        }

        return [
            "Project Name: \(store.projectName)",
            "Workspace ID: \(store.fileName)",
            "Node Count: \(store.nodes.count)",
            srsReadinessContext(from: store),
            Self.firebaseContextForCoCaptain(nodes: store.nodes),
            "Node Graph:",
            inventory,
            sections.isEmpty ? nil : "Canonical Nodes:\n" + sections.joined(separator: "\n\n")
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")
    }

    @MainActor
    public func buildNodePromptContext(from store: ProjectStore, nodeID: UUID) -> String {
        guard let selectedNode = store.nodes.first(where: { $0.id == nodeID }) else {
            return buildPromptContext(from: store)
        }

        let inventory = store.nodes.map { node in
            let marker = node.id == nodeID ? " [selected]" : ""
            let linkCount = (node.connectedNodeIds?.count ?? 0) + (node.nextNodeId == nil ? 0 : 1)
            return "- \(node.title) [\(node.type.rawValue)] id: \(node.id.uuidString)\(marker) links: \(linkCount)"
        }.joined(separator: "\n")

        let linkedNodes = linkedNeighbors(of: selectedNode, in: store.nodes)
        let linkedSections = linkedNodes.map { node in
            let content = editableContent(for: node, selected: false)
            return """
            - \(node.title) [\(node.type.rawValue)] id: \(node.id.uuidString) role: \(node.role.rawValue)
              snippet: \(Self.trimmed(content, limit: 500))
            """
        }.joined(separator: "\n")

        let selectedContent = editableContent(for: selectedNode, selected: true)

        return [
            "Project Name: \(store.projectName)",
            "Workspace ID: \(store.fileName)",
            "Node Agent Scope: \(selectedNode.title)",
            selectedNode.agentProfile.systemPrompt.map { "Agent System Prompt:\n\($0)" },
            "Selected Node ID: \(selectedNode.id.uuidString)",
            "Selected Node Type: \(selectedNode.type.rawValue)",
            "Selected Node Role: \(selectedNode.role.rawValue)",
            srsReadinessContext(from: store),
            selectedNode.agentState.memorySummary.map { "Node Agent Memory:\n\($0)" },
            "Selected Node Content:\n\(selectedContent.isEmpty ? "[EMPTY]" : selectedContent)",
            linkedSections.isEmpty ? nil : "Linked Neighbor Nodes:\n\(linkedSections)",
            "Project Inventory:\n\(inventory)"
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")
    }

    // MARK: - Firebase (CoCaptain must read canvas node contents)

    /// Full Firebase canvas context: actual `firebaseConfig` from the node (truncated) + how to wire JS.
    /// Web `apiKey` is intentionally client-exposed in Firebase; rules protect data.
    private static func firebaseContextForCoCaptain(nodes: [SpatialNode]) -> String {
        var parts: [String] = []
        parts.append("### Firebase canvas node + Live Preview wiring")

        let firebaseNodes = nodes.filter { $0.type == .firebase }
        guard !firebaseNodes.isEmpty else {
            parts.append(
                """
                No `firebase` node on this canvas yet.
                - Tell the user to add a Firebase node from the command palette (⌘K → search "firebase" → Create Firebase Node) and paste the Web `firebaseConfig` object from Firebase Console → Project settings → Your apps.
                - You may propose a pending app action with id `create_firebase_node` so an empty Firebase node appears for them to fill.
                """
            )
            parts.append(Self.firebaseWiringRulesBulletList())
            return parts.joined(separator: "\n\n")
        }

        guard let node = FirebasePreviewBootstrap.firstInjectableFirebaseNode(in: nodes) else {
            parts.append(
                """
                There are \(firebaseNodes.count) `firebase` node(s), but **none** have a valid Web `firebaseConfig` yet (empty text, invalid JSON, or still using placeholders like YOUR_WEB_API_KEY / projectId your-project-id).
                - Tell the user to open each Firebase node and paste the real config from Firebase Console, or delete duplicate empty nodes.
                """
            )
            parts.append(Self.firebaseWiringRulesBulletList())
            return parts.joined(separator: "\n\n")
        }

        if firebaseNodes.count > 1 {
            parts.append("Multiple Firebase nodes: Live Preview uses the **first in the node list with a valid** Web config (skips placeholders). Config below is from: **\(node.title)**.")
        } else {
            parts.append("Live Preview uses this Firebase node: **\(node.title)**.")
        }

        let path = node.firebaseFirestorePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        parts.append(
            "Optional default Firestore path (exposed as `window.__caocapFirestoreDefaultPath`): \(path.isEmpty ? "(none set)" : "`\(path)`")"
        )

        let raw = node.textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty {
            parts.append("**firebaseConfig JSON in node is empty** — user must open this node and paste the Web app config from Firebase Console.")
        } else {
            let formatted = Self.formatFirebaseConfigForPrompt(raw)
            parts.append(
                """
                **firebaseConfig stored on this node** (Live Preview injects this for `initializeApp`; Web `apiKey` is public by Firebase design — protect data with Security Rules):
                \(formatted)
                """
            )
            if let data = raw.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let pid = obj["projectId"] as? String, !pid.isEmpty {
                parts.append("Parsed `projectId` for reference: `\(pid)`")
            }
        }

        parts.append(Self.firebaseWiringRulesBulletList())
        return parts.joined(separator: "\n\n")
    }

    private static func formatFirebaseConfigForPrompt(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8) else {
            return Self.trimmed(raw, limit: maxFirebaseConfigChars)
        }
        if let obj = try? JSONSerialization.jsonObject(with: data),
           JSONSerialization.isValidJSONObject(obj),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) {
            return Self.trimmed(str, limit: maxFirebaseConfigChars)
        }
        return Self.trimmed(raw, limit: maxFirebaseConfigChars)
    }

    private static func firebaseWiringRulesBulletList() -> String {
        """
        Wiring rules for you (CoCaptain):
        - Live Preview loads this config and sets `window.__caocapFirestore` when valid. Check `window.__caocapFirestoreStatus === 'ready'`; if not ready, read `window.__caocapFirestoreLastError` — do **not** call `initializeApp` again in the code node.
        - Always guard: `const db = window.__caocapFirestore; if (!db) { … }`
        - **Firestore compat:** `db.collection('segment')` only accepts a **single** collection id (e.g. `leads`). For nested paths like `users/UID/items`, use `db.collection('users').doc(uid).collection('items')` — never pass a slash string into `collection()`.
        - If `window.__caocapFirestoreDefaultPath` is one segment, `db.collection(window.__caocapFirestoreDefaultPath)` is OK; if it contains `/`, build `doc()` / `collection()` chains instead.
        - To persist data, emit **`code` `node_edits`** with inline JavaScript using `.add()`, `.set({ merge: true })`, etc., after DOM ready or inside click/submit handlers. Match **real** HTML `id` / `name` attributes from the code node content.
        - Remind the user: **Firestore Security Rules** must allow the intended client reads/writes (permission-denied often looks like “not saving”).
        """
    }

    // MARK: - Private helpers

    /// Includes the SRS readiness state in the prompt so CoCaptain knows
    /// whether to ask clarifying questions or proceed to code generation.
    @MainActor
    private func srsReadinessContext(from store: ProjectStore) -> String? {
        guard let srsNode = store.nodes.first(where: { $0.role == .srs }) else { return nil }
        let state = srsNode.srsReadinessState ?? .empty
        
        var context = "SRS Readiness: \(state.contextLabel)"
        
        let hasImplementationNodes = store.nodes.contains(where: { $0.role == .code })
        if !hasImplementationNodes {
            context += "\nImplementation State: Blank Canvas (No code nodes exist yet)"
        }
        
        return context
    }

    @MainActor
    private func node(for role: NodeRole, in nodes: [SpatialNode]) -> SpatialNode? {
        nodes.first(where: { role.matches(node: $0) })
    }

    @MainActor
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

    private func editableContent(for node: SpatialNode, selected: Bool) -> String {
        switch node.type {
        case .webView:
            return selected ? Self.trimmed(node.htmlContent ?? "", limit: 1600) : Self.trimmed(node.htmlContent ?? "", limit: 500)
        case .standard, .srs, .code:
            return selected ? (node.textContent ?? "") : Self.trimmed(node.textContent ?? "", limit: 500)
        case .firebase:
            let summary = FirebasePreviewBootstrap.canvasSummaryLine(for: node)
            return selected ? (node.textContent ?? summary) : summary
        case .subCanvas:
            let fileName = node.linkedCanvasFileName ?? "[None]"
            return "Sub-Canvas node linking to file: \(fileName)"
        }
    }

    private static func trimmed(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "\n[TRUNCATED]"
    }
}
