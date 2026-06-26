import Foundation
import OSLog

/// One-time migration from the project-manager era to the canvas workspace model.
enum CanvasWorkspaceMigration {
    private static let migrationCompleteKey = "canvasWorkspaceMigration_v1_complete"
    private static let lastCanvasFileNameKey = "lastCanvasFileName"
    private static let legacyLastProjectFileNameKey = "lastProjectFileName"
    private static let logger = Logger(subsystem: "com.caocap.app", category: "CanvasWorkspaceMigration")

    /// Runs all migration steps, then sets a `UserDefaults` flag so subsequent
    /// launches skip this work entirely. Safe to call on every app launch.
    static func runIfNeeded(persistence: ProjectPersistenceService = ProjectPersistenceService()) {
        // Short-circuit if this migration has already been applied on this device.
        guard !UserDefaults.standard.bool(forKey: migrationCompleteKey) else { return }

        let directory = persistence.workspaceDirectory()
        renameLegacyProjectFiles(in: directory)
        stripRootShortcutActions(persistence: persistence)
        rewriteLinkedCanvasFileNames(persistence: persistence, in: directory)
        migrateLastOpenedFileName()

        UserDefaults.standard.set(true, forKey: migrationCompleteKey)
        logger.info("Canvas workspace migration completed.")
    }

    /// Renames any `project_*.json` files in the workspace directory to the
    /// canonical `canvas_*.json` naming scheme. Skips files where the target
    /// already exists to avoid overwriting data.
    private static func renameLegacyProjectFiles(in directory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }

        for url in files where url.lastPathComponent.hasPrefix(CanvasFileNaming.legacyProjectPrefix)
            && url.pathExtension == "json" {
            let legacyName = url.lastPathComponent
            let canvasName = CanvasFileNaming.migrateLegacyFileName(legacyName)
            let destination = directory.appendingPathComponent(canvasName)
            guard !FileManager.default.fileExists(atPath: destination.path) else { continue }
            do {
                try FileManager.default.moveItem(at: url, to: destination)
                logger.info("Renamed \(legacyName) to \(canvasName)")
            } catch {
                logger.error("Failed to rename \(legacyName): \(error.localizedDescription)")
            }
        }
    }

    /// Removes any `NodeAction` values that were stored on sub-canvas nodes in
    /// the root canvas file. Actions were moved out of nodes in a previous refactor
    /// and leftover values can cause unexpected behaviour.
    private static func stripRootShortcutActions(persistence: ProjectPersistenceService) {
        let rootFileName = CanvasFileNaming.rootFileName
        guard persistence.projectExists(fileName: rootFileName) else { return }

        do {
            var snapshot = try persistence.load(fileName: rootFileName)
            var changed = false
            snapshot = ProjectSnapshot(
                schemaVersion: snapshot.schemaVersion,
                projectName: snapshot.projectName,
                nodes: snapshot.nodes.map { node in
                    guard node.action != nil else { return node }
                    changed = true
                    var updated = node
                    updated.action = nil
                    return updated
                },
                viewportOffset: snapshot.viewportOffset,
                viewportScale: snapshot.viewportScale,
                checkpointLabel: snapshot.checkpointLabel
            )
            if changed {
                try persistence.save(snapshot, fileName: rootFileName)
                logger.info("Stripped shortcut actions from \(rootFileName)")
            }
        } catch {
            logger.error("Failed to strip root shortcut actions: \(error.localizedDescription)")
        }
    }

    /// Updates `linkedCanvasFileName` references inside all canvas JSON files to
    /// use the canonical `canvas_*` prefix, replacing any surviving `project_*` values
    /// left over from before the rename step.
    private static func rewriteLinkedCanvasFileNames(
        persistence: ProjectPersistenceService,
        in directory: URL
    ) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }

        let canvasFiles = files
            .map(\.lastPathComponent)
            .filter { $0.hasSuffix(".json") && ($0 == CanvasFileNaming.rootFileName || $0.hasPrefix(CanvasFileNaming.canvasPrefix)) }

        for fileName in canvasFiles {
            do {
                var snapshot = try persistence.load(fileName: fileName)
                var changed = false
                let updatedNodes = snapshot.nodes.map { node -> SpatialNode in
                    guard let linked = node.linkedCanvasFileName,
                          linked.hasPrefix(CanvasFileNaming.legacyProjectPrefix) else {
                        return node
                    }
                    changed = true
                    var updated = node
                    updated.linkedCanvasFileName = CanvasFileNaming.migrateLegacyFileName(linked)
                    return updated
                }
                guard changed else { continue }
                snapshot = ProjectSnapshot(
                    schemaVersion: snapshot.schemaVersion,
                    projectName: snapshot.projectName,
                    nodes: updatedNodes,
                    viewportOffset: snapshot.viewportOffset,
                    viewportScale: snapshot.viewportScale,
                    checkpointLabel: snapshot.checkpointLabel
                )
                try persistence.save(snapshot, fileName: fileName)
                logger.info("Rewrote linked canvas file names in \(fileName)")
            } catch {
                logger.error("Failed to rewrite links in \(fileName): \(error.localizedDescription)")
            }
        }
    }

    /// Migrates the "last opened" file name stored in `UserDefaults` from the
    /// legacy `lastProjectFileName` key to the new `lastCanvasFileName` key,
    /// applying the `project_` → `canvas_` rename in the process.
    private static func migrateLastOpenedFileName() {
        let defaults = UserDefaults.standard
        if let legacy = defaults.string(forKey: legacyLastProjectFileNameKey) {
            let migrated = CanvasFileNaming.migrateLegacyFileName(legacy)
            defaults.set(migrated, forKey: lastCanvasFileNameKey)
            defaults.removeObject(forKey: legacyLastProjectFileNameKey)
        }
    }
}
