import Foundation
import Testing
@testable import caocap

struct LocalGemmaModelManagerTests {
    @MainActor
    @Test func successfulDownloadPublishesProgressAndReadyState() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let manager = LocalGemmaModelManager(
            store: fixture.store,
            downloader: SuccessfulDownloader(),
            eligibility: supportedDevice
        )

        manager.downloadLocalModel()
        await waitUntil { !manager.isDownloadingLocalModel && manager.isLocalModelCached }

        #expect(manager.localModelDownloadProgress == 1)
        #expect(manager.localModelError == nil)
        #expect(FileManager.default.fileExists(atPath: fixture.store.modelURL.path))
    }

    @MainActor
    @Test func failedDownloadCanBeRetried() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let downloader = RetryDownloader()
        let manager = LocalGemmaModelManager(
            store: fixture.store,
            downloader: downloader,
            eligibility: supportedDevice
        )

        manager.downloadLocalModel()
        await waitUntil { !manager.isDownloadingLocalModel && manager.localModelError != nil }

        #expect(!manager.isLocalModelCached)

        manager.downloadLocalModel()
        await waitUntil { !manager.isDownloadingLocalModel && manager.isLocalModelCached }

        #expect(manager.localModelError == nil)
        let attemptCount = await downloader.attemptCount
        #expect(attemptCount == 2)
    }

    @MainActor
    @Test func deletingModelReturnsManagerToUnreadyState() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try FileManager.default.createDirectory(
            at: fixture.store.directory,
            withIntermediateDirectories: true
        )
        try Data([0]).write(to: fixture.store.modelURL)
        let engineCacheDirectory = fixture.root.appendingPathComponent("EngineCache", isDirectory: true)
        try FileManager.default.createDirectory(
            at: engineCacheDirectory,
            withIntermediateDirectories: true
        )
        try Data([0]).write(
            to: engineCacheDirectory.appendingPathComponent("compiled.cache")
        )
        let manager = LocalGemmaModelManager(
            store: fixture.store,
            downloader: SuccessfulDownloader(),
            eligibility: supportedDevice,
            engineCacheDirectory: engineCacheDirectory
        )

        await waitUntil { manager.isLocalModelCached }

        manager.clearLocalModelCache()
        await waitUntil { !manager.isLocalModelCached }

        #expect(!FileManager.default.fileExists(atPath: fixture.store.modelURL.path))
        #expect(!FileManager.default.fileExists(atPath: engineCacheDirectory.path))
    }

    @MainActor
    @Test func cancellingDownloadReturnsToIdleWithoutAnError() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let manager = LocalGemmaModelManager(
            store: fixture.store,
            downloader: CancellableDownloader(),
            eligibility: supportedDevice
        )

        manager.downloadLocalModel()
        #expect(manager.isDownloadingLocalModel)

        manager.cancelDownload()
        await waitUntil { !manager.isDownloadingLocalModel }

        #expect(manager.localModelError == nil)
        #expect(!manager.isLocalModelCached)
    }

    @MainActor
    @Test func insufficientStorageStopsBeforeDownloading() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let manager = LocalGemmaModelManager(
            store: fixture.store,
            downloader: SuccessfulDownloader(),
            eligibility: supportedDevice,
            availableCapacityProvider: { 0 }
        )

        manager.downloadLocalModel()
        await waitUntil {
            !manager.isDownloadingLocalModel && manager.localModelError != nil
        }

        #expect(manager.localModelError?.contains("3.5 GB") == true)
        #expect(!manager.isLocalModelCached)
        #expect(!FileManager.default.fileExists(atPath: fixture.store.modelURL.path))
    }

    @MainActor
    @Test func resettingOneScopeCancelsOnlyThatGeneration() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let probe = GenerationProbe()
        let nodeScope = CoCaptainAgentScope.node(UUID())
        let manager = LocalGemmaModelManager(
            store: fixture.store,
            downloader: SuccessfulDownloader(),
            eligibility: supportedDevice,
            streamProvider: { _, scope in
                AsyncThrowingStream { continuation in
                    Task { await probe.markStarted(scope) }
                    continuation.onTermination = { _ in
                        Task { await probe.markCancelled(scope) }
                    }
                }
            }
        )

        let projectTask = consume(manager.streamResponse(to: "project", scope: .project))
        let nodeTask = consume(manager.streamResponse(to: "node", scope: nodeScope))
        await waitUntilAsync {
            let projectStarted = await probe.didStart(.project)
            let nodeStarted = await probe.didStart(nodeScope)
            return projectStarted && nodeStarted
        }

        manager.resetChat(scope: .project)
        await waitUntilAsync { await probe.wasCancelled(.project) }

        #expect(await probe.wasCancelled(.project))
        #expect(!(await probe.wasCancelled(nodeScope)))

        projectTask.cancel()
        nodeTask.cancel()
        manager.resetChat(scope: nodeScope)
    }

    private var supportedDevice: LocalModelDeviceEligibility {
        LocalModelDeviceEligibility(family: .phone, hardwareIdentifier: "iPhone16,1")
    }

    private func makeFixture() throws -> (root: URL, store: LocalGemmaModelStore) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalGemmaModelManagerTests-\(UUID().uuidString)", isDirectory: true)
        return (
            root,
            LocalGemmaModelStore(
                directory: root.appendingPathComponent("Gemma", isDirectory: true),
                minimumValidModelBytes: 1
            )
        )
    }

    @MainActor
    private func waitUntil(
        _ condition: @MainActor () -> Bool
    ) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }

    private func waitUntilAsync(
        _ condition: @escaping @Sendable () async -> Bool
    ) async {
        for _ in 0..<200 {
            if await condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(await condition())
    }

    private func consume(
        _ stream: AsyncThrowingStream<String, Error>
    ) -> Task<Void, Never> {
        Task {
            do {
                for try await _ in stream {}
            } catch is CancellationError {
                // Expected when the scoped chat is reset.
            } catch {
                Issue.record("Unexpected stream failure: \(error)")
            }
        }
    }
}

