import XCTest
@testable import caocap

@MainActor
final class LivePreviewOrchestratorTests: XCTestCase {
    var orchestrator: LivePreviewOrchestrator!
    
    override func setUp() async throws {
        orchestrator = LivePreviewOrchestrator()
    }
    
    func testReturnsFalseWhenNoWebViewNode() {
        var nodes = [SpatialNode(type: .code, position: .zero, title: "Code", textContent: "<h1>Test</h1>")]
        let modified = orchestrator.compile(nodes: &nodes)
        XCTAssertFalse(modified)
    }

    func testReturnsFalseWhenNoCodeNode() {
        let webViewNode = SpatialNode(type: .webView, position: .zero, title: "Live Preview")
        var nodes = [webViewNode]
        let modified = orchestrator.compile(nodes: &nodes)
        XCTAssertFalse(modified)
        XCTAssertNil(nodes.first(where: { $0.type == .webView })?.htmlContent)
    }
    
    func testUpdatesWebViewContentFromCodeNode() {
        let codeNode = SpatialNode(
            type: .code,
            position: .zero,
            title: "Code",
            textContent: "<html><head></head><body><h1>Test</h1><style>h1 { color: red; }</style><script>console.log('hi');</script></body></html>"
        )
        let webViewNode = SpatialNode(type: .webView, position: .zero, title: "Live Preview")
        
        var nodes = [codeNode, webViewNode]
        let modified = orchestrator.compile(nodes: &nodes)
        
        XCTAssertTrue(modified)
        
        let updatedWebView = nodes.first(where: { $0.type == .webView })!
        XCTAssertNotNil(updatedWebView.htmlContent)
        XCTAssertTrue(updatedWebView.htmlContent!.contains("<h1>Test</h1>"))
        XCTAssertTrue(updatedWebView.htmlContent!.contains("h1 { color: red; }"))
        XCTAssertTrue(updatedWebView.htmlContent!.contains("console.log('hi');"))
    }
    
    func testDoesNotModifyIfNothingChanged() {
        let codeNode = SpatialNode(
            type: .code,
            position: .zero,
            title: "Code",
            textContent: "<html><head></head><body><h1>Test</h1></body></html>"
        )
        let webViewNode = SpatialNode(type: .webView, position: .zero, title: "Live Preview")
        
        var nodes = [codeNode, webViewNode]
        
        _ = orchestrator.compile(nodes: &nodes)
        let modified = orchestrator.compile(nodes: &nodes)
        XCTAssertFalse(modified)
    }
}
