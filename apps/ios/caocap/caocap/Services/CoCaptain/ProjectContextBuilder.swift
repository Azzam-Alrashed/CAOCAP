import Foundation

/// Serializes the current canvas state into a structured plain-text block
/// suitable for injection into the LLM prompt context.
///
/// Both methods produce a snapshot of the project's node graph. Node-scoped
/// context highlights the selected node and its immediate neighbors so the
/// agent can reason about one card without losing awareness of the canvas.
public struct ProjectContextBuilder {
    /// Controls how much implementation detail is included in canvas context.
    public enum DetailLevel: Hashable {
        /// Full node inventory for Agent turns that may request canvas actions.
        case implementation
        /// Lighter inventory for Ask/Plan prose turns.
        case product
    }

    public init(usesOnDemandCodeReads: Bool = true) {
        // On-demand section reads existed for Mini-App HTML/SRS. The flag is
        // kept so existing coordinator call sites still compile.
        _ = usesOnDemandCodeReads
    }

    /// Builds a full-project context string from every node on the canvas.
    @MainActor
    public func buildPromptContext(
        from store: ProjectStore,
        detailLevel: DetailLevel = .implementation
    ) -> String {
        [
            "Project Name: \(store.projectName)",
            "Workspace ID: \(store.fileName)",
            "Node Count: \(store.nodes.count)",
            "Node Graph:\n\(nodeInventory(store.nodes))",
            detailLevel == .implementation
                ? "CoCaptain can talk about this canvas and request app actions such as creating or moving a node. It cannot edit HTML, SRS, or Mini-App source."
                : nil
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")
    }

    /// Builds a node-scoped context string that emphasises a specific node.
    @MainActor
    public func buildNodePromptContext(
        from store: ProjectStore,
        nodeID: UUID,
        detailLevel: DetailLevel = .implementation
    ) -> String {
        guard let selectedNode = store.nodes.first(where: { $0.id == nodeID }) else {
            return buildPromptContext(from: store, detailLevel: detailLevel)
        }

        let linkedNodes = linkedNeighbors(of: selectedNode, in: store.nodes)
        let linkedLines = linkedNodes.map(nodeLine)

        return [
            "Project Name: \(store.projectName)",
            "Workspace ID: \(store.fileName)",
            "Node Agent Scope: \(selectedNode.title)",
            selectedNode.agentProfile.systemPrompt.map { "Agent System Prompt:\n\($0)" },
            "Selected Node ID: \(selectedNode.id.uuidString)",
            "Selected Node Type: \(selectedNode.type.rawValue)",
            "Selected Node Role: \(selectedNode.role.rawValue)",
            selectedNode.agentState.memorySummary.map { "Node Agent Memory:\n\($0)" },
            "Selected Node:\n\(nodeLine(selectedNode))",
            linkedLines.isEmpty ? nil : "Linked Neighbor Nodes:\n\(linkedLines.joined(separator: "\n"))",
            "Project Inventory:\n\(nodeInventory(store.nodes))"
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")
    }

    private func nodeInventory(_ nodes: [SpatialNode]) -> String {
        nodes.map(nodeLine).joined(separator: "\n")
    }

    private func nodeLine(_ node: SpatialNode) -> String {
        let linkCount = (node.connectedNodeIds?.count ?? 0) + (node.nextNodeId == nil ? 0 : 1)
        if node.type == .subCanvas {
            return "- \(node.title) [subCanvas] id: \(node.id.uuidString) links: \(linkCount) file: \(node.linkedCanvasFileName ?? "[None]")"
        }
        return "- \(node.title) [\(node.type.rawValue)] id: \(node.id.uuidString) links: \(linkCount)"
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
}
