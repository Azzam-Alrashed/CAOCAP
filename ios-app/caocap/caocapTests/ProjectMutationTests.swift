import CoreGraphics
import Foundation
import Testing
@testable import caocap

@MainActor
struct ProjectMutationTests {

    @Test func nodeAdditionRegistersUndo() throws {
        let store = ProjectStore(fileName: "test_add.json")
        let undoManager = UndoManager()
        store.undoManager = undoManager
        
        let initialCount = store.nodes.count
        store.addNode()
        
        #expect(store.nodes.count == initialCount + 1)
        #expect(undoManager.canUndo)
        
        undoManager.undo()
        #expect(store.nodes.count == initialCount)
    }

    @Test func nodeDeletionCleansUpConnections() throws {
        let node1 = SpatialNode(id: UUID(), type: .code, position: .zero, title: "N1")
        let node2Id = UUID()
        let node2 = SpatialNode(id: node2Id, type: .code, position: .zero, title: "N2")
        
        var node3 = SpatialNode(id: UUID(), type: .code, position: .zero, title: "N3")
        node3.nextNodeId = node2Id
        node3.connectedNodeIds = [node2Id]
        
        let store = ProjectStore(fileName: "test_del.json", initialNodes: [node1, node2, node3])
        
        store.deleteNode(id: node2Id)
        
        #expect(store.nodes.count == 2)
        #expect(!store.nodes.contains(where: { $0.id == node2Id }))
        
        let updatedNode3 = store.nodes.first(where: { $0.title == "N3" })!
        #expect(updatedNode3.nextNodeId == nil)
        #expect(updatedNode3.connectedNodeIds == nil)
    }

    @Test func nodeDeletionRegistersUndo() throws {
        let node1 = SpatialNode(id: UUID(), type: .code, position: .zero, title: "N1")
        let store = ProjectStore(fileName: "test_del_undo.json", initialNodes: [node1])
        let undoManager = UndoManager()
        store.undoManager = undoManager
        
        store.deleteNode(id: node1.id)
        #expect(store.nodes.isEmpty)
        #expect(undoManager.canUndo)
        
        undoManager.undo()
        #expect(store.nodes.count == 1)
        #expect(store.nodes.first?.id == node1.id)
    }

    @Test func undoingNodeDeletionRestoresCleanedConnections() throws {
        let sourceId = UUID()
        let targetId = UUID()

        var sourceNode = SpatialNode(id: sourceId, type: .code, position: .zero, title: "Source")
        sourceNode.nextNodeId = targetId
        sourceNode.connectedNodeIds = [targetId]

        let targetNode = SpatialNode(id: targetId, type: .code, position: .zero, title: "Target")
        let store = ProjectStore(
            fileName: "test_del_undo_connections.json",
            initialNodes: [sourceNode, targetNode]
        )
        let undoManager = UndoManager()
        store.undoManager = undoManager

        store.deleteNode(id: targetId)
        undoManager.undo()

        let restoredSource = try #require(store.nodes.first(where: { $0.id == sourceId }))
        #expect(store.nodes.map(\.id) == [sourceId, targetId])
        #expect(restoredSource.nextNodeId == targetId)
        #expect(restoredSource.connectedNodeIds == [targetId])
    }

    @Test func requestSaveRespectsShowIndicatorFlag() async throws {
        let store = ProjectStore(fileName: "test_save_indicator.json")
        
        // 1. Silent save should not trigger visual indicator
        store.requestSave(showIndicator: false)
        #expect(!store.isSaving)
        
        // 2. Visual save should trigger visual indicator
        store.requestSave(showIndicator: true)
        #expect(store.isSaving)
        
        // Wait for debounce (500ms) and actual background save to finish
        try? await Task.sleep(nanoseconds: 700_000_000)
        
        #expect(!store.isSaving)
    }