private actor GenerationProbe {
    private var startedScopes: Set<CoCaptainAgentScope> = []
    private var cancelledScopes: Set<CoCaptainAgentScope> = []

    func markStarted(_ scope: CoCaptainAgentScope) {
        startedScopes.insert(scope)
    }

    func markCancelled(_ scope: CoCaptainAgentScope) {
        cancelledScopes.insert(scope)
    }

    func didStart(_ scope: CoCaptainAgentScope) -> Bool {
        startedScopes.contains(scope)
    }

    func wasCancelled(_ scope: CoCaptainAgentScope) -> Bool {
        cancelledScopes.contains(scope)
    }
}

private struct SuccessfulDownloader: LocalGemmaModelDownloading {
    func download(
        from sourceURL: URL,
        to store: LocalGemmaModelStore,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        progress(0.5)
        try FileManager.default.createDirectory(
            at: store.directory,
            withIntermediateDirectories: true
        )
        try Data([0]).write(to: store.modelURL)
        progress(1)
    }
}

private actor RetryDownloader: LocalGemmaModelDownloading {
    private(set) var attemptCount = 0

    func download(
        from sourceURL: URL,
        to store: LocalGemmaModelStore,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        attemptCount += 1
        guard attemptCount > 1 else {
            throw URLError(.networkConnectionLost)
        }

        try FileManager.default.createDirectory(
            at: store.directory,
            withIntermediateDirectories: true
        )
        try Data([0]).write(to: store.modelURL)
        progress(1)
    }
}

private struct CancellableDownloader: LocalGemmaModelDownloading {
    func download(
        from sourceURL: URL,
        to store: LocalGemmaModelStore,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        try await Task.sleep(for: .seconds(60))
    }
}
