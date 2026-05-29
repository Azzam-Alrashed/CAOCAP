import Foundation

@MainActor
struct LivePreviewOrchestrator {
    private let compiler = LivePreviewCompiler()
    
    /// Compiles the live preview and updates node state (input wiring + HTML content).
    /// Returns true if any nodes were modified.
    func compile(nodes: inout [SpatialNode]) -> Bool {
        guard let compilation = compiler.compile(nodes: nodes),
              let webViewIndex = nodes.firstIndex(where: { $0.id == compilation.webViewNodeID }) else {
            return false
        }
        
        var modified = false
        
        // Ensure the source code nodes are registered as inputs to the WebView 
        // so that the Magic Organize clustering treats them as a group.
        let sourceNodeIds = nodes.filter { [.html, .css, .javascript].contains($0.role) }.map { $0.id }
        if Set(nodes[webViewIndex].inputNodeIds ?? []) != Set(sourceNodeIds) {
            nodes[webViewIndex].inputNodeIds = sourceNodeIds
            modified = true
        }
        
        // Also ensure SRS is linked as an input to the HTML node so the entire chain stays together
        if let srsNode = nodes.first(where: { $0.role == .srs }),
           let htmlIndex = nodes.firstIndex(where: { $0.role == .html }) {
            if !(nodes[htmlIndex].inputNodeIds ?? []).contains(srsNode.id) {
                var currentInputs = nodes[htmlIndex].inputNodeIds ?? []
                currentInputs.append(srsNode.id)
                nodes[htmlIndex].inputNodeIds = currentInputs
                modified = true
            }
        }
        
        // Update the WebView node if the content changed
        if nodes[webViewIndex].htmlContent != compilation.html {
            nodes[webViewIndex].htmlContent = compilation.html
            modified = true
        }
        
        return modified
    }
}
