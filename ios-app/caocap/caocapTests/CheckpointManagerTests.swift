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
        let snapshot = ProjectSnapshot(schemaVersion: 1, projectName: "Test", nodes: [], viewportOffset: .zero, viewportScale: 1.0)
        manager.createCheckpoint(snapshot: snapshot, fileName: fileName, label: "Initial")
        
        // Wait for background task to complete
        try await Task.sleep(nanoseconds: 500_000_000)
        
        XCTAssertEqual(manager.history.count, 1)
        XCTAssertEqual(manager.history.first?.label, "Initial")
    }
    
    func testDeleteCheckpoint() async throws {
        let snapshot = ProjectSnapshot(schemaVersion: 1, projectName: "Test", nodes: [], viewportOffset: .zero, viewportScale: 1.0)
        manager.createCheckpoint(snapshot: snapshot, fileName: fileName, label: "To Delete")
        
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(manager.history.count, 1)
        
        let metadata = manager.history[0]
        manager.deleteCheckpoint(metadata: metadata, fileName: fileName)
        
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertTrue(manager.history.isEmpty)
    }
    
    func testRestoreCheckpoint() async throws {
        let snapshot = ProjectSnapshot(schemaVersion: 1, projectName: "Test", nodes: [SpatialNode(position: .zero, title: "HTML")], viewportOffset: .zero, viewportScale: 1.0)
        manager.createCheckpoint(snapshot: snapshot, fileName: fileName, label: "To Restore")
        
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(manager.history.count, 1)
        
        let metadata = manager.history[0]
        let restored = manager.restore(from: metadata, fileName: fileName)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.nodes.count, 1)
    }
    
    func testHistoryCap() async throws {
        let snapshot = ProjectSnapshot(schemaVersion: 1, projectName: "Test", nodes: [], viewportOffset: .zero, viewportScale: 1.0)
        
        for i in 1...25 {
            manager.createCheckpoint(snapshot: snapshot, fileName: fileName, label: "Label \(i)")
            try await Task.sleep(nanoseconds: 50_000_000) // Small delay to prevent same timestamp overwrites
        }
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // wait to ensure all background saves complete
        
        XCTAssertEqual(manager.history.count, 20)
        // Last one inserted should be at index 0
        XCTAssertEqual(manager.history.first?.label, "Label 25")
    }
}