    @Test func organizeNodesRegistersUndoAndRedo() throws {
        let node1Id = UUID()
        let node2Id = UUID()
        let node1 = SpatialNode(id: node1Id, type: .code, position: CGPoint(x: 10, y: 20), title: "Node 1")
        let node2 = SpatialNode(id: node2Id, type: .code, position: CGPoint(x: 30, y: 40), title: "Node 2")
        
        let store = ProjectStore(fileName: "test_organize_undo_redo.json", initialNodes: [node1, node2])
        let undoManager = UndoManager()
        store.undoManager = undoManager
        
        store.organizeNodes(isHome: false)
        
        let n1PosAfter = store.nodes.first(where: { $0.id == node1Id })!.position
        let n2PosAfter = store.nodes.first(where: { $0.id == node2Id })!.position
        
        #expect(n1PosAfter != CGPoint(x: 10, y: 20) || n2PosAfter != CGPoint(x: 30, y: 40))
        #expect(undoManager.canUndo)
        
        // 1. Undo
        undoManager.undo()
        
        let n1PosRestored = store.nodes.first(where: { $0.id == node1Id })!.position
        let n2PosRestored = store.nodes.first(where: { $0.id == node2Id })!.position
        
        #expect(n1PosRestored == CGPoint(x: 10, y: 20))
        #expect(n2PosRestored == CGPoint(x: 30, y: 40))
        #expect(undoManager.canRedo)
        
        // 2. Redo
        undoManager.redo()
        
        let n1PosRedone = store.nodes.first(where: { $0.id == node1Id })!.position
        let n2PosRedone = store.nodes.first(where: { $0.id == node2Id })!.position
        
        #expect(n1PosRedone == n1PosAfter)
        #expect(n2PosRedone == n2PosAfter)
    }

    @Test func organizeNodesResetsHomeNodesToDefaults() throws {
        let node = SpatialNode(id: UUID(), type: .standard, position: CGPoint(x: 999, y: 999), title: "Home Node", action: .createNewProject)
        let store = ProjectStore(fileName: "test_home_reset.json", initialNodes: [node])
        
        store.organizeNodes(isHome: true)
        
        let nodePos = store.nodes[0].position
        #expect(nodePos == CGPoint(x: 0, y: 0))
    }

    @Test func organizeNodesProducesHierarchicalFlow() throws {
        let node1Id = UUID()
        let node2Id = UUID()
        let node1 = SpatialNode(id: node1Id, type: .code, position: CGPoint(x: 100, y: 100), title: "Source")
        var node2 = SpatialNode(id: node2Id, type: .code, position: CGPoint(x: 0, y: 0), title: "Target")
        node2.inputNodeIds = [node1Id]
        
        let store = ProjectStore(fileName: "test_flow.json", initialNodes: [node1, node2])
        store.organizeNodes(isHome: false)
        
        let pos1 = store.nodes.first(where: { $0.id == node1Id })!.position
        let pos2 = store.nodes.first(where: { $0.id == node2Id })!.position
        
        #expect(pos1.x < pos2.x)
    }

    @Test func organizeNodesAppliesLargerVerticalSpacingForWebViews() throws {
        let node1Id = UUID()
        let node2Id = UUID()
        let node1 = SpatialNode(id: node1Id, type: .webView, position: CGPoint(x: 0, y: 0), title: "WebView 1")
        let node2 = SpatialNode(id: node2Id, type: .webView, position: CGPoint(x: 100, y: 100), title: "WebView 2")
        
        let store = ProjectStore(fileName: "test_webview_spacing.json", initialNodes: [node1, node2])
        store.organizeNodes(isHome: false)
        
        let pos1 = store.nodes.first(where: { $0.id == node1Id })!.position
        let pos2 = store.nodes.first(where: { $0.id == node2Id })!.position
        
        let distanceY = abs(pos1.y - pos2.y)
        #expect(distanceY == 300)
    }

    @Test func organizeNodesAvoidsClusterOverlap() throws {
        let node1 = SpatialNode(id: UUID(), type: .code, position: CGPoint(x: 0, y: 0), title: "Cluster 1 Node")
        let node2 = SpatialNode(id: UUID(), type: .code, position: CGPoint(x: 100, y: 100), title: "Cluster 2 Node")
        
        let store = ProjectStore(fileName: "test_cluster_stacking.json", initialNodes: [node1, node2])
        store.organizeNodes(isHome: false)
        
        let pos1 = store.nodes[0].position
        let pos2 = store.nodes[1].position
        
        #expect(pos1.x == 0)
        #expect(pos2.x == 900)
    }
}
