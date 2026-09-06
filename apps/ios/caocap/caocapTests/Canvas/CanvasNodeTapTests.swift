import CoreGraphics
import Foundation
import Testing
@testable import caocap

struct CanvasNodeTapTests {
    @Test func leftoverMiniAppJSONDecodesAsAnInspectableCard() throws {
        let json = Data("""
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "type": "miniApp",
          "position": [0, 0],
          "title": "Leftover",
          "theme": "blue"
        }
        """.utf8)
        let node = try JSONDecoder().decode(SpatialNode.self, from: json)

        #expect(node.type == .standard)
        #expect(node.tapDestination == .inspect)
    }

    @Test func actionNodesStillDispatch() {
        let node = SpatialNode(
            position: .zero,
            title: "Settings",
            action: .openSettings
        )

        #expect(node.tapDestination == .action(.openSettings))
    }

    @Test func subCanvasNodesStillOpenLinkedCanvas() {
        let node = SpatialNode(
            type: .subCanvas,
            position: .zero,
            title: "Portal",
            linkedCanvasFileName: "canvas_other.json"
        )

        #expect(node.tapDestination == .subCanvas("canvas_other.json"))
    }
}
