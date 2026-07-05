import CoreGraphics
import Testing
@testable import caocap

@MainActor
struct MiniAppVerificationServiceTests {
    @Test func offlineHTMLPassesRuntimeAndBehaviorCheck() async {
        let service = MiniAppVerificationService()
        let result = await service.verify(
            code: "<html><body><h1>Ready</h1></body></html>",
            checks: [
                CoCaptainVerificationCheck(
                    id: "heading",
                    description: "Heading is ready",
                    script: #"return document.querySelector("h1")?.textContent === "Ready";"#
                )
            ],
            node: makeNode()
        )

        #expect(result.passed)
    }

    @Test func runtimeExceptionFailsVerification() async {
        let service = MiniAppVerificationService()
        let result = await service.verify(
            code: "<html><body><script>throw new Error('boom')</script></body></html>",
            checks: [passingCheck],
            node: makeNode()
        )

        #expect(!result.passed)
        #expect(result.diagnostics.contains { $0.kind == .runtimeError })
    }

    @Test func falseAssertionFailsVerification() async {
        let service = MiniAppVerificationService()
        let result = await service.verify(
            code: "<html><body><h1>Wrong</h1></body></html>",
            checks: [
                CoCaptainVerificationCheck(
                    id: "heading",
                    description: "Heading is right",
                    script: #"return document.querySelector("h1")?.textContent === "Right";"#
                )
            ],
            node: makeNode()
        )

        #expect(!result.passed)
        #expect(result.checkResults.first?.passed == false)
    }

    @Test func networkCandidateIsBlockedBeforeLoading() async {
        let service = MiniAppVerificationService()
        let result = await service.verify(
            code: "<script>fetch('https://example.com')</script>",
            checks: [passingCheck],
            node: makeNode()
        )

        #expect(!result.passed)
        #expect(result.diagnostics.first?.kind == .blockedExternalAccess)
    }

    @Test func slowCheckTimesOut() async {
        let service = MiniAppVerificationService()
        let result = await service.verify(
            code: "<html><body>Ready</body></html>",
            checks: [
                CoCaptainVerificationCheck(
                    id: "slow",
                    description: "Never resolves",
                    script: "return await new Promise(function () {});"
                )
            ],
            node: makeNode()
        )

        #expect(!result.passed)
        #expect(result.checkResults.first?.detail?.contains("timed out") == true)
    }

    private var passingCheck: CoCaptainVerificationCheck {
        CoCaptainVerificationCheck(
            id: "body",
            description: "Body exists",
            script: "return document.body !== null;"
        )
    }

    private func makeNode() -> SpatialNode {
        SpatialNode(
            type: .miniApp,
            position: CGPoint(x: 0, y: 0),
            title: "Verifier",
            miniApp: MiniAppState(codeText: "<html><body></body></html>")
        )
    }
}
