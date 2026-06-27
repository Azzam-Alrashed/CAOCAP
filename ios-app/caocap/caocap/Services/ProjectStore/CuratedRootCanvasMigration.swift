import Foundation
import OSLog

/// Installs the launch-ready root constellation once while leaving subsequent
/// user edits to the root and curated child canvases untouched.
enum CuratedRootCanvasMigration {
    static let migrationCompleteKey = "curatedRootCanvas_v1_complete"
    static let verticalLayoutCompleteKey = "curatedRootCanvas_v2_vertical_layout_complete"
    private static let logger = Logger(subsystem: "com.caocap.app", category: "CuratedRootCanvasMigration")

    static func runIfNeeded(
        persistence: ProjectPersistenceService = ProjectPersistenceService(),
        defaults: UserDefaults = .standard
    ) {
        if !defaults.bool(forKey: migrationCompleteKey) {
            do {
                try seedIfMissing(
                    TutorialCanvasProvider.snapshot,
                    fileName: RootCanvasProvider.tutorialFileName,
                    persistence: persistence
                )
                try seedIfMissing(
                    PacManCanvasProvider.snapshot,
                    fileName: RootCanvasProvider.pacManFileName,
                    persistence: persistence
                )

                // This release intentionally replaces the old home workspace once.
                try persistence.save(RootCanvasProvider.snapshot, fileName: CanvasFileNaming.rootFileName)
                defaults.set(true, forKey: migrationCompleteKey)
                logger.info("Installed the curated root canvas.")
            } catch {
                logger.error("Failed to install the curated root canvas: \(error.localizedDescription)")
            }
        }

        guard !defaults.bool(forKey: verticalLayoutCompleteKey) else { return }

        do {
            try refreshVerticalRootLayout(persistence: persistence)
            defaults.set(true, forKey: verticalLayoutCompleteKey)
            logger.info("Updated the curated root canvas to the vertical layout.")
        } catch {
            logger.error("Failed to update the curated root canvas layout: \(error.localizedDescription)")
        }
    }

    private static func refreshVerticalRootLayout(persistence: ProjectPersistenceService) throws {
        let rootFileName = CanvasFileNaming.rootFileName
        guard persistence.projectExists(fileName: rootFileName) else { return }

        let snapshot = try persistence.load(fileName: rootFileName)
        let curatedIDs = Set(RootCanvasProvider.nodes.map(\.id))
        guard Set(snapshot.nodes.map(\.id)) == curatedIDs else { return }

        let positionsByID = Dictionary(
            uniqueKeysWithValues: RootCanvasProvider.nodes.map { ($0.id, $0.position) }
        )
        let updatedNodes = snapshot.nodes.map { node -> SpatialNode in
            var updated = node
            if let position = positionsByID[node.id] {
                updated.position = position
            }
            return updated
        }

        let updatedSnapshot = ProjectSnapshot(
            schemaVersion: snapshot.schemaVersion,
            projectName: snapshot.projectName,
            nodes: updatedNodes,
            viewportOffset: snapshot.viewportOffset,
            viewportScale: snapshot.viewportScale,
            checkpointLabel: snapshot.checkpointLabel
        )

        try persistence.save(updatedSnapshot, fileName: rootFileName)
    }

    private static func seedIfMissing(
        _ snapshot: ProjectSnapshot,
        fileName: String,
        persistence: ProjectPersistenceService
    ) throws {
        guard !persistence.projectExists(fileName: fileName) else { return }
        try persistence.save(snapshot, fileName: fileName)
    }
}
