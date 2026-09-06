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

        engine.addNode(nodes: &nodes)

        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].type, .standard)
        XCTAssertEqual(nodes[0].theme, NodeType.standard.defaultTheme)
        XCTAssertEqual(nodes[0].title, NodeType.standard.defaultTitle)
        XCTAssertEqual(nodes[0].icon, NodeType.standard.defaultIcon)
        XCTAssertNil(nodes[0].subtitle)
    }

    func testApplyingCanonicalThemeLeavesCustomCardTheme() {
        let card = SpatialNode(type: .standard, position: .zero, title: "Card", theme: .orange)

        XCTAssertEqual(card.applyingCanonicalThemeIfNeeded().theme, .orange)
    }

    func testDeleteNodeCleansUpConnections() {
        let node1 = SpatialNode(type: .standard, position: .zero, title: "1")
        var node2 = SpatialNode(type: .standard, position: .zero, title: "2")

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
