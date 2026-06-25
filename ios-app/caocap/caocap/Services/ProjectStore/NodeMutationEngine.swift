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
            
            // Type-specific initialization if content is empty
            switch type {
            case .srs:
                if nodes[index].textContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    nodes[index].textContent = SRSScaffold.defaultText
                }
                let text = nodes[index].textContent ?? ""
                nodes[index].srsReadinessState = SRSReadinessEvaluator().evaluate(text: text, currentState: nil)
            case .code:
                if nodes[index].textContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    nodes[index].textContent = "// Write code here..."
                }
            case .webView, .standard:
                break
            case .firebase:
                if nodes[index].textContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    nodes[index].textContent = FirebasePreviewBootstrap.placeholderConfigJSON()
                }
            case .subCanvas:
                if nodes[index].linkedCanvasFileName == nil {
                    nodes[index].linkedCanvasFileName = "project_\(UUID().uuidString.prefix(8)).json"
                }
            }
            
            if persist {
                onRequestSave?(true)
            }
            onCompileLivePreview?(&nodes)
        }
    }
    
    public func updateNodeTextContent(nodes: inout [SpatialNode], id: UUID, text: String, persist: Bool = true) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            let oldText = nodes[index].textContent ?? ""
            let oldReadiness = nodes[index].srsReadinessState

            undoManager?.registerUndo(withTarget: self) { target in
                MainActor.assumeIsolated {
                    target.onPerformUndoMutation? { currentNodes in
                        target.updateNodeTextContent(nodes: &currentNodes, id: id, text: oldText, persist: persist)
                    }
                }
            }
            undoStackChanged += 1

            nodes[index].textContent = text

            if nodes[index].type == .srs {
                let evaluator = SRSReadinessEvaluator()
                nodes[index].srsReadinessState = evaluator.evaluate(text: text, currentState: oldReadiness)
            }

            if persist {
                onRequestSave?(true)
            }
            onTriggerDownstreamAgents?(id, nodes)
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
    
    public func addNode(nodes: inout [SpatialNode], type: NodeType = .code) {
        let baseTitle = type == .code ? "New Logic" : type.displayName
        let uniqueTitle = generateUniqueTitle(nodes: nodes, base: baseTitle)

        let subtitle: String?
        let initialText: String?
        switch type {
        case .code:
            subtitle = "Write your intent here."
            initialText = "// Start coding here..."
        case .firebase:
            subtitle = "Project settings → Your apps → Web app config"
            initialText = FirebasePreviewBootstrap.placeholderConfigJSON()
        case .subCanvas:
            subtitle = "Tap to open this canvas"
            initialText = nil
        default:
            subtitle = nil
            initialText = nil
        }

        let linkedFileName: String? = type == .subCanvas ? "project_\(UUID().uuidString.prefix(8)).json" : nil
        let offset = onViewportChange?() ?? .zero

        let newNode = SpatialNode(
            id: UUID(),
            type: type,
            position: CGPoint(x: -offset.width, y: -offset.height), // Scale is applied in view usually, simplified here based on ProjectStore
            title: uniqueTitle,
            subtitle: subtitle,
            icon: nodeIcon(for: type),
            theme: nodeTheme(for: type),
            textContent: initialText,
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
        onRequestSave?(true)
    }
    
    public func nodeIcon(for type: NodeType) -> String {
        switch type {
        case .code: return "plus.square.fill"
        case .srs: return "doc.text.fill"
        case .webView: return "play.display"
        case .standard: return "square.grid.2x2"
        case .firebase: return "flame.fill"
        case .subCanvas: return "folder.fill"
        }
    }

    public func nodeTheme(for type: NodeType) -> NodeTheme {
        switch type {
        case .firebase: return .orange
        case .subCanvas: return .cyan
        default: return .blue
        }
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
            let oldPath = nodes[index].firebaseFirestorePath
            undoManager?.registerUndo(withTarget: self) { target in
                MainActor.assumeIsolated {
                    target.onPerformUndoMutation? { currentNodes in
                        target.updateNodeFirebaseFirestorePath(nodes: &currentNodes, id: id, path: oldPath, persist: persist)
                    }
                }
            }
            undoStackChanged += 1
            nodes[index].firebaseFirestorePath = path
            if persist {
                onRequestSave?(true)
            }
            onCompileLivePreview?(&nodes)
        }
    }
}
