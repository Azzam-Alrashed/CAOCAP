import Foundation

@MainActor
struct LivePreviewOrchestrator {
    private let compiler = LivePreviewCompiler()
    
    /// Compiles the live preview and updates node HTML content.
    /// Returns true if any nodes were modified.
    func compile(nodes: inout [SpatialNode]) -> Bool {
        guard let compilation = compiler.compile(nodes: nodes),
              let webViewIndex = nodes.firstIndex(where: { $0.id == compilation.webViewNodeID }) else {
            return false
        }
        
        var modified = false
        
        // Update the WebView node if the content changed
        if nodes[webViewIndex].htmlContent != compilation.html {
            nodes[webViewIndex].htmlContent = compilation.html
            modified = true
        }
        
        return modified
    }
}
