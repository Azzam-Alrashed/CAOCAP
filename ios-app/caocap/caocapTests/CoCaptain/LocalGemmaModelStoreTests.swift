import Foundation
import Testing
@testable import caocap

struct LocalGemmaModelStoreTests {
    @Test func incompleteModelIsNotReady() throws {
        let fixture = try makeFixture(minimumValidBytes: 8)
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        try FileManager.default.createDirectory(
            at: fixture.store.directory,
            withIntermediateDirectories: true
        )
        try Data(repeating: 0, count: 7).write(to: fixture.store.modelURL)

        let inspection = fixture.store.inspect()

        #expect(!inspection.isReady)
        #expect(inspection.size == 7)
    }

    @Test func completeModelIsReadyAndReportsSize() throws {
        let fixture = try makeFixture(minimumValidBytes: 8)
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        try FileManager.default.createDirectory(
            at: fixture.store.directory,
            withIntermediateDirectories: true
        )
        try Data(repeating: 0, count: 8).write(to: fixture.store.modelURL)

        let inspection = fixture.store.inspect()

        #expect(inspection.isReady)
        #expect(inspection.size == 8)
    }

    @Test func removingModelAlsoRemovesPartialDownload() throws {
        let fixture = try makeFixture(minimumValidBytes: 1)
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        try FileManager.default.createDirectory(
            at: fixture.store.directory,
            withIntermediateDirectories: true
        )
        try Data([0]).write(to: fixture.store.modelURL)
        try Data([0]).write(to: fixture.store.partialDownloadURL)

        try fixture.store.removeModel()

        #expect(!FileManager.default.fileExists(atPath: fixture.store.modelURL.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.store.partialDownloadURL.path))
    }

    private func makeFixture(
        minimumValidBytes: Int64
    ) throws -> (root: URL, store: LocalGemmaModelStore) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalGemmaModelStoreTests-\(UUID().uuidString)", isDirectory: true)
        return (
            root,
            LocalGemmaModelStore(
                directory: root.appendingPathComponent("Gemma", isDirectory: true),
                minimumValidModelBytes: minimumValidBytes
            )
        )
    }
}
