import XCTest
@testable import caocap

@MainActor
final class CheckpointManagerTests: XCTestCase {
    var persistence: ProjectPersistenceService!
    var manager: CheckpointManager!
    let fileName = "test_checkpoints.json"
    
    override func setUp() async throws {
        persistence = ProjectPersistenceService()
        manager = CheckpointManager(persistence: persistence)
        
        let fileURL = persistence.fileURL(for: fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        let snapshotsDir = fileURL.deletingPathExtension().appendingPathExtension("snapshots")
        if FileManager.default.fileExists(atPath: snapshotsDir.path) {
            try FileManager.default.removeItem(at: snapshotsDir)
        }
    }
    
    override func tearDown() async throws {
        let fileURL = persistence.fileURL(for: fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        let snapshotsDir = fileURL.deletingPathExtension().appendingPathExtension("snapshots")
        if FileManager.default.fileExists(atPath: snapshotsDir.path) {
            try FileManager.default.removeItem(at: snapshotsDir)
        }
    }
    
    func testCreateCheckpoint() async throws {
        let snapshot = ProjectSnapshot(schemaVersion: ProjectPersistenceService.currentSchemaVersion, projectName: "Test", nodes: [], viewportOffset: .zero, viewportScale: 1.0)
        manager.createCheckpoint(snapshot: snapshot, fileName: fileName, label: "Initial")
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        XCTAssertEqual(manager.history.count, 1)
        XCTAssertEqual(manager.history.first?.label, "Initial")
    }
    
    func testDeleteCheckpoint() async throws {
        let snapshot = ProjectSnapshot(schemaVersion: ProjectPersistenceService.currentSchemaVersion, projectName: "Test", nodes: [], viewportOffset: .zero, viewportScale: 1.0)
        manager.createCheckpoint(snapshot: snapshot, fileName: fileName, label: "To Delete")
        
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(manager.history.count, 1)
        
        let metadata = manager.history[0]
        manager.deleteCheckpoint(metadata: metadata, fileName: fileName)
        
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertTrue(manager.history.isEmpty)
    }
    
    func testRestoreCheckpoint() async throws {
        let snapshot = ProjectSnapshot(schemaVersion: ProjectPersistenceService.currentSchemaVersion, projectName: "Test", nodes: [SpatialNode(type: .code, position: .zero, title: "Code")], viewportOffset: .zero, viewportScale: 1.0)
        manager.createCheckpoint(snapshot: snapshot, fileName: fileName, label: "To Restore")
        
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(manager.history.count, 1)
        
        let metadata = manager.history[0]
        let restored = manager.restore(from: metadata, fileName: fileName)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.nodes.count, 1)
    }
    
    func testHistoryCap() async throws {
        let snapshot = ProjectSnapshot(schemaVersion: ProjectPersistenceService.currentSchemaVersion, projectName: "Test", nodes: [], viewportOffset: .zero, viewportScale: 1.0)
        
        for i in 1...25 {
            manager.createCheckpoint(snapshot: snapshot, fileName: fileName, label: "Label \(i)")
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        XCTAssertEqual(manager.history.count, 20)
        XCTAssertEqual(manager.history.first?.label, "Label 25")
    }

    func testOldSchemaCheckpointExcludedFromHistory() async throws {
        let directory = persistence.snapshotsDirectory(for: fileName)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let id = UUID()
        let v1Snapshot = ProjectSnapshot(schemaVersion: 1, projectName: "Old", nodes: [], viewportOffset: .zero, viewportScale: 1.0, checkpointLabel: "Old Schema")
        let url = directory.appendingPathComponent("\(id.uuidString).json")
        let data = try JSONEncoder().encode(v1Snapshot)
        try data.write(to: url)

        manager.loadHistory(for: fileName)
        XCTAssertTrue(manager.history.isEmpty)
    }

    func testLoadSnapshotThrowsForOldSchema() throws {
        let directory = persistence.snapshotsDirectory(for: fileName)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let id = UUID()
        let fileNameOnDisk = "\(id.uuidString).json"
        let v1Snapshot = ProjectSnapshot(schemaVersion: 1, projectName: "Old", nodes: [], viewportOffset: .zero, viewportScale: 1.0)
        let url = directory.appendingPathComponent(fileNameOnDisk)
        try JSONEncoder().encode(v1Snapshot).write(to: url)

        let metadata = SnapshotMetadata(id: id, label: "Old", fileName: fileNameOnDisk)
        XCTAssertThrowsError(try persistence.loadSnapshot(metadata: metadata, for: fileName)) { error in
            guard case ProjectPersistenceError.unsupportedSchemaVersion(let version, let current) = error else {
                return XCTFail("Expected unsupportedSchemaVersion, got \(error)")
            }
            XCTAssertEqual(version, 1)
            XCTAssertEqual(current, ProjectPersistenceService.currentSchemaVersion)
        }
    }
}
