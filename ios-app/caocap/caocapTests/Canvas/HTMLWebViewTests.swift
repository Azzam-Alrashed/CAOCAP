import Testing
@testable import caocap

struct HTMLWebViewTests {
    @MainActor
    @Test func coordinatorLoadsOnlyChangedHTML() {
        let coordinator = HTMLWebView.Coordinator()

        #expect(coordinator.shouldLoad("<h1>First</h1>"))
        #expect(!coordinator.shouldLoad("<h1>First</h1>"))
        #expect(coordinator.shouldLoad("<h1>Changed</h1>"))
        #expect(!coordinator.shouldLoad("<h1>Changed</h1>"))
    }
}
