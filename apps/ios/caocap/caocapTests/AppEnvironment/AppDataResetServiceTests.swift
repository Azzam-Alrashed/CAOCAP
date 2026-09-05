import Foundation
import Testing
@testable import caocap

struct AppDataResetServiceTests {
    @Test func eraseLocalDataRemovesWorkspaceContainerFilesAndDefaults() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-reset-\(UUID().uuidString)", isDirectory: true)
        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        let documents = root.appendingPathComponent("documents", isDirectory: true)
        let caches = root.appendingPathComponent("caches", isDirectory: true)
        let defaultsName = "AppDataResetServiceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
            try? FileManager.default.removeItem(at: root)
        }

        for directory in [workspace, documents, caches] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("saved".utf8).write(to: directory.appendingPathComponent("saved.data"))
        }
        defaults.set(true, forKey: "completed")

        try await AppDataResetService.eraseLocalData(
            persistence: ProjectPersistenceService(baseDirectory: workspace),
            defaults: defaults,
            defaultsDomain: defaultsName,
            containerDirectories: [documents, caches]
        )

        let remainingDocuments = try FileManager.default.contentsOfDirectory(atPath: documents.path)
        let remainingCaches = try FileManager.default.contentsOfDirectory(atPath: caches.path)
        #expect(!FileManager.default.fileExists(atPath: workspace.path))
        #expect(remainingDocuments.isEmpty)
        #expect(remainingCaches.isEmpty)
        #expect(defaults.object(forKey: "completed") == nil)
    }
}
