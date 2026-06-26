import Foundation
import SwiftUI
import os

@Observable
@MainActor
final class NodeMutationEngine {
    var undoManager: UndoManager?
    var undoStackChanged: Int = 0
    private let logger = Logger(subsystem: "com.caocap.App", category: "NodeMutationEngine")
    
    // Callbacks for side effects:
    var onRequestSave: ((Bool) -> Void)?
    var onCompileLivePreview: ((inout [SpatialNode]) -> Void)?
    var onTriggerDownstreamAgents: ((UUID, [SpatialNode]) -> Void)?
    var onViewportChange: (() -> CGSize)?
    var onPerformUndoMutation: (( @escaping (inout [SpatialNode]) -> Void ) -> Void)?
    
    public func updateNodeType(nodes: inout [SpatialNode], id: UUID, type: NodeType, persist: Bool = true) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            let oldType = nodes[index].type
            
            undoManager?.registerUndo(withTarget: self) { target in
                MainActor.assumeIsolated {
                    target.onPerformUndoMutation? { currentNodes in
                        target.updateNodeType(nodes: &currentNodes, id: id, type: oldType, persist: persist)
                    }
                }
            }
            undoStackChanged += 1
            
            nodes[index].type = type
            nodes[index].theme = nodeTheme(for: type)
            nodes[index].icon = nodeIcon(for: type)
            
            switch type {
            case .miniApp:
                nodes[index].miniApp = nodes[index].miniApp ?? MiniAppState(
                    srsReadinessState: SRSReadinessEvaluator().evaluate(text: SRSScaffold.defaultText, currentState: nil),
                    codeText: ProjectTemplateProvider.defaultCode,
                    firebaseConfigText: FirebasePreviewBootstrap.placeholderConfigJSON()
                )
            case .standard:
                nodes[index].miniApp = nil
            case .subCanvas:
                nodes[index].miniApp = nil
                if nodes[index].linkedCanvasFileName == nil {
                    nodes[index].linkedCanvasFileName = CanvasFileNaming.newCanvasFileName()
                }
            }
            
