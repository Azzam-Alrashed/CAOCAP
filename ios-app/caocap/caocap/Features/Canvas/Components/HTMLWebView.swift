import SwiftUI
import WebKit

/// A thin `UIViewRepresentable` wrapper around `WKWebView` that renders an HTML
/// string inline inside a SwiftUI view. Used to display compiled Mini-App output
/// both as a scaled thumbnail inside `NodeView` and as a full-screen preview inside
/// `MiniAppPreviewShell`.
struct HTMLWebView: UIViewRepresentable {
    /// The complete HTML string to render, typically the `compiledHTML` of a
    /// `MiniApp` model object.
    let htmlContent: String

    /// Creates and configures the underlying `WKWebView`.
    /// - Inline media playback is enabled so that `<video>` and `<audio>` tags
    ///   work without requiring the user to enter full-screen.
    /// - The view is made transparent so Mini-App HTML can use its own background.
    /// - Scroll is disabled because the node thumbnail must not be scrollable.
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        return webView
    }
    
    /// Reloads the HTML string whenever `htmlContent` changes.
    /// Using `loadHTMLString` with a `nil` base URL restricts the page to the
    /// `about:blank` origin, which prevents local-file access from the HTML.
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
