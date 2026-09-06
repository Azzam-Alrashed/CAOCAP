import CoreGraphics
import Foundation
import Testing
@testable import caocap

struct CanvasNodeTapTests {
    @Test func leftoverMiniAppNodeInspectsInsteadOfOpeningAWorkspace() {
        let node = SpatialNode(
            type: .miniApp,
            position: .zero,
            title: "Leftover",
            miniApp: MiniAppState(codeText: "<h1>Hi</h1>")
        )

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
