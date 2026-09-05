import Foundation

public struct LivePreviewCompilation: Hashable {
    public let miniAppNodeID: UUID
    public let html: String
}

/// Produces each Mini-App's runnable preview payload from its embedded source.
public struct LivePreviewCompiler {
    public init() {}

    public func compile(nodes: [SpatialNode]) -> LivePreviewCompilation? {
        guard let node = nodes.first(where: { $0.type == .miniApp }) else { return nil }
        return compile(node: node)
    }

    public func compile(node: SpatialNode) -> LivePreviewCompilation? {
        guard node.type == .miniApp, let miniApp = node.miniApp else {
            return nil
        }

        let hasFirebaseConfig = !miniApp.firebaseConfigText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        var compiledHTML = miniApp.codeText
        injectFirebaseHead(from: miniApp, into: &compiledHTML)
        injectViewportMeta(into: &compiledHTML)
        if hasFirebaseConfig {
            injectFirebasePreviewDiagnostics(into: &compiledHTML)
        }
        return LivePreviewCompilation(miniAppNodeID: node.id, html: compiledHTML)
    }

    private func injectViewportMeta(into html: inout String) {
        if html.localizedCaseInsensitiveContains("name=\"viewport\"") || html.localizedCaseInsensitiveContains("name='viewport'") {
            return
        }
        
        let metaTag = "\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n"
        if let headStart = html.range(of: "<head", options: .caseInsensitive),
           let headOpenEnd = html.range(of: ">", range: headStart.upperBound..<html.endIndex) {
            html.insert(contentsOf: metaTag, at: headOpenEnd.upperBound)
        } else if let htmlStart = html.range(of: "<html", options: .caseInsensitive),
                  let htmlOpenEnd = html.range(of: ">", range: htmlStart.upperBound..<html.endIndex) {
            html.insert(contentsOf: "<head>\(metaTag)</head>", at: htmlOpenEnd.upperBound)
        } else {
            html = """
            <!DOCTYPE html>
            <html><head>\(metaTag)</head><body>
            \(html)
            </body></html>
            """
        }
    }

    private func injectFirebaseHead(from miniApp: MiniAppState, into html: inout String) {
        guard let snippet = FirebasePreviewBootstrap.headInjectionHTML(from: miniApp) else { return }
        if let headStart = html.range(of: "<head", options: .caseInsensitive),
           let headOpenEnd = html.range(of: ">", range: headStart.upperBound..<html.endIndex) {
            html.insert(contentsOf: snippet, at: headOpenEnd.upperBound)
            return
        }
        if let htmlStart = html.range(of: "<html", options: .caseInsensitive),
           let htmlOpenEnd = html.range(of: ">", range: htmlStart.upperBound..<html.endIndex) {
            html.insert(contentsOf: "<head>\(snippet)</head>", at: htmlOpenEnd.upperBound)
            return
        }
        html = """
        <!DOCTYPE html>
        <html><head>\(snippet)</head><body>
        \(html)
        </body></html>
        """
    }

    /// When Firestore is not ready, show a short bar in the preview so users know to fix the Mini-App Firebase config.
    private func injectFirebasePreviewDiagnostics(into html: inout String) {
        // Use single-quoted JS strings so Swift multiline literal stays valid.
        let snippet = #"""
        <script>
        (function(){
          function showBanner(){
            if (document.querySelector('[data-caocap-fb-diag]')) return;
            var st = window.__caocapFirestoreStatus;
            var db = window.__caocapFirestore;
            if (st === 'ready' && db) return;
            var el = document.createElement('div');
            el.setAttribute('data-caocap-fb-diag','1');
            el.setAttribute('style','position:fixed;bottom:0;left:0;right:0;padding:10px 12px;font:12px/1.35 -apple-system,BlinkMacSystemFont,sans-serif;background:rgba(18,18,20,0.96);color:#ffb454;border-top:1px solid #555;z-index:2147483646;');
            var err = (window.__caocapFirestoreLastError || '').trim();
            var msg;
            if (!st && !db) {
              msg = 'Mini-App Preview: Firebase did not load. Paste the real Web app config in this Mini-App Firebase tool, remove YOUR_… placeholders, then tap Done to refresh.';
            } else {
              msg = 'Mini-App Preview: Firebase status is "' + st + '"' + (err ? (' — ' + err) : '') + '. Open this Mini-App Firebase tool and fix the Web config (apiKey + projectId), then refresh.';
            }
            el.textContent = msg;
            (document.body || document.documentElement).appendChild(el);
          }
          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', function(){ setTimeout(showBanner, 80); });
          } else {
            setTimeout(showBanner, 80);
          }
        })();
        </script>
        """#

        if let bodyRange = html.range(of: "</body>", options: .caseInsensitive) {
            html.insert(contentsOf: snippet, at: bodyRange.lowerBound)
        } else if let htmlRange = html.range(of: "</html>", options: .caseInsensitive) {
            html.insert(contentsOf: snippet, at: htmlRange.lowerBound)
        } else {
            html += snippet
        }
    }
}
