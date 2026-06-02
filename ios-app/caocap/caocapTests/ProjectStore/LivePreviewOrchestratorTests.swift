import XCTest
@testable import caocap

@MainActor
final class LivePreviewOrchestratorTests: XCTestCase {
    var orchestrator: LivePreviewOrchestrator!
    
    override func setUp() async throws {
        orchestrator = LivePreviewOrchestrator()
    }
    
    func testReturnsFalseWhenNoWebViewNode() {
        var nodes = [SpatialNode(type: .code, position: .zero, title: "HTML")]
        let modified = orchestrator.compile(nodes: &nodes)
        XCTAssertFalse(modified)
    }
    
    func testWiresSourceNodesToWebViewAndUpdatesContent() {
        var htmlNode = SpatialNode(type: .code, position: .zero, title: "HTML")
        htmlNode.htmlContent = "<h1>Test</h1>"
        
        var cssNode = SpatialNode(type: .code, position: .zero, title: "CSS")
        cssNode.htmlContent = "h1 { color: red; }"
        
        var jsNode = SpatialNode(type: .code, position: .zero, title: "JavaScript")
        jsNode.htmlContent = "console.log('hi');"
        
        let webViewNode = SpatialNode(type: .webView, position: .zero, title: "Live Preview")
        
        var nodes = [htmlNode, cssNode, jsNode, webViewNode]
        let modified = orchestrator.compile(nodes: &nodes)
        
        XCTAssertTrue(modified)
        
        let updatedWebView = nodes.first(where: { $0.type == .webView })!
        
        // Input wiring check
        let inputIds = updatedWebView.inputNodeIds ?? []
        XCTAssertEqual(inputIds.count, 3)
        XCTAssertTrue(inputIds.contains(htmlNode.id))
        XCTAssertTrue(inputIds.contains(cssNode.id))
        XCTAssertTrue(inputIds.contains(jsNode.id))
        
        // Content compilation check
        XCTAssertNotNil(updatedWebView.htmlContent)
        XCTAssertTrue(updatedWebView.htmlContent!.contains("<h1>Test</h1>"))
        XCTAssertTrue(updatedWebView.htmlContent!.contains("h1 { color: red; }"))
        XCTAssertTrue(updatedWebView.htmlContent!.contains("console.log('hi');"))
    }
    
    func testWiresSRSNodeToHTMLNode() {
        var srsNode = SpatialNode(type: .srs, position: .zero, title: "SRS")
        var htmlNode = SpatialNode(type: .code, position: .zero, title: "HTML")
        htmlNode.htmlContent = "<h1>Test</h1>"
        let webViewNode = SpatialNode(type: .webView, position: .zero, title: "Live Preview")
        
        var nodes = [srsNode, htmlNode, webViewNode]
        let modified = orchestrator.compile(nodes: &nodes)
        
        XCTAssertTrue(modified)
        
        let updatedHtml = nodes.first(where: { $0.title == "HTML" })!
        XCTAssertEqual(updatedHtml.inputNodeIds?.count, 1)
        XCTAssertEqual(updatedHtml.inputNodeIds?.first, srsNode.id)
    }
    
    func testDoesNotModifyIfNothingChanged() {
        var htmlNode = SpatialNode(type: .code, position: .zero, title: "HTML")
        htmlNode.htmlContent = "<h1>Test</h1>"
        let webViewNode = SpatialNode(type: .webView, position: .zero, title: "Live Preview")
        
        var nodes = [htmlNode, webViewNode]
        
        // First compilation
        _ = orchestrator.compile(nodes: &nodes)
        
        // Second compilation
        let modified = orchestrator.compile(nodes: &nodes)
        XCTAssertFalse(modified)
    }
}
