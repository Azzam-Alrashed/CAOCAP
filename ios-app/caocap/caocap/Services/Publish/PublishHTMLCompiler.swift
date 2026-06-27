import Foundation

/// Compiles Mini-App HTML for Vercel publish with PWA / Home Screen meta tags.
struct PublishHTMLCompiler {
    private let previewCompiler = LivePreviewCompiler()

    func compileForPublish(node: SpatialNode) -> String? {
        guard let compilation = previewCompiler.compile(node: node) else { return nil }
        return injectPWAMeta(into: compilation.html, appTitle: node.title)
    }

    func injectPWAMeta(into html: String, appTitle: String) -> String {
        var output = html
        let trimmedTitle = appTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = trimmedTitle.isEmpty ? "CAOCAP Mini-App" : trimmedTitle

        let pwaTags = """
        <meta name="apple-mobile-web-app-capable" content="yes">
        <meta name="apple-mobile-web-app-status-bar-style" content="default">
        <meta name="apple-mobile-web-app-title" content="\(escapeHTML(displayTitle))">
        <meta name="mobile-web-app-capable" content="yes">
        <meta name="theme-color" content="#000000">
        """

        if let headStart = output.range(of: "<head", options: .caseInsensitive),
           let headOpenEnd = output.range(of: ">", range: headStart.upperBound..<output.endIndex) {
            output.insert(contentsOf: "\n\(pwaTags)\n", at: headOpenEnd.upperBound)
        } else if let htmlStart = output.range(of: "<html", options: .caseInsensitive),
                  let htmlOpenEnd = output.range(of: ">", range: htmlStart.upperBound..<output.endIndex) {
            output.insert(contentsOf: "<head>\n\(pwaTags)\n</head>", at: htmlOpenEnd.upperBound)
        } else {
            output = """
            <!DOCTYPE html>
            <html><head>
            \(pwaTags)
            </head><body>
            \(output)
            </body></html>
            """
        }

        return output
    }

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
