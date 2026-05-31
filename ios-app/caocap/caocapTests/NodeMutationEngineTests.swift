import XCTest
import SwiftUI
@testable import caocap

@MainActor
final class NodeMutationEngineTests: XCTestCase {
    var engine: NodeMutationEngine!
    
    override func setUp() async throws {
        engine = NodeMutationEngine()
    }
    
    func testAddNodeSetsCorrectDefaults() {
        var nodes: [SpatialNode] = []
        engine.addNode(nodes: &nodes, type: .code)
        
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].type, .code)
        XCTAssertEqual(nodes[0].textContent, "// Start coding here...")
        XCTAssertEqual(nodes[0].title, "New Logic")
        
        engine.addNode(nodes: &nodes, type: .srs)
        XCTAssertEqual(nodes.count, 2)
        XCTAssertEqual(nodes[1].type, .srs)
        XCTAssertEqual(nodes[1].title, "Software Requirements Specification")
        
        engine.addNode(nodes: &nodes, type: .console)
        XCTAssertEqual(nodes.count, 3)
        XCTAssertEqual(nodes[2].type, .console)
        XCTAssertEqual(nodes[2].title, "Console")
        XCTAssertEqual(nodes[2].subtitle, "Logs and errors from Live Preview")
    }
    
    func testUpdateNodeTypeTriggersCallbacks() {
        var nodes = [SpatialNode(type: .code, position: .zero, title: "HTML")]
        
        var saveCalled = false
        var compileCalled = false
        
        engine.onRequestSave = { _ in saveCalled = true }
        engine.onCompileLivePreview = { _ in compileCalled = true }
        
        engine.updateNodeType(nodes: &nodes, id: nodes[0].id, type: .srs, persist: true)
        
        XCTAssertEqual(nodes[0].type, .srs)
        XCTAssertTrue(saveCalled)
        XCTAssertTrue(compileCalled)
    }
    
    func testDeleteNodeCleansUpConnections() {
        let node1 = SpatialNode(type: .code, position: .zero, title: "1")
        var node2 = SpatialNode(type: .code, position: .zero, title: "2")
        
        node2.inputNodeIds = [node1.id]
        node2.connectedNodeIds = [node1.id]
        node2.nextNodeId = node1.id
        
        var nodes = [node1, node2]
        
        engine.deleteNode(nodes: &nodes, id: node1.id)
        
        XCTAssertEqual(nodes.count, 1)
        let updatedNode2 = nodes[0]
        
        XCTAssertNil(updatedNode2.inputNodeIds)
        XCTAssertNil(updatedNode2.connectedNodeIds)
        XCTAssertNil(updatedNode2.nextNodeId)
    }
}
