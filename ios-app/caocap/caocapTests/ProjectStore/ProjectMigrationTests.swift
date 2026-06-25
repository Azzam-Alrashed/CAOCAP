import CoreGraphics
import Foundation
import Testing
@testable import caocap

struct ProjectMigrationTests {

    @MainActor
    @Test func loadThrowsForMissingSchemaVersion() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let persistence = ProjectPersistenceService(baseDirectory: tempDirectory)
        let fileName = "legacy.json"
        let legacyJSON = """
        {
            "projectName": "Legacy Project",
            "viewportOffset": {"width": 0, "height": 0},
            "viewportScale": 1.0,
            "nodes": []
        }
        """

        try legacyJSON.data(using: .utf8)!.write(to: persistence.fileURL(for: fileName))

        #expect(throws: ProjectPersistenceError.unsupportedSchemaVersion(nil, current: 3)) {
            try persistence.load(fileName: fileName)
        }
    }

    @MainActor
    @Test func loadingCurrentVersionSucceeds() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let persistence = ProjectPersistenceService(baseDirectory: tempDirectory)
        let fileName = "v3.json"
        let v3JSON = """
        {
            "schemaVersion": 3,
            "projectName": "V3 Project",
            "viewportOffset": {"width": 10, "height": 20},
            "viewportScale": 0.5,
            "nodes": []
        }
        """

        try v3JSON.data(using: .utf8)!.write(to: persistence.fileURL(for: fileName))

        let snapshot = try persistence.load(fileName: fileName)

        #expect(snapshot.schemaVersion == 3)
        #expect(snapshot.projectName == "V3 Project")
        #expect(snapshot.viewportScale == 0.5)
    }

    @MainActor
    @Test func loadThrowsForOldSchemaVersion() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let persistence = ProjectPersistenceService(baseDirectory: tempDirectory)
        let fileName = "v1.json"
        let v1JSON = """
        {
            "schemaVersion": 1,
            "projectName": "V1 Project",
            "viewportOffset": {"width": 0, "height": 0},
            "viewportScale": 1.0,
            "nodes": []
        }
        """

        try v1JSON.data(using: .utf8)!.write(to: persistence.fileURL(for: fileName))

        #expect(throws: ProjectPersistenceError.unsupportedSchemaVersion(1, current: 3)) {
            try persistence.load(fileName: fileName)
        }
    }

    @MainActor
    @Test func loadingNewerVersionAbortsToPreventDataLoss() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let persistence = ProjectPersistenceService(baseDirectory: tempDirectory)
        let fileName = "future.json"
        let v99JSON = """
        {
            "schemaVersion": 99,
            "projectName": "Future Project",
            "viewportOffset": {"width": 0, "height": 0},
            "viewportScale": 1.0,
            "nodes": []
        }
        """

        try v99JSON.data(using: .utf8)!.write(to: persistence.fileURL(for: fileName))

        #expect(throws: ProjectPersistenceError.unsupportedSchemaVersion(99, current: 3)) {
            try persistence.load(fileName: fileName)
        }
    }

    @MainActor
    @Test func storeFallsBackToInitialNodesWhenProjectFileIsCorrupted() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let persistence = ProjectPersistenceService(baseDirectory: tempDirectory)
        let fileName = "corrupted.json"
        try Data("{not-json}".utf8).write(to: persistence.fileURL(for: fileName))

        let fallbackNode = SpatialNode(type: .code, position: .zero, title: "Code", textContent: "<h1>Fallback</h1>")
        let store = ProjectStore(
            fileName: fileName,
            projectName: "Fallback Project",
            initialNodes: [fallbackNode],
            persistence: persistence
        )

        #expect(store.nodes == [fallbackNode])
        #expect(store.projectName == "Fallback Project")
    }

    @MainActor
    @Test func storeFallsBackForUnsupportedSchemaWithoutSaving() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let persistence = ProjectPersistenceService(baseDirectory: tempDirectory)
        let fileName = "v1-on-disk.json"
        let v1JSON = """
        {
            "schemaVersion": 1,
            "projectName": "V1 Project",
            "viewportOffset": {"width": 0, "height": 0},
            "viewportScale": 1.0,
            "nodes": []
        }
        """
        try v1JSON.data(using: .utf8)!.write(to: persistence.fileURL(for: fileName))

        let fallbackNode = SpatialNode(type: .code, position: .zero, title: "Code", textContent: "<h1>Fallback</h1>")
        _ = ProjectStore(
            fileName: fileName,
            projectName: "Fallback Project",
            initialNodes: [fallbackNode],
            persistence: persistence
        )

        let diskData = try Data(contentsOf: persistence.fileURL(for: fileName))
        let diskJSON = String(data: diskData, encoding: .utf8) ?? ""
        #expect(diskJSON.contains("\"schemaVersion\" : 1") || diskJSON.contains("\"schemaVersion\": 1"))
    }

    @MainActor
    @Test func storeFallsBackForMissingSchemaWithoutSaving() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let persistence = ProjectPersistenceService(baseDirectory: tempDirectory)
        let fileName = "missing-schema.json"
        let legacyJSON = """
        {
            "projectName": "Legacy Project",
            "viewportOffset": {"width": 0, "height": 0},
            "viewportScale": 1.0,
            "nodes": []
        }
        """
        try legacyJSON.data(using: .utf8)!.write(to: persistence.fileURL(for: fileName))

        let fallbackNode = SpatialNode(type: .code, position: .zero, title: "Code", textContent: "<h1>Fallback</h1>")
        _ = ProjectStore(
            fileName: fileName,
            projectName: "Fallback Project",
            initialNodes: [fallbackNode],
            persistence: persistence
        )

        let diskJSON = String(data: try Data(contentsOf: persistence.fileURL(for: fileName)), encoding: .utf8) ?? ""
        #expect(!diskJSON.contains("schemaVersion"))
    }

    @Test func persistenceSaveLoadRoundTrip() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let persistence = ProjectPersistenceService(baseDirectory: tempDirectory)
        let fileName = "roundtrip.json"
        let snapshot = ProjectSnapshot(
            projectName: "Round Trip",
            nodes: [
                SpatialNode(type: .code, position: CGPoint(x: 12, y: 24), title: "Code", textContent: "<h1>Hello</h1>")
            ],
            viewportOffset: CGSize(width: 10, height: 20),
            viewportScale: 0.75
        )

        try persistence.save(snapshot, fileName: fileName)
        let loaded = try persistence.load(fileName: fileName)

        #expect(loaded == snapshot)
        #expect(loaded.schemaVersion == ProjectPersistenceService.currentSchemaVersion)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("caocap-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
