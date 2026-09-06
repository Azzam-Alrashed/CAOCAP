import XCTest
import SwiftUI
@testable import caocap

@MainActor
final class NodeMutationEngineTests: XCTestCase {
    var engine: NodeMutationEngine!

    override func setUp() async throws {
        engine = NodeMutationEngine()
    }

    func testAddNodeCreatesStandardCardByDefault() {
        var nodes: [SpatialNode] = []
        var compileCalled = false
        engine.onCompileLivePreview = { _ in compileCalled = true }

        engine.addNode(nodes: &nodes)

        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].type, .standard)
        XCTAssertEqual(nodes[0].theme, NodeType.standard.defaultTheme)
        XCTAssertEqual(nodes[0].title, NodeType.standard.defaultTitle)
        XCTAssertEqual(nodes[0].icon, NodeType.standard.defaultIcon)
        XCTAssertNil(nodes[0].subtitle)
        XCTAssertNil(nodes[0].miniApp)
        XCTAssertTrue(compileCalled)
    }

    func testUpdateMiniAppSectionsTriggersExpectedCallbacks() {
        var nodes = [
            SpatialNode(type: .miniApp, position: .zero, title: "Mini-App", miniApp: MiniAppState())
        ]

        var saveCalled = false
        var compileCalled = false
        engine.onRequestSave = { _ in saveCalled = true }
        engine.onCompileLivePreview = { _ in compileCalled = true }

        engine.updateMiniAppSRS(nodes: &nodes, id: nodes[0].id, text: "# Intent\nShip it.", persist: true)
        XCTAssertEqual(nodes[0].miniApp?.srsText, "# Intent\nShip it.")
        XCTAssertTrue(saveCalled)

        engine.updateMiniAppCode(nodes: &nodes, id: nodes[0].id, text: "<h1>Updated</h1>", persist: true)
        XCTAssertEqual(nodes[0].miniApp?.codeText, "<h1>Updated</h1>")
        XCTAssertTrue(compileCalled)
    }

    func testApplyingCanonicalThemeRepairsMiniAppTheme() {
        let miniApp = SpatialNode(type: .miniApp, position: .zero, title: "Mini-App", theme: .orange)

        XCTAssertEqual(miniApp.applyingCanonicalThemeIfNeeded().theme, .orange)
    }

    func testDeleteNodeCleansUpConnections() {
        let node1 = SpatialNode(type: .miniApp, position: .zero, title: "1")
        var node2 = SpatialNode(type: .miniApp, position: .zero, title: "2")

        node2.connectedNodeIds = [node1.id]
        node2.nextNodeId = node1.id

        var nodes = [node1, node2]

        engine.deleteNode(nodes: &nodes, id: node1.id)

        XCTAssertEqual(nodes.count, 1)
        let updatedNode2 = nodes[0]

        XCTAssertNil(updatedNode2.connectedNodeIds)
        XCTAssertNil(updatedNode2.nextNodeId)
    }
}
