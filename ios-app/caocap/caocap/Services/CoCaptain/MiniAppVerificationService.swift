import Foundation
import WebKit

@MainActor
public protocol MiniAppVerifying: AnyObject {
    func unsupportedReason(for node: SpatialNode) -> String?
    func verify(
        code: String,
        checks: [CoCaptainVerificationCheck],
        node: SpatialNode
    ) async -> CoCaptainVerificationResult
}

/// Executes staged Mini-App source in an ephemeral, offline WKWebView.
///
/// No candidate is written to ProjectStore. Remote resources are blocked both
/// through WebKit content rules and document-start API guards.
@MainActor
public final class MiniAppVerificationService: NSObject, MiniAppVerifying, WKNavigationDelegate, WKScriptMessageHandler {
    private static let loadTimeoutNanoseconds: UInt64 = 5_000_000_000
    private static let checkTimeoutMilliseconds = 2_000
    private static let attemptTimeout: TimeInterval = 10

    private var loadContinuation: CheckedContinuation<Bool, Never>?
    private var diagnostics: [CoCaptainVerificationDiagnostic] = []

    public func unsupportedReason(for node: SpatialNode) -> String? {
        guard let miniApp = node.miniApp else {
            return "The selected node is not a Mini-App."
        }
        if !miniApp.firebaseConfigText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Firebase-backed Mini-Apps are not supported by offline verification yet."
        }
        if Self.containsExternalDependency(miniApp.codeText) {
            return "This Mini-App depends on external services or remote resources that the offline verifier cannot safely run."
        }
        return nil
    }

    public func verify(
        code: String,
        checks: [CoCaptainVerificationCheck],
        node: SpatialNode
    ) async -> CoCaptainVerificationResult {
        guard !Self.containsExternalDependency(code) else {
            return CoCaptainVerificationResult(
                diagnostics: [
                    CoCaptainVerificationDiagnostic(
                        kind: .blockedExternalAccess,
                        message: "The candidate introduced a remote resource or network API."
                    )
                ]
            )
        }

        var stagedNode = node
        stagedNode.miniApp?.codeText = code
        guard let compilation = LivePreviewCompiler().compile(node: stagedNode) else {
            return CoCaptainVerificationResult(
                diagnostics: [
                    CoCaptainVerificationDiagnostic(
                        kind: .invalidCandidate,
                        message: "The staged Mini-App could not be compiled."
                    )
                ]
            )
        }

        diagnostics = []
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(
            self,
            name: "cocaptainVerifier"
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: Self.instrumentationScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )

        if let ruleList = await Self.makeOfflineRuleList() {
            configuration.userContentController.add(ruleList)
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        let startedAt = Date()
        let loaded = await load(compilation.html, in: webView)
        guard loaded else {
            configuration.userContentController.removeScriptMessageHandler(forName: "cocaptainVerifier")
            return CoCaptainVerificationResult(
                diagnostics: diagnostics + [
                    CoCaptainVerificationDiagnostic(
                        kind: .timeout,
                        message: "The staged preview did not finish loading within 5 seconds."
                    )
                ]
            )
        }

        try? await Task.sleep(nanoseconds: 250_000_000)
        var results: [CoCaptainVerificationCheckResult] = []
        for check in checks {
            guard !Task.isCancelled else {
                configuration.userContentController.removeScriptMessageHandler(forName: "cocaptainVerifier")
                return CoCaptainVerificationResult(
                    diagnostics: [
                        CoCaptainVerificationDiagnostic(kind: .timeout, message: "Verification was cancelled.")
                    ],
                    checkResults: results
                )
            }
            guard Date().timeIntervalSince(startedAt) < Self.attemptTimeout else {
                diagnostics.append(
                    CoCaptainVerificationDiagnostic(
                        kind: .timeout,
                        message: "The verification attempt exceeded 10 seconds."
                    )
                )
                break
            }

            results.append(await run(check: check, in: webView))
        }

        configuration.userContentController.removeScriptMessageHandler(forName: "cocaptainVerifier")
        webView.stopLoading()
        return CoCaptainVerificationResult(
            diagnostics: diagnostics,
            checkResults: results
        )
    }

    private func load(_ html: String, in webView: WKWebView) async -> Bool {
        await withCheckedContinuation { continuation in
            loadContinuation = continuation
            webView.loadHTMLString(html, baseURL: nil)

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: Self.loadTimeoutNanoseconds)
                self?.completeLoad(false)
            }
        }
    }

    private func completeLoad(_ succeeded: Bool) {
        guard let continuation = loadContinuation else { return }
        loadContinuation = nil
        continuation.resume(returning: succeeded)
    }

    private func run(
        check: CoCaptainVerificationCheck,
        in webView: WKWebView
    ) async -> CoCaptainVerificationCheckResult {
        let source = """
        return await Promise.race([
          (async function() {
            try {
              const value = await (async function() {
                \(check.script)
              })();
              return { passed: value === true, detail: value === true ? "" : "Assertion returned false." };
            } catch (error) {
              return { passed: false, detail: String(error && error.message ? error.message : error) };
            }
          })(),
          new Promise(function(resolve) {
            setTimeout(function() {
              resolve({ passed: false, detail: "Check timed out after 2 seconds." });
            }, \(Self.checkTimeoutMilliseconds));
          })
        ]);
        """

        do {
            let value = try await webView.callAsyncJavaScript(
                source,
                arguments: [:],
                in: nil,
                contentWorld: .page
            )
            let dictionary = value as? [String: Any]
            let passed = dictionary?["passed"] as? Bool ?? false
            let detail = (dictionary?["detail"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return CoCaptainVerificationCheckResult(
                check: check,
                passed: passed,
                detail: detail
            )
        } catch {
            return CoCaptainVerificationCheckResult(
                check: check,
                passed: false,
                detail: error.localizedDescription
            )
        }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        completeLoad(true)
    }

    public func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        diagnostics.append(
            CoCaptainVerificationDiagnostic(
                kind: .loadFailure,
                message: error.localizedDescription
            )
        )
        completeLoad(false)
    }

    public func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        diagnostics.append(
            CoCaptainVerificationDiagnostic(
                kind: .loadFailure,
                message: error.localizedDescription
            )
        )
        completeLoad(false)
    }

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "cocaptainVerifier",
              let body = message.body as? [String: Any],
              let kindValue = body["kind"] as? String,
              let kind = CoCaptainVerificationDiagnosticKind(rawValue: kindValue),
              let text = body["message"] as? String else {
            return
        }
        diagnostics.append(CoCaptainVerificationDiagnostic(kind: kind, message: text))
    }

    private static func makeOfflineRuleList() async -> WKContentRuleList? {
        let rules = """
        [{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}}]
        """
        return await withCheckedContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "caocap-verified-loop-offline",
                encodedContentRuleList: rules
            ) { ruleList, _ in
                continuation.resume(returning: ruleList)
            }
        }
    }

    private static func containsExternalDependency(_ code: String) -> Bool {
        let patterns = [
            #"<script[^>]+src\s*=\s*["']\s*https?://"#,
            #"<link[^>]+href\s*=\s*["']\s*https?://"#,
            #"\bfetch\s*\("#,
            #"\bXMLHttpRequest\b"#,
            #"\bWebSocket\s*\("#,
            #"\bEventSource\s*\("#,
            #"\bsendBeacon\s*\("#,
            #"\b__caocapFirestore\b"#
        ]
        return patterns.contains { pattern in
            code.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static let instrumentationScript = """
    (function () {
      function report(kind, value) {
        try {
          window.webkit.messageHandlers.cocaptainVerifier.postMessage({
            kind: kind,
            message: String(value && value.message ? value.message : value)
          });
        } catch (_) {}
      }

      window.addEventListener('error', function (event) {
        report('runtimeError', event.error || event.message || 'Unknown runtime error');
      });
      window.addEventListener('unhandledrejection', function (event) {
        report('runtimeError', event.reason || 'Unhandled promise rejection');
      });

      var originalConsoleError = console.error;
      console.error = function () {
        report('consoleError', Array.prototype.map.call(arguments, String).join(' '));
        return originalConsoleError.apply(console, arguments);
      };

      function blocked(name) {
        report('blockedExternalAccess', name + ' is disabled during offline verification.');
      }

      window.fetch = function () {
        blocked('fetch');
        return Promise.reject(new Error('Network access is disabled during verification.'));
      };
      window.XMLHttpRequest = function () {
        blocked('XMLHttpRequest');
        throw new Error('Network access is disabled during verification.');
      };
      window.WebSocket = function () {
        blocked('WebSocket');
        throw new Error('Network access is disabled during verification.');
      };
      window.EventSource = function () {
        blocked('EventSource');
        throw new Error('Network access is disabled during verification.');
      };
      if (navigator.sendBeacon) {
        navigator.sendBeacon = function () {
          blocked('sendBeacon');
          return false;
        };
      }
    })();
    """
}
