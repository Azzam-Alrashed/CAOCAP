import Foundation

@MainActor
struct LivePreviewOrchestrator {
    private let compiler = LivePreviewCompiler()
    
    /// Compiles the live preview and updates node HTML content.
    /// Returns true if any nodes were modified.
    func compile(nodes: inout [SpatialNode]) -> Bool {
        var modified = false

        for index in nodes.indices where nodes[index].type == .miniApp {
            guard let compilation = compiler.compile(node: nodes[index]) else { continue }
            if nodes[index].miniApp?.compiledHTML != compilation.html {
                nodes[index].miniApp?.compiledHTML = compilation.html
                modified = true
            }
        }

        return modified
    }
}
