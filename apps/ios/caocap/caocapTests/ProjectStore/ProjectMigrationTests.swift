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

        #expect(throws: ProjectPersistenceError.unsupportedSchemaVersion(nil, current: ProjectPersistenceService.currentSchemaVersion)) {
            try persistence.load(fileName: fileName)
        }
    }

    @MainActor
    @Test func loadingCurrentVersionSucceeds() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let persistence = ProjectPersistenceService(baseDirectory: tempDirectory)
        let fileName = "v4.json"
        let v4JSON = """
        {
            "schemaVersion": 4,
            "projectName": "V4 Project",
            "viewportOffset": [10, 20],
            "viewportScale": 0.5,
            "nodes": []
        }
        """

        try v4JSON.data(using: .utf8)!.write(to: persistence.fileURL(for: fileName))

        let snapshot = try persistence.load(fileName: fileName)

        #expect(snapshot.schemaVersion == ProjectPersistenceService.currentSchemaVersion)
        #expect(snapshot.projectName == "V4 Project")
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

        #expect(throws: ProjectPersistenceError.unsupportedSchemaVersion(1, current: ProjectPersistenceService.currentSchemaVersion)) {
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

        #expect(throws: ProjectPersistenceError.unsupportedSchemaVersion(99, current: ProjectPersistenceService.currentSchemaVersion)) {
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

        let fallbackNode = SpatialNode(type: .miniApp, position: .zero, title: "Mini-App")
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

        let fallbackNode = SpatialNode(type: .miniApp, position: .zero, title: "Mini-App")
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

        let fallbackNode = SpatialNode(type: .miniApp, position: .zero, title: "Mini-App")
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
                SpatialNode(type: .standard, position: CGPoint(x: 12, y: 24), title: "Card")
            ],
            viewportOffset: CGSize(width: 10, height: 20),
            viewportScale: 0.75
        )

        try persistence.save(snapshot, fileName: fileName)
        let loaded = try persistence.load(fileName: fileName)

        #expect(loaded.projectName == snapshot.projectName)
        #expect(loaded.nodes.count == 1)
        #expect(loaded.nodes[0].type == .standard)
        #expect(loaded.nodes[0].title == "Card")
        #expect(loaded.nodes[0].position == CGPoint(x: 12, y: 24))
        #expect(loaded.viewportScale == 0.75)
        #expect(loaded.schemaVersion == ProjectPersistenceService.currentSchemaVersion)

        let savedJSON = String(data: try Data(contentsOf: persistence.fileURL(for: fileName)), encoding: .utf8) ?? ""
        #expect(!savedJSON.contains("\"miniApp\""))
        #expect(!savedJSON.contains("srsText"))
        #expect(!savedJSON.contains("codeText"))
    }

    @Test func leftoverMiniAppNodeDecodesAsOrdinaryCard() throws {
        let nodeID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let json = """
        {
            "id": "\(nodeID.uuidString)",
            "type": "miniApp",
            "position": [12, 24],
            "title": "Hello World",
            "theme": "blue",
            "miniApp": {
                "srsText": "# Intent",
                "srsReadinessState": "empty",
                "codeText": "<h1>Hello</h1>",
                "firebaseConfigText": ""
            }
        }
        """

        let decoded = try JSONDecoder().decode(SpatialNode.self, from: Data(json.utf8))

        #expect(decoded.id == nodeID)
        #expect(decoded.type == .standard)
        #expect(decoded.title == "Hello World")
        #expect(decoded.position == CGPoint(x: 12, y: 24))

        let encoded = try JSONEncoder().encode(decoded)
        let encodedObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(encodedObject["type"] as? String == "standard")
        #expect(encodedObject["miniApp"] == nil)
        #expect(encodedObject["title"] as? String == "Hello World")
    }

    @Test func legacyNodeActionStringDecodesToNil() throws {
        let original = SpatialNode(type: .standard, position: .zero, title: "Launcher", action: nil)
        var data = try JSONEncoder().encode(original)
        var jsonObject = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        jsonObject["action"] = "createNewProject"
        data = try JSONSerialization.data(withJSONObject: jsonObject)
        let decoded = try JSONDecoder().decode(SpatialNode.self, from: data)
        #expect(decoded.action == nil)
    }

    @Test func canvasFileNamingMigratesLegacyFileNames() {
        #expect(CanvasFileNaming.migrateLegacyFileName("project_abc12345.json") == "canvas_abc12345.json")
        #expect(CanvasFileNaming.migrateLegacyFileName("canvas_abc12345.json") == "canvas_abc12345.json")
    }

    @Test func canvasFileNamingResolvesLegacyFallback() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let persistence = ProjectPersistenceService(baseDirectory: tempDirectory)
        let legacy = "project_deadbeef.json"
        try persistence.save(
            ProjectSnapshot(projectName: "Legacy", nodes: [], viewportOffset: .zero, viewportScale: 1.0),
            fileName: legacy
        )

        let resolved = CanvasFileNaming.resolveExistingFileName("canvas_deadbeef.json", persistence: persistence)
        #expect(resolved == legacy)
    }

    @MainActor
    @Test func canvasWorkspaceMigrationRenamesFilesAndRewritesLinks() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let persistence = ProjectPersistenceService(baseDirectory: tempDirectory)
        let migrationKey = "canvasWorkspaceMigration_v1_complete"
        defer { UserDefaults.standard.removeObject(forKey: migrationKey) }
        UserDefaults.standard.removeObject(forKey: migrationKey)

        let legacyLinked = "project_abc12345.json"
        let subCanvasNode = SpatialNode(
            type: .subCanvas,
            position: .zero,
            title: "Child",
            linkedCanvasFileName: legacyLinked
        )
        let launcher = SpatialNode(type: .standard, position: .zero, title: "Settings", action: .openSettings)
        let rootSnapshot = ProjectSnapshot(
            projectName: "Root",
            nodes: [subCanvasNode, launcher],
            viewportOffset: .zero,
            viewportScale: 1.0
        )
        try persistence.save(rootSnapshot, fileName: CanvasFileNaming.rootFileName)
        try persistence.save(
            ProjectSnapshot(projectName: "Child", nodes: [], viewportOffset: .zero, viewportScale: 1.0),
            fileName: legacyLinked
        )

        #expect(persistence.projectExists(fileName: legacyLinked))
        #expect(!persistence.projectExists(fileName: "canvas_abc12345.json"))

        CanvasWorkspaceMigration.runIfNeeded(persistence: persistence)

        #expect(!persistence.projectExists(fileName: legacyLinked))
        #expect(persistence.projectExists(fileName: "canvas_abc12345.json"))

        let root = try persistence.load(fileName: CanvasFileNaming.rootFileName)
        #expect(root.nodes.first(where: { $0.title == "Child" })?.linkedCanvasFileName == "canvas_abc12345.json")
        #expect(root.nodes.first(where: { $0.title == "Settings" })?.action == .openSettings)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("caocap-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