            if persist {
                onRequestSave?(true)
            }
            onCompileLivePreview?(&nodes)
        }
    }
    
    public func updateNodeTextContent(nodes: inout [SpatialNode], id: UUID, text: String, persist: Bool = true) {
        updateMiniAppCode(nodes: &nodes, id: id, text: text, persist: persist)
    }

    public func updateMiniAppSRS(nodes: inout [SpatialNode], id: UUID, text: String, persist: Bool = true) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            ensureMiniAppState(for: &nodes[index])
            let oldText = nodes[index].miniApp?.srsText ?? ""
            let oldReadiness = nodes[index].miniApp?.srsReadinessState

            undoManager?.registerUndo(withTarget: self) { target in
                MainActor.assumeIsolated {
                    target.onPerformUndoMutation? { currentNodes in
                        target.updateMiniAppSRS(nodes: &currentNodes, id: id, text: oldText, persist: persist)
                    }
                }
            }
            undoStackChanged += 1

            nodes[index].miniApp?.srsText = text
            nodes[index].miniApp?.srsReadinessState = SRSReadinessEvaluator().evaluate(text: text, currentState: oldReadiness)

            if persist {
                onRequestSave?(true)
            }
            onTriggerDownstreamAgents?(id, nodes)
        }
    }

    public func updateMiniAppCode(nodes: inout [SpatialNode], id: UUID, text: String, persist: Bool = true) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            ensureMiniAppState(for: &nodes[index])
            let oldText = nodes[index].miniApp?.codeText ?? ""

            undoManager?.registerUndo(withTarget: self) { target in
                MainActor.assumeIsolated {
                    target.onPerformUndoMutation? { currentNodes in
                        target.updateMiniAppCode(nodes: &currentNodes, id: id, text: oldText, persist: persist)
                    }
                }
            }
            undoStackChanged += 1

            nodes[index].miniApp?.codeText = text
            onCompileLivePreview?(&nodes)

            if persist {
                onRequestSave?(true)
            }
            onTriggerDownstreamAgents?(id, nodes)
        }
    }

    public func updateMiniAppFirebaseConfig(nodes: inout [SpatialNode], id: UUID, text: String, persist: Bool = true) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            ensureMiniAppState(for: &nodes[index])
            let oldText = nodes[index].miniApp?.firebaseConfigText ?? ""

            undoManager?.registerUndo(withTarget: self) { target in
                MainActor.assumeIsolated {
                    target.onPerformUndoMutation? { currentNodes in
                        target.updateMiniAppFirebaseConfig(nodes: &currentNodes, id: id, text: oldText, persist: persist)
                    }
                }
            }
            undoStackChanged += 1

            nodes[index].miniApp?.firebaseConfigText = text
            onCompileLivePreview?(&nodes)

            if persist {
                onRequestSave?(true)
            }
        }
    }
    
    public func updateNodeAgentState(nodes: inout [SpatialNode], id: UUID, agentState: NodeAgentState, persist: Bool = true) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[index].agentState = agentState
        if persist {
            onRequestSave?(true)
        }
    }

    public func appendNodeAgentMessage(nodes: inout [SpatialNode], id: UUID, message: NodeAgentMessage, persist: Bool = true) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[index].agentState.messages.append(message)
        if persist {
            onRequestSave?(true)
        }
    }

    public func clearNodeAgentMessages(nodes: inout [SpatialNode], id: UUID, persist: Bool = true) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[index].agentState.messages = []
        if persist {
            onRequestSave?(true)
        }
    }
    
    public func updateNodePositions(nodes: inout [SpatialNode], _ positions: [UUID: CGPoint], animated: Bool = true) {
        let oldPositions = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.position) })
        
        undoManager?.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated {
                target.onPerformUndoMutation? { currentNodes in
                    target.updateNodePositions(nodes: &currentNodes, oldPositions, animated: animated)
                }
            }
        }
        undoStackChanged += 1
        
        let applyPositions: (inout [SpatialNode]) -> Void = { n in
            for (id, pos) in positions {
                if let index = n.firstIndex(where: { $0.id == id }) {
                    n[index].position = pos
                }
            }
        }
        
        if animated {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                applyPositions(&nodes)
            }
        } else {
            applyPositions(&nodes)
        }
        
        onRequestSave?(true)
    }
    
    public func organizeNodes(nodes: inout [SpatialNode]) {
        guard !nodes.isEmpty else { return }
        
        let organizer = NodeLayoutOrganizer()
        let nodePositions = organizer.organize(nodes: nodes)
        
        updateNodePositions(nodes: &nodes, nodePositions, animated: true)
        HapticsManager.shared.notification(.success)
    }
    
    public func addNode(nodes: inout [SpatialNode], type: NodeType = .miniApp) {
        let uniqueTitle = generateUniqueTitle(nodes: nodes, base: type.defaultTitle)

        let subtitle = type.defaultSubtitle
        let linkedFileName: String? = type == .subCanvas ? CanvasFileNaming.newCanvasFileName() : nil
        let miniApp = type == .miniApp ? MiniAppState(
            srsReadinessState: SRSReadinessEvaluator().evaluate(text: SRSScaffold.defaultText, currentState: nil),
            codeText: ProjectTemplateProvider.defaultCode,
            firebaseConfigText: FirebasePreviewBootstrap.placeholderConfigJSON()
        ) : nil
        let offset = onViewportChange?() ?? .zero

        let newNode = SpatialNode(
            id: UUID(),
            type: type,
            position: CGPoint(x: -offset.width, y: -offset.height), // Scale is applied in view usually, simplified here based on ProjectStore
            title: uniqueTitle,
            subtitle: subtitle,
            icon: nodeIcon(for: type),
            theme: nodeTheme(for: type),
            miniApp: miniApp,
            linkedCanvasFileName: linkedFileName
        )
        
        undoManager?.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated {
                target.onPerformUndoMutation? { currentNodes in
                    target.deleteNode(nodes: &currentNodes, id: newNode.id, persist: true)
                }
            }
        }
        undoStackChanged += 1

        withAnimation(.spring()) {
            nodes.append(newNode)
        }
        onCompileLivePreview?(&nodes)
        onRequestSave?(true)
    }

    public func addShortcutNode(
        nodes: inout [SpatialNode],
        action: NodeAction,
        title: String,
        icon: String,
        at position: CGPoint
    ) {
        let newNode = SpatialNode(
            type: .standard,
            position: position,
            title: title,
            icon: icon,
            theme: .indigo,
            action: action
        )

        undoManager?.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated {
                target.onPerformUndoMutation? { currentNodes in
                    target.deleteNode(nodes: &currentNodes, id: newNode.id, persist: true)
                }
            }
        }
        undoStackChanged += 1

        withAnimation(.spring()) {
            nodes.append(newNode)
        }
        onRequestSave?(true)
    }
    
    public func nodeIcon(for type: NodeType) -> String {
        type.defaultIcon
    }

    public func nodeTheme(for type: NodeType) -> NodeTheme {
        type.defaultTheme
    }

    public func generateUniqueTitle(nodes: [SpatialNode], base: String) -> String {
        var candidate = base
        var count = 1
        if nodes.contains(where: { $0.title.lowercased() == candidate.lowercased() }) {
            while nodes.contains(where: { $0.title.lowercased() == "\(base) \(count)".lowercased() }) {
                count += 1
            }
            candidate = "\(base) \(count)"
        }
        return candidate
    }

    public func updateNodeTitle(nodes: inout [SpatialNode], id: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if nodes.contains(where: { $0.id != id && $0.title.lowercased() == trimmed.lowercased() }) {
            return 
        }
        
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes[index].title = trimmed
            onRequestSave?(true)
        }
    }

    public func updateNodeSubtitle(nodes: inout [SpatialNode], id: UUID, subtitle: String?) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        nodes[index].subtitle = trimmed?.isEmpty == true ? nil : trimmed
        onRequestSave?(true)
    }

    public func updateNodeIcon(nodes: inout [SpatialNode], id: UUID, icon: String?) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = icon?.trimmingCharacters(in: .whitespacesAndNewlines)
        nodes[index].icon = trimmed?.isEmpty == true ? nil : trimmed
        onRequestSave?(true)
    }
    
    public func deleteNode(nodes: inout [SpatialNode], id: UUID, persist: Bool = true) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        
        if nodes[index].isProtected {
            let title = nodes[index].title
            logger.warning("Attempted to delete protected node: \(title)")
            return
        }
        
        let nodesBeforeDeletion = nodes
        
        undoManager?.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated {
                target.onPerformUndoMutation? { currentNodes in
                    currentNodes = nodesBeforeDeletion
                    if persist {
                        target.onRequestSave?(true)
                    }
                }
            }
        }
        undoStackChanged += 1

        withAnimation(.spring()) {
            nodes.remove(at: index)
            
            for i in 0..<nodes.count {
                if nodes[i].nextNodeId == id {
                    nodes[i].nextNodeId = nil
                }
                if let connections = nodes[i].connectedNodeIds {
                    nodes[i].connectedNodeIds = connections.filter { $0 != id }
                    if nodes[i].connectedNodeIds?.isEmpty == true {
                        nodes[i].connectedNodeIds = nil
                    }
                }
            }
        }
        
        if persist {
            onRequestSave?(true)
        }
    }

    public func updateNodeFirebaseFirestorePath(nodes: inout [SpatialNode], id: UUID, path: String?, persist: Bool = true) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            ensureMiniAppState(for: &nodes[index])
            let oldPath = nodes[index].miniApp?.firebaseFirestorePath
            undoManager?.registerUndo(withTarget: self) { target in
                MainActor.assumeIsolated {
                    target.onPerformUndoMutation? { currentNodes in
                        target.updateNodeFirebaseFirestorePath(nodes: &currentNodes, id: id, path: oldPath, persist: persist)
                    }
                }
            }
            undoStackChanged += 1
            nodes[index].miniApp?.firebaseFirestorePath = path
            if persist {
                onRequestSave?(true)
            }
            onCompileLivePreview?(&nodes)
        }
    }

    private func ensureMiniAppState(for node: inout SpatialNode) {
        guard node.type == .miniApp else { return }
        if node.miniApp == nil {
            node.miniApp = MiniAppState(
                srsReadinessState: SRSReadinessEvaluator().evaluate(text: SRSScaffold.defaultText, currentState: nil),
                codeText: ProjectTemplateProvider.defaultCode,
                firebaseConfigText: FirebasePreviewBootstrap.placeholderConfigJSON()
            )
        }
    }
}
