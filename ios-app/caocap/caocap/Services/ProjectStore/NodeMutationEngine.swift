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
    var onRecalculateGraph: ((inout [SpatialNode]) -> Void)?
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
            case .webView, .art, .display, .standard:
                break
            case .table:
                if nodes[index].textContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    nodes[index].textContent = "Header 1, Header 2\nData 1, Data 2"
                }
            case .text:
                if nodes[index].textContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    nodes[index].textContent = "Write notes here..."
                }
            case .number:
                if nodes[index].textContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    nodes[index].textContent = "0"
                }
            case .calculation:
                if nodes[index].operation == nil {
                    nodes[index].operation = .add
                }
            case .aiAgent:
                if nodes[index].promptTemplate == nil {
                    nodes[index].promptTemplate = "Compare {{input1}} and {{input2}}"
                }
            case .chart:
                if nodes[index].chartStyle == nil {
                    nodes[index].chartStyle = .bar
                }
            case .firebase:
                if nodes[index].textContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    nodes[index].textContent = FirebasePreviewBootstrap.placeholderConfigJSON()
                }
            case .subCanvas:
                if nodes[index].linkedCanvasFileName == nil {
                    nodes[index].linkedCanvasFileName = "project_\(UUID().uuidString.prefix(8)).json"
                }
            case .console:
                break
            }
            
            if persist {
                onRequestSave?(true)
            }
            onCompileLivePreview?(&nodes)
        }
    }
    
    public func updateNodeChartStyle(nodes: inout [SpatialNode], id: UUID, style: ChartStyle) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[index].chartStyle = style
        onRequestSave?(true)
    }

    public func updateNodeChartXColumn(nodes: inout [SpatialNode], id: UUID, index: Int?) {
        guard let nodeIndex = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[nodeIndex].chartXColumnIndex = index
        onRequestSave?(true)
    }

    public func updateNodeChartYColumn(nodes: inout [SpatialNode], id: UUID, index: Int?) {
        guard let nodeIndex = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[nodeIndex].chartYColumnIndex = index
        onRequestSave?(true)
    }

    public func updateNodeChartHasHeaderRow(nodes: inout [SpatialNode], id: UUID, hasHeader: Bool) {
        guard let nodeIndex = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[nodeIndex].chartHasHeaderRow = hasHeader
        onRequestSave?(true)
    }
    
    public func updateNodeDrawingData(nodes: inout [SpatialNode], id: UUID, data: Data, persist: Bool = true) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            let oldData = nodes[index].drawingData ?? Data()
            
            undoManager?.registerUndo(withTarget: self) { target in
                MainActor.assumeIsolated {
                    target.onPerformUndoMutation? { currentNodes in
                        target.updateNodeDrawingData(nodes: &currentNodes, id: id, data: oldData, persist: persist)
                    }
                }
            }
            undoStackChanged += 1
            
            nodes[index].drawingData = data
            if persist {
                onRequestSave?(true)
            }
            
            onRecalculateGraph?(&nodes)
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
            onRecalculateGraph?(&nodes)
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
        case .console:
            subtitle = "Logs and errors from Live Preview"
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
            chartStyle: type == .chart ? .bar : nil,
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
        onRecalculateGraph?(&nodes)
    }
    
    public func nodeIcon(for type: NodeType) -> String {
        switch type {
        case .code: return "plus.square.fill"
        case .text: return "text.justify.left"
        case .number: return "text.cursor"
        case .table: return "tablecells.fill"
        case .calculation: return "plus.forwardslash.minus"
        case .display: return "opticaldisc.fill"
        case .srs: return "doc.text.fill"
        case .webView: return "play.display"
        case .art: return "pencil.tip"
        case .standard: return "square.grid.2x2"
        case .aiAgent: return "brain.head.profile.fill"
        case .chart: return "chart.line.uptrend.xyaxis"
        case .firebase: return "flame.fill"
        case .subCanvas: return "folder.fill"
        case .console: return "terminal.fill"
        }
    }

    public func nodeTheme(for type: NodeType) -> NodeTheme {
        switch type {
        case .text: return .blue
        case .number: return .blue
        case .table: return .cyan
        case .calculation: return .orange
        case .display: return .green
        case .aiAgent: return .indigo
        case .chart: return .purple
        case .firebase: return .orange
        case .subCanvas: return .cyan
        case .console: return .purple
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
                if let inputs = nodes[i].inputNodeIds {
                    nodes[i].inputNodeIds = inputs.filter { $0 != id }
                    if nodes[i].inputNodeIds?.isEmpty == true {
                        nodes[i].inputNodeIds = nil
                    }
                }
            }
        }
        
        if persist {
            onRequestSave?(true)
        }
    }

    public func updateNodeOperation(nodes: inout [SpatialNode], id: UUID, operation: ArithmeticOperation, persist: Bool = true) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            let oldOp = nodes[index].operation ?? .add
            
            undoManager?.registerUndo(withTarget: self) { target in
                MainActor.assumeIsolated {
                    target.onPerformUndoMutation? { currentNodes in
                        target.updateNodeOperation(nodes: &currentNodes, id: id, operation: oldOp, persist: persist)
                    }
                }
            }
            undoStackChanged += 1
            
            nodes[index].operation = operation
            if persist {
                onRequestSave?(true)
            }
            onRecalculateGraph?(&nodes)
        }
    }
    
    public func updateNodeInputs(nodes: inout [SpatialNode], id: UUID, inputNodeIds: [UUID]) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            let oldInputs = nodes[index].inputNodeIds ?? []
            
            undoManager?.registerUndo(withTarget: self) { target in
                MainActor.assumeIsolated {
                    target.onPerformUndoMutation? { currentNodes in
                        target.updateNodeInputs(nodes: &currentNodes, id: id, inputNodeIds: oldInputs)
                    }
                }
            }
            undoStackChanged += 1
            
            nodes[index].inputNodeIds = inputNodeIds
            onRequestSave?(true)
            onRecalculateGraph?(&nodes)
        }
    }
    
    public func updateNodePrompt(nodes: inout [SpatialNode], id: UUID, prompt: String) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes[index].promptTemplate = prompt
            onRequestSave?(true)
        }
    }

    public func updateNodeDisplayStyle(nodes: inout [SpatialNode], id: UUID, style: DisplayStyle) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes[index].displayStyle = style
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
