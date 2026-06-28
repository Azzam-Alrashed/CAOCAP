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
            "viewportOffset": {"width": 10, "height": 20},
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

        let fallbackNode = SpatialNode(type: .miniApp, position: .zero, title: "Mini-App", miniApp: MiniAppState(codeText: "<h1>Fallback</h1>"))
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

        let fallbackNode = SpatialNode(type: .miniApp, position: .zero, title: "Mini-App", miniApp: MiniAppState(codeText: "<h1>Fallback</h1>"))
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

        let fallbackNode = SpatialNode(type: .miniApp, position: .zero, title: "Mini-App", miniApp: MiniAppState(codeText: "<h1>Fallback</h1>"))
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
                SpatialNode(type: .miniApp, position: CGPoint(x: 12, y: 24), title: "Mini-App", miniApp: MiniAppState(codeText: "<h1>Hello</h1>"))
            ],
            viewportOffset: CGSize(width: 10, height: 20),
            viewportScale: 0.75
        )

        try persistence.save(snapshot, fileName: fileName)
        let loaded = try persistence.load(fileName: fileName)

        #expect(loaded == snapshot)
        #expect(loaded.schemaVersion == ProjectPersistenceService.currentSchemaVersion)
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

    @Test func curatedRootMigrationResetsRootOnceAndSeedsChildCanvases() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let persistence = ProjectPersistenceService(baseDirectory: tempDirectory)
        let defaults = try #require(UserDefaults(suiteName: "CuratedRootCanvasMigrationTests.reset"))
        defer { defaults.removePersistentDomain(forName: "CuratedRootCanvasMigrationTests.reset") }
        defaults.removePersistentDomain(forName: "CuratedRootCanvasMigrationTests.reset")

        try persistence.save(
            ProjectSnapshot(
                projectName: "Old Root",
                nodes: [SpatialNode(position: .zero, title: "Old Node")],
                viewportOffset: CGSize(width: 42, height: 24),
                viewportScale: 1
            ),
            fileName: CanvasFileNaming.rootFileName
        )

        CuratedRootCanvasMigration.runIfNeeded(persistence: persistence, defaults: defaults)

        let migratedRoot = try persistence.load(fileName: CanvasFileNaming.rootFileName)
        #expect(migratedRoot.nodes == RootCanvasProvider.nodes)
        #expect(migratedRoot.viewportOffset == .zero)
        #expect(migratedRoot.viewportScale == 0.5)
        #expect(persistence.projectExists(fileName: RootCanvasProvider.tutorialFileName))
        #expect(persistence.projectExists(fileName: RootCanvasProvider.pacManFileName))

        let customizedRoot = ProjectSnapshot(
            projectName: "Customized",
            nodes: [SpatialNode(position: .zero, title: "My Node")],
            viewportOffset: .zero,
            viewportScale: 1
        )
        try persistence.save(customizedRoot, fileName: CanvasFileNaming.rootFileName)
        CuratedRootCanvasMigration.runIfNeeded(persistence: persistence, defaults: defaults)
        let preservedRoot = try persistence.load(fileName: CanvasFileNaming.rootFileName)
        #expect(preservedRoot == customizedRoot)
    }

    @Test func curatedRootMigrationPreservesExistingChildCanvases() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let persistence = ProjectPersistenceService(baseDirectory: tempDirectory)
        let defaults = try #require(UserDefaults(suiteName: "CuratedRootCanvasMigrationTests.children"))
        defer { defaults.removePersistentDomain(forName: "CuratedRootCanvasMigrationTests.children") }
        defaults.removePersistentDomain(forName: "CuratedRootCanvasMigrationTests.children")

        let customizedPacMan = ProjectSnapshot(
            projectName: "Customized Pac-Man",
            nodes: [SpatialNode(position: .zero, title: "Keep Me")],
            viewportOffset: .zero,
            viewportScale: 1
        )
        try persistence.save(customizedPacMan, fileName: RootCanvasProvider.pacManFileName)

        CuratedRootCanvasMigration.runIfNeeded(persistence: persistence, defaults: defaults)

        let preservedPacMan = try persistence.load(fileName: RootCanvasProvider.pacManFileName)
        #expect(preservedPacMan == customizedPacMan)
    }

    @Test func activityMigrationAppendsBelowCustomizedRootWithoutMovingExistingNodes() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let persistence = ProjectPersistenceService(baseDirectory: tempDirectory)
        let suiteName = "CuratedRootCanvasMigrationTests.activity.custom"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.removePersistentDomain(forName: suiteName)

        let customNode = SpatialNode(
            position: CGPoint(x: 125, y: 700),
            title: "My Custom Root Node"
        )
        try persistence.save(
            ProjectSnapshot(
                projectName: "Root",
                nodes: [customNode],
                viewportOffset: .zero,
                viewportScale: 0.5
            ),
            fileName: CanvasFileNaming.rootFileName
        )
        defaults.set(true, forKey: CuratedRootCanvasMigration.migrationCompleteKey)
        defaults.set(true, forKey: CuratedRootCanvasMigration.verticalLayoutCompleteKey)

        CuratedRootCanvasMigration.runIfNeeded(persistence: persistence, defaults: defaults)
        CuratedRootCanvasMigration.runIfNeeded(persistence: persistence, defaults: defaults)

        let migrated = try persistence.load(fileName: CanvasFileNaming.rootFileName)
        let preserved = try #require(migrated.nodes.first(where: { $0.id == customNode.id }))
        let activity = try #require(migrated.nodes.first(where: {
            $0.id == RootCanvasProvider.activityNodeID
        }))

        #expect(preserved.position == customNode.position)
        #expect(activity.position == CGPoint(x: 0, y: 920))
        #expect(activity.isProtected)
        #expect(migrated.nodes.filter { $0.id == RootCanvasProvider.activityNodeID }.count == 1)
    }

    @Test func curatedRootMigrationUpdatesLegacyConstellationToVerticalLayout() throws {
        let tempDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let persistence = ProjectPersistenceService(baseDirectory: tempDirectory)
        let defaults = try #require(UserDefaults(suiteName: "CuratedRootCanvasMigrationTests.vertical"))
        defer { defaults.removePersistentDomain(forName: "CuratedRootCanvasMigrationTests.vertical") }
        defaults.removePersistentDomain(forName: "CuratedRootCanvasMigrationTests.vertical")

        let legacyNodes = [
            SpatialNode(
                id: RootCanvasProvider.tutorialNodeID,
                type: .subCanvas,
                position: .zero,
                title: "Tutorial",
                subtitle: "Learn CAOCAP by using it",
                icon: "graduationcap.fill",
                theme: .green,
                linkedCanvasFileName: RootCanvasProvider.tutorialFileName
            ),
            SpatialNode(
                id: RootCanvasProvider.proNodeID,
                position: CGPoint(x: 0, y: -300),
                title: "Pro Subscription",
                subtitle: "Unlock CoCaptain & Premium Features",
                icon: "crown.fill",
                theme: .indigo,
                action: .proSubscription
            ),
            SpatialNode(
                id: RootCanvasProvider.profileNodeID,
                position: CGPoint(x: -250, y: -150),
                title: "Profile",
                subtitle: "Account & Preferences",
                icon: "person.crop.circle.fill",
                theme: .blue,
                action: .openProfile
            ),
            SpatialNode(
                id: RootCanvasProvider.pacManNodeID,
                type: .subCanvas,
                position: CGPoint(x: 250, y: -150),
                title: "Pac-Man",
                subtitle: "A mobile-ready Mini-App",
                icon: "gamecontroller.fill",
                theme: .purple,
                linkedCanvasFileName: RootCanvasProvider.pacManFileName
            ),
            SpatialNode(
                id: RootCanvasProvider.settingsNodeID,
                position: CGPoint(x: -250, y: 150),
                title: "Settings",
                subtitle: "App Tools & Config",
                icon: "gearshape.fill",
                theme: .orange,
                action: .openSettings
            )
        ]

        try persistence.save(
            ProjectSnapshot(projectName: "Root", nodes: legacyNodes, viewportOffset: .zero, viewportScale: 0.5),
            fileName: CanvasFileNaming.rootFileName
        )
        defaults.set(true, forKey: CuratedRootCanvasMigration.migrationCompleteKey)

        CuratedRootCanvasMigration.runIfNeeded(persistence: persistence, defaults: defaults)

        let migratedRoot = try persistence.load(fileName: CanvasFileNaming.rootFileName)
        let positionsByID = Dictionary(uniqueKeysWithValues: migratedRoot.nodes.map { ($0.id, $0.position) })
        let expectedPositions = Dictionary(uniqueKeysWithValues: RootCanvasProvider.nodes.map { ($0.id, $0.position) })
        #expect(positionsByID == expectedPositions)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("caocap-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
