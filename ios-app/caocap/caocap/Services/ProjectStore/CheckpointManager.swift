import Foundation
import Observation
import OSLog
import SwiftUI

/// Manages historical checkpoints for a project.
@Observable
@MainActor
final class CheckpointManager {
    var history: [SnapshotMetadata] = []
    
    private let persistence: ProjectPersistenceService
    private let logger = Logger(subsystem: "com.caocap.app", category: "Checkpoints")
    
    init(persistence: ProjectPersistenceService) {
        self.persistence = persistence
    }
    
    /// Loads the history from disk.
    func loadHistory(for fileName: String) {
        history = persistence.listSnapshots(for: fileName)
    }
    
    /// Creates a durable checkpoint of the current project state.
    func createCheckpoint(snapshot: ProjectSnapshot, fileName: String, label: String = "Manual Checkpoint") {
        Task(priority: .background) { [weak self] in
            do {
                guard let self = self else { return }
                let metadata = try self.persistence.saveSnapshot(snapshot, fileName: fileName, label: label)
                await MainActor.run {
                    self.history.insert(metadata, at: 0)
                    // Keep history to last 20 for now
                    if self.history.count > 20 {
                        self.history.removeLast()
                    }
                }
            } catch {
                self?.logger.error("Failed to create checkpoint: \(error.localizedDescription)")
            }
        }
    }
    
    /// Creates an automatic checkpoint before significant mutations (e.g. Co-Captain edits).
    func createAutoCheckpoint(snapshot: ProjectSnapshot, fileName: String, label: String = "Pre-AI Snapshot") {
        createCheckpoint(snapshot: snapshot, fileName: fileName, label: label)
    }
    
    /// Restores the project graph from a historical checkpoint and returns it.
    /// The caller is responsible for applying it and saving.
    func restore(from metadata: SnapshotMetadata, fileName: String) -> ProjectSnapshot? {
        do {
            return try persistence.loadSnapshot(metadata: metadata, for: fileName)
        } catch {
            logger.error("Failed to load snapshot for restore: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Deletes a historical checkpoint from disk and local state.
    func deleteCheckpoint(metadata: SnapshotMetadata, fileName: String) {
        Task(priority: .background) { [weak self] in
            do {
                guard let self = self else { return }
                try self.persistence.deleteSnapshot(metadata: metadata, for: fileName)
                await MainActor.run {
                    self.history.removeAll(where: { $0.id == metadata.id })
                }
            } catch {
                self?.logger.error("Failed to delete checkpoint: \(error.localizedDescription)")
            }
        }
    }
}
