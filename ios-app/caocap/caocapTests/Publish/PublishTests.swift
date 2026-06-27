import XCTest
@testable import caocap

final class PublishRepoNamingTests: XCTestCase {
    func testSanitizeRemovesSpecialCharacters() {
        XCTAssertEqual(PublishRepoNaming.sanitize("My Cool App!"), "my-cool-app")
    }

    func testSanitizeCollapsesHyphens() {
        XCTAssertEqual(PublishRepoNaming.sanitize("hello---world"), "hello-world")
    }

    func testRepositoryNameUsesTitleAndShortID() {
        let id = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
        let name = PublishRepoNaming.repositoryName(nodeTitle: "Todo App", nodeID: id)
        XCTAssertEqual(name, "caocap-todo-app-123456")
    }

    func testRepositoryNameFallbackWhenTitleEmpty() {
        let id = UUID(uuidString: "ABCDEF01-1234-1234-1234-123456789ABC")!
        let name = PublishRepoNaming.repositoryName(nodeTitle: "   ", nodeID: id)
        XCTAssertEqual(name, "caocap-miniapp-abcdef")
    }
}

final class PublishHTMLCompilerTests: XCTestCase {
    func testInjectPWAMetaIntoExistingHead() {
        let compiler = PublishHTMLCompiler()
        let html = "<html><head><title>App</title></head><body></body></html>"
        let output = compiler.injectPWAMeta(into: html, appTitle: "My App")

        XCTAssertTrue(output.contains("apple-mobile-web-app-capable"))
        XCTAssertTrue(output.contains("apple-mobile-web-app-title\" content=\"My App\""))
        XCTAssertTrue(output.contains("mobile-web-app-capable"))
    }

    func testInjectPWAMetaWrapsFragmentHTML() {
        let compiler = PublishHTMLCompiler()
        let output = compiler.injectPWAMeta(into: "<h1>Hello</h1>", appTitle: "Hello")

        XCTAssertTrue(output.contains("<!DOCTYPE html>"))
        XCTAssertTrue(output.contains("apple-mobile-web-app-title"))
        XCTAssertTrue(output.contains("<h1>Hello</h1>"))
    }

    func testCompileForPublishUsesLivePreviewPipeline() {
        let compiler = PublishHTMLCompiler()
        let node = SpatialNode(
            type: .miniApp,
            position: .zero,
            title: "Counter",
            miniApp: MiniAppState(codeText: "<html><body><h1>Counter</h1></body></html>")
        )

        let html = compiler.compileForPublish(node: node)
        XCTAssertNotNil(html)
        XCTAssertTrue(html!.contains("<h1>Counter</h1>"))
        XCTAssertTrue(html!.contains("apple-mobile-web-app-title\" content=\"Counter\""))
    }
}

final class MiniAppPublishMetadataTests: XCTestCase {
    func testMiniAppStateEncodesPublishMetadata() throws {
        let state = MiniAppState(
            codeText: "<h1>Hi</h1>",
            publishURL: "https://example.vercel.app",
            githubRepoOwner: "dev",
            githubRepoName: "caocap-demo-abc123",
            githubRepoId: 42,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            isPublishRepoPrivate: false
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(MiniAppState.self, from: data)

        XCTAssertEqual(decoded.publishURL, "https://example.vercel.app")
        XCTAssertEqual(decoded.githubRepoOwner, "dev")
        XCTAssertEqual(decoded.githubRepoName, "caocap-demo-abc123")
        XCTAssertEqual(decoded.githubRepoId, 42)
        XCTAssertEqual(decoded.isPublishRepoPrivate, false)
    }

    func testLegacyMiniAppStateDecodesWithoutPublishFields() throws {
        let json = """
        {"srsText":"","srsReadinessState":"empty","codeText":"","firebaseConfigText":""}
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(MiniAppState.self, from: data)

        XCTAssertNil(decoded.publishURL)
        XCTAssertNil(decoded.githubRepoOwner)
        XCTAssertNil(decoded.githubRepoId)
    }
}

@MainActor
final class PublishCoordinatorGateTests: XCTestCase {
    func testGateRequiresProBeforeSignIn() {
        let coordinator = PublishCoordinator()
        XCTAssertEqual(coordinator.gate(isSubscribed: false, isAnonymous: true), .requiresPro)
        XCTAssertEqual(coordinator.gate(isSubscribed: false, isAnonymous: false), .requiresPro)
    }

    func testGateRequiresSignInForFreeAuthenticatedUsers() {
        let coordinator = PublishCoordinator()
        XCTAssertEqual(coordinator.gate(isSubscribed: true, isAnonymous: true), .requiresSignIn)
    }

    func testGateReadyForProSignedInUsers() {
        let coordinator = PublishCoordinator()
        XCTAssertEqual(coordinator.gate(isSubscribed: true, isAnonymous: false), .ready)
    }

    func testFirebaseHostnameExtraction() {
        XCTAssertEqual(
            PublishCoordinator.firebaseHostname(from: "https://my-app.vercel.app"),
            "my-app.vercel.app"
        )
    }
}

@MainActor
final class PublishMetadataMutationTests: XCTestCase {
    func testUpdateMiniAppPublishMetadataPersistsOnNode() {
        let engine = NodeMutationEngine()
        var nodes = [SpatialNode(type: .miniApp, position: .zero, title: "App")]
        let nodeID = nodes[0].id
        var saveRequested = false
        engine.onRequestSave = { _ in saveRequested = true }

        engine.updateMiniAppPublishMetadata(
            nodes: &nodes,
            id: nodeID,
            publishURL: "https://demo.vercel.app",
            githubRepoOwner: "builder",
            githubRepoName: "caocap-app-abc123",
            githubRepoId: 99,
            isPrivate: false
        )

        XCTAssertTrue(saveRequested)
        XCTAssertEqual(nodes[0].miniApp?.publishURL, "https://demo.vercel.app")
        XCTAssertEqual(nodes[0].miniApp?.githubRepoOwner, "builder")
        XCTAssertEqual(nodes[0].miniApp?.githubRepoName, "caocap-app-abc123")
        XCTAssertEqual(nodes[0].miniApp?.githubRepoId, 99)
    }
}
