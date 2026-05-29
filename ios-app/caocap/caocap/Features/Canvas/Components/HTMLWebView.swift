import SwiftUI
import WebKit

class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    
    init(_ delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

struct HTMLWebView: UIViewRepresentable {
    let htmlContent: String
    
    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: HTMLWebView
        
        init(_ parent: HTMLWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "caocapConsole",
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String,
                  let content = body["message"] as? String else {
                return
            }
            Task { @MainActor in
                ConsoleLogStore.shared.addLog(type: type, message: content)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        // Setup console interceptor script
        let source = """
        (function() {
            function formatArg(x) {
                try {
                    if (x === null) return 'null';
                    if (x === undefined) return 'undefined';
                    return (typeof x === 'object') ? JSON.stringify(x) : String(x);
                } catch(e) {
                    return String(x);
                }
            }
            function sendLog(type, args) {
                var msg = Array.prototype.slice.call(args).map(formatArg).join(' ');
                window.webkit.messageHandlers.caocapConsole.postMessage({
                    type: type,
                    message: msg
                });
            }
            var oldLog = console.log;
            console.log = function() {
                sendLog('log', arguments);
                if (oldLog) oldLog.apply(console, arguments);
            };
            var oldError = console.error;
            console.error = function() {
                sendLog('error', arguments);
                if (oldError) oldError.apply(console, arguments);
            };
            var oldWarn = console.warn;
            console.warn = function() {
                sendLog('warn', arguments);
                if (oldWarn) oldWarn.apply(console, arguments);
            };
            var oldInfo = console.info;
            console.info = function() {
                sendLog('info', arguments);
                if (oldInfo) oldInfo.apply(console, arguments);
            };
            window.onerror = function(message, source, lineno, colno, error) {
                var cleanSource = source ? source.substring(source.lastIndexOf('/') + 1) : '';
                window.webkit.messageHandlers.caocapConsole.postMessage({
                    type: 'error',
                    message: message + (cleanSource ? ' (' + cleanSource + ':' + lineno + ')' : '')
                });
                return false;
            };
        })();
        """
        
        let userScript = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        let controller = WKUserContentController()
        controller.addUserScript(userScript)
        controller.add(WeakScriptMessageHandler(context.coordinator), name: "caocapConsole")
        configuration.userContentController = controller
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
