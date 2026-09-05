import XCTest
@testable import caocap

@MainActor
final class LivePreviewOrchestratorTests: XCTestCase {
    var orchestrator: LivePreviewOrchestrator!

    override func setUp() async throws {
        orchestrator = LivePreviewOrchestrator()
    }

    func testReturnsFalseWhenNoMiniAppNode() {
        var nodes = [SpatialNode(type: .standard, position: .zero, title: "Note")]
        let modified = orchestrator.compile(nodes: &nodes)
        XCTAssertFalse(modified)
    }

    func testUpdatesMiniAppCompiledHTMLFromEmbeddedCode() {
        let miniAppNode = SpatialNode(
            type: .miniApp,
            position: .zero,
            title: "Mini-App",
            miniApp: MiniAppState(
                codeText: "<html><head></head><body><h1>Test</h1><style>h1 { color: red; }</style><script>console.log('hi');</script></body></html>"
            )
        )

        var nodes = [miniAppNode]
        let modified = orchestrator.compile(nodes: &nodes)

        XCTAssertTrue(modified)
        let compiled = nodes[0].miniApp?.compiledHTML
        XCTAssertNotNil(compiled)
        XCTAssertTrue(compiled!.contains("<h1>Test</h1>"))
        XCTAssertTrue(compiled!.contains("h1 { color: red; }"))
        XCTAssertTrue(compiled!.contains("console.log('hi');"))
    }

    func testDoesNotModifyIfNothingChanged() {
        let miniAppNode = SpatialNode(
            type: .miniApp,
            position: .zero,
            title: "Mini-App",
            miniApp: MiniAppState(codeText: "<html><head></head><body><h1>Test</h1></body></html>")
        )

        var nodes = [miniAppNode]
        _ = orchestrator.compile(nodes: &nodes)
        let modified = orchestrator.compile(nodes: &nodes)

        XCTAssertFalse(modified)
    }
}
