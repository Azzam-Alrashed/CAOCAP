import CoreGraphics
import Foundation
import Testing
@testable import caocap

struct RootCanvasProviderTests {
    @Test func rootHomeCanvasIsEmpty() {
        #expect(RootCanvasProvider.nodes.isEmpty)
        #expect(RootCanvasProvider.snapshot.nodes.isEmpty)
        #expect(RootCanvasProvider.snapshot.viewportScale == RootCanvasProvider.defaultViewportScale)
        #expect(RootCanvasProvider.defaultViewportScale == 0.22)
    }
}
