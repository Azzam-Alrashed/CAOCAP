import Foundation

public struct ProjectContextBuilder {
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
            let content = trimmed(node.textContent ?? "", limit: 1000)
            guard !content.isEmpty else { return nil }
            return "\(role.displayName):\n\(content)"
        }

        return [
            "Project Name: \(store.projectName)",
            "Workspace ID: \(store.fileName)",
            "Node Count: \(store.nodes.count)",
            srsReadinessContext(from: store),
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
              snippet: \(trimmed(content, limit: 500))
            """
        }.joined(separator: "\n")

        let selectedContent = editableContent(for: selectedNode, selected: true)

        return [
            "Project Name: \(store.projectName)",
            "Workspace ID: \(store.fileName)",
            "Node Agent Scope: \(selectedNode.title)",
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

    // MARK: - Private helpers

    /// Includes the SRS readiness state in the prompt so CoCaptain knows
    /// whether to ask clarifying questions or proceed to code generation.
    @MainActor
    private func srsReadinessContext(from store: ProjectStore) -> String? {
        guard let srsNode = store.nodes.first(where: { $0.role == .srs }) else { return nil }
        let state = srsNode.srsReadinessState ?? .empty
        return "SRS Readiness: \(state.contextLabel)"
    }

    private func node(for role: NodeRole, in nodes: [SpatialNode]) -> SpatialNode? {
        nodes.first(where: { role.matches(node: $0) })
    }

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
            return selected ? trimmed(node.htmlContent ?? "", limit: 1600) : trimmed(node.htmlContent ?? "", limit: 500)
        case .art:
            return node.drawingData == nil ? "[No drawing data]" : "[Pencil drawing data: \(node.drawingData?.count ?? 0) bytes]"
        case .standard, .srs, .code:
            return selected ? (node.textContent ?? "") : trimmed(node.textContent ?? "", limit: 500)
        }
    }

    private func trimmed(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "\n[TRUNCATED]"
    }
}
