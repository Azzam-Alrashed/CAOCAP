import Foundation
import OSLog

/// Installs the launch-ready root constellation once while leaving subsequent
/// user edits to the root and curated child canvases untouched.
enum CuratedRootCanvasMigration {
    static let migrationCompleteKey = "curatedRootCanvas_v1_complete"
    static let verticalLayoutCompleteKey = "curatedRootCanvas_v2_vertical_layout_complete"
    static let activityNodeCompleteKey = "curatedRootCanvas_v3_activity_complete"
    static let launchLayoutCompleteKey = "curatedRootCanvas_v4_launch_layout_complete"
    static let dailyNodeCompleteKey = "curatedRootCanvas_v5_daily_node_complete"
    static let constellationLayoutCompleteKey = "curatedRootCanvas_v6_constellation_layout_complete"
    static let xoGridLayoutCompleteKey = "curatedRootCanvas_v7_xo_grid_layout_complete"
    static let launchViewportScaleCompleteKey = "curatedRootCanvas_v8_launch_viewport_scale_complete"
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
                try seedIfMissing(
                    XOCanvasProvider.snapshot,
                    fileName: RootCanvasProvider.xoFileName,
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

        if !defaults.bool(forKey: verticalLayoutCompleteKey) {
            do {
                try refreshVerticalRootLayout(persistence: persistence)
                defaults.set(true, forKey: verticalLayoutCompleteKey)
                logger.info("Updated the curated root canvas to the vertical layout.")
            } catch {
                logger.error("Failed to update the curated root canvas layout: \(error.localizedDescription)")
            }
        }

        if !defaults.bool(forKey: activityNodeCompleteKey) {
            do {
                try installActivityNode(persistence: persistence)
                defaults.set(true, forKey: activityNodeCompleteKey)
                logger.info("Installed the root Activity node.")
            } catch {
                logger.error("Failed to install the root Activity node: \(error.localizedDescription)")
            }
        }

        if !defaults.bool(forKey: launchLayoutCompleteKey) {
            do {
                try refreshLaunchRootLayout(persistence: persistence)
                defaults.set(true, forKey: launchLayoutCompleteKey)
                logger.info("Updated the curated root canvas to the launch layout.")
            } catch {
                logger.error("Failed to update the curated root canvas launch layout: \(error.localizedDescription)")
            }
        }

        if !defaults.bool(forKey: dailyNodeCompleteKey) {
            do {
                try installDailyNode(persistence: persistence)
                defaults.set(true, forKey: dailyNodeCompleteKey)
                logger.info("Installed the root Daily node.")
            } catch {
                logger.error("Failed to install the root Daily node: \(error.localizedDescription)")
            }
        }

        if !defaults.bool(forKey: constellationLayoutCompleteKey) {
            do {
                try refreshConstellationRootLayout(persistence: persistence)
                defaults.set(true, forKey: constellationLayoutCompleteKey)
                logger.info("Updated the curated root canvas to the constellation layout.")
            } catch {
                logger.error("Failed to update the curated root canvas constellation layout: \(error.localizedDescription)")
            }
        }

        if !defaults.bool(forKey: xoGridLayoutCompleteKey) {
            do {
                try installXOGridLayout(persistence: persistence)
                defaults.set(true, forKey: xoGridLayoutCompleteKey)
                logger.info("Installed the root XO node and grid layout.")
            } catch {
                logger.error("Failed to install the root XO node and grid layout: \(error.localizedDescription)")
            }
        }

        if !defaults.bool(forKey: launchViewportScaleCompleteKey) {
            do {
                try refreshLaunchViewportScale(persistence: persistence)
                defaults.set(true, forKey: launchViewportScaleCompleteKey)
                logger.info("Updated the curated root canvas launch viewport scale.")
            } catch {
                logger.error("Failed to update the curated root canvas launch viewport scale: \(error.localizedDescription)")
            }
        }
    }

    private static func refreshVerticalRootLayout(persistence: ProjectPersistenceService) throws {
        let rootFileName = CanvasFileNaming.rootFileName
        guard persistence.projectExists(fileName: rootFileName) else { return }

        let snapshot = try persistence.load(fileName: rootFileName)
        let legacyNodes = RootCanvasProvider.nodes.filter { $0.id != RootCanvasProvider.activityNodeID }
        let curatedIDs = Set(legacyNodes.map(\.id))
        let constellationPositions: [UUID: CGPoint] = [
            RootCanvasProvider.tutorialNodeID: .zero,
            RootCanvasProvider.proNodeID: CGPoint(x: 0, y: -300),
            RootCanvasProvider.profileNodeID: CGPoint(x: -250, y: -150),
            RootCanvasProvider.pacManNodeID: CGPoint(x: 250, y: -150),
            RootCanvasProvider.settingsNodeID: CGPoint(x: -250, y: 150)
        ]
        let isLegacyConstellation =
            Set(snapshot.nodes.map(\.id)) == curatedIDs &&
            snapshot.nodes.allSatisfy { constellationPositions[$0.id] == $0.position }
        guard isLegacyConstellation else { return }

        let positionsByID = Dictionary(
            uniqueKeysWithValues: legacyNodes.enumerated().map { index, node in
                (node.id, RootCanvasProvider.verticalColumnPosition(index: index, count: legacyNodes.count))
            }
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

    private static func installActivityNode(persistence: ProjectPersistenceService) throws {
        let rootFileName = CanvasFileNaming.rootFileName
        guard persistence.projectExists(fileName: rootFileName) else { return }

        let snapshot = try persistence.load(fileName: rootFileName)
        guard !snapshot.nodes.contains(where: { $0.id == RootCanvasProvider.activityNodeID }),
              let activityNode = RootCanvasProvider.nodes.first(where: {
                  $0.id == RootCanvasProvider.activityNodeID
              }) else {
            return
        }

        let legacyNodes = RootCanvasProvider.nodes.filter { $0.id != RootCanvasProvider.activityNodeID }
        let legacyPositions = Dictionary(
            uniqueKeysWithValues: legacyNodes.enumerated().map { index, node in
                (node.id, RootCanvasProvider.verticalColumnPosition(index: index, count: legacyNodes.count))
            }
        )
        let hasCanonicalIDs = Set(snapshot.nodes.map(\.id)) == Set(legacyNodes.map(\.id))
        let hasCanonicalPositions = hasCanonicalIDs && snapshot.nodes.allSatisfy {
            legacyPositions[$0.id] == $0.position
        }

        var updatedNodes = snapshot.nodes
        if hasCanonicalPositions {
            let newPositions = Dictionary(
                uniqueKeysWithValues: RootCanvasProvider.nodes.map { ($0.id, $0.position) }
            )
            updatedNodes = updatedNodes.map { node in
                var updated = node
                if let position = newPositions[node.id] {
                    updated.position = position
                }
                return updated
            }
            updatedNodes.insert(activityNode, at: 0)
        } else {
            var appendedActivity = activityNode
            let lowestY = updatedNodes.map(\.position.y).max() ?? 0
            appendedActivity.position = CGPoint(x: 0, y: lowestY + 220)
            updatedNodes.append(appendedActivity)
        }

        try persistence.save(
            ProjectSnapshot(
                schemaVersion: snapshot.schemaVersion,
                projectName: snapshot.projectName,
                nodes: updatedNodes,
                viewportOffset: snapshot.viewportOffset,
                viewportScale: snapshot.viewportScale,
                checkpointLabel: snapshot.checkpointLabel
            ),
            fileName: rootFileName
        )
    }

    /// Reorders the curated six-node column and refreshes launch themes when the
    /// root still matches the prior activity-first vertical layout.
    private static func refreshLaunchRootLayout(persistence: ProjectPersistenceService) throws {
        let rootFileName = CanvasFileNaming.rootFileName
        guard persistence.projectExists(fileName: rootFileName) else { return }

        let snapshot = try persistence.load(fileName: rootFileName)
        let launchLayoutIDs = Set(launchLayoutNodeIDs())
        guard Set(snapshot.nodes.map(\.id)) == launchLayoutIDs else { return }

        let previousPositions = activityFirstVerticalPositions()
        let hasPreviousLayout = snapshot.nodes.allSatisfy {
            previousPositions[$0.id] == $0.position
        }
        guard hasPreviousLayout else { return }

        let canonicalByID = Dictionary(uniqueKeysWithValues: RootCanvasProvider.nodes.map { ($0.id, $0) })
        let updatedNodes = snapshot.nodes.map { node -> SpatialNode in
            guard let canonical = canonicalByID[node.id] else { return node }
            var updated = node
            updated.position = canonical.position
            updated.theme = canonical.theme
            return updated
        }
        let orderedNodes = RootCanvasProvider.nodes.compactMap { canonical in
            updatedNodes.first(where: { $0.id == canonical.id })
        }

        try persistence.save(
            ProjectSnapshot(
                schemaVersion: snapshot.schemaVersion,
                projectName: snapshot.projectName,
                nodes: orderedNodes,
                viewportOffset: snapshot.viewportOffset,
                viewportScale: snapshot.viewportScale,
                checkpointLabel: snapshot.checkpointLabel
            ),
            fileName: rootFileName
        )
    }

    private static func activityFirstVerticalPositions() -> [UUID: CGPoint] {
        let count = 6
        let orderedIDs = [
            RootCanvasProvider.activityNodeID,
            RootCanvasProvider.profileNodeID,
            RootCanvasProvider.proNodeID,
            RootCanvasProvider.settingsNodeID,
            RootCanvasProvider.tutorialNodeID,
            RootCanvasProvider.pacManNodeID
        ]
        return Dictionary(
            uniqueKeysWithValues: orderedIDs.enumerated().map { index, id in
                (id, RootCanvasProvider.verticalColumnPosition(index: index, count: count))
            }
        )
    }

    private static func launchLayoutNodeIDs() -> [UUID] {
        RootCanvasProvider.nodes
            .filter {
                $0.id != RootCanvasProvider.dailyNodeID &&
                    $0.id != RootCanvasProvider.xoNodeID
            }
            .map(\.id)
    }

    private static func installDailyNode(persistence: ProjectPersistenceService) throws {
        let rootFileName = CanvasFileNaming.rootFileName
        guard persistence.projectExists(fileName: rootFileName) else { return }

        let snapshot = try persistence.load(fileName: rootFileName)
        guard !snapshot.nodes.contains(where: { $0.id == RootCanvasProvider.dailyNodeID }) else {
            return
        }

        let launchIDs = Set(launchLayoutNodeIDs())
        guard Set(snapshot.nodes.map(\.id)) == launchIDs else { return }

        let launchNodes = launchLayoutNodeIDs().compactMap { id in
            RootCanvasProvider.nodes.first(where: { $0.id == id })
        }
        let constellationPositions: [UUID: CGPoint] = Dictionary(
            uniqueKeysWithValues: launchNodes.compactMap { node -> (UUID, CGPoint)? in
                guard let position = RootCanvasProvider.legacyConstellationPosition(for: node.id) else {
                    return nil
                }
                return (node.id, position)
            }
        )
        let verticalPositions: [UUID: CGPoint] = Dictionary(
            uniqueKeysWithValues: launchNodes.enumerated().map { index, node in
                (node.id, RootCanvasProvider.verticalColumnPosition(index: index, count: launchNodes.count))
            }
        )
        let gridPositions: [UUID: CGPoint] = Dictionary(uniqueKeysWithValues: launchNodes.map { ($0.id, $0.position) })
        let hasLaunchPositions = snapshot.nodes.allSatisfy {
            constellationPositions[$0.id] == $0.position ||
                verticalPositions[$0.id] == $0.position ||
                gridPositions[$0.id] == $0.position
        }
        guard hasLaunchPositions else { return }

        let orderedNodes = RootCanvasProvider.nodes.map { canonical -> SpatialNode in
            if let existing = snapshot.nodes.first(where: { $0.id == canonical.id }) {
                var updated = existing
                updated.position = canonical.position
                return updated
            }
            return canonical
        }

        try persistence.save(
            ProjectSnapshot(
                schemaVersion: snapshot.schemaVersion,
                projectName: snapshot.projectName,
                nodes: orderedNodes,
                viewportOffset: snapshot.viewportOffset,
                viewportScale: snapshot.viewportScale,
                checkpointLabel: snapshot.checkpointLabel
            ),
            fileName: rootFileName
        )
    }

    private static func preGridRootNodeIDs() -> Set<UUID> {
        Set(RootCanvasProvider.nodes.filter { $0.id != RootCanvasProvider.xoNodeID }.map(\.id))
    }

    /// Repositions the seven-node vertical column into the centered two-column constellation.
    private static func refreshConstellationRootLayout(persistence: ProjectPersistenceService) throws {
        let rootFileName = CanvasFileNaming.rootFileName
        guard persistence.projectExists(fileName: rootFileName) else { return }

        let snapshot = try persistence.load(fileName: rootFileName)
        let preGridIDs = preGridRootNodeIDs()
        guard Set(snapshot.nodes.map(\.id)) == preGridIDs else { return }

        let preGridNodes = RootCanvasProvider.nodes.filter { $0.id != RootCanvasProvider.xoNodeID }
        let verticalPositions = Dictionary(
            uniqueKeysWithValues: preGridNodes.enumerated().map { index, node in
                (node.id, RootCanvasProvider.verticalColumnPosition(index: index, count: preGridNodes.count))
            }
        )
        let hasVerticalLayout = snapshot.nodes.allSatisfy { verticalPositions[$0.id] == $0.position }
        guard hasVerticalLayout else { return }

        let updatedNodes = snapshot.nodes.map { node -> SpatialNode in
            var updated = node
            if let position = RootCanvasProvider.legacyConstellationPosition(for: node.id) {
                updated.position = position
            }
            return updated
        }
        let orderedNodes = preGridNodes.compactMap { canonical in
            updatedNodes.first(where: { $0.id == canonical.id })
        }

        try persistence.save(
            ProjectSnapshot(
                schemaVersion: snapshot.schemaVersion,
                projectName: snapshot.projectName,
                nodes: orderedNodes,
                viewportOffset: snapshot.viewportOffset,
                viewportScale: snapshot.viewportScale,
                checkpointLabel: snapshot.checkpointLabel
            ),
            fileName: rootFileName
        )
    }

    /// Seeds the XO child canvas and upgrades the seven-node constellation to the launch grid.
    private static func installXOGridLayout(persistence: ProjectPersistenceService) throws {
        try seedIfMissing(
            XOCanvasProvider.snapshot,
            fileName: RootCanvasProvider.xoFileName,
            persistence: persistence
        )

        let rootFileName = CanvasFileNaming.rootFileName
        guard persistence.projectExists(fileName: rootFileName) else { return }

        let snapshot = try persistence.load(fileName: rootFileName)
        guard !snapshot.nodes.contains(where: { $0.id == RootCanvasProvider.xoNodeID }) else {
            return
        }

        let preGridIDs = preGridRootNodeIDs()
        guard Set(snapshot.nodes.map(\.id)) == preGridIDs else { return }

        let hasConstellationLayout = snapshot.nodes.allSatisfy {
            RootCanvasProvider.legacyConstellationPosition(for: $0.id) == $0.position
        }
        guard hasConstellationLayout else { return }

        let orderedNodes = RootCanvasProvider.nodes.map { canonical -> SpatialNode in
            if let existing = snapshot.nodes.first(where: { $0.id == canonical.id }) {
                var updated = existing
                updated.position = canonical.position
                return updated
            }
            return canonical
        }

        try persistence.save(
            ProjectSnapshot(
                schemaVersion: snapshot.schemaVersion,
                projectName: snapshot.projectName,
                nodes: orderedNodes,
                viewportOffset: snapshot.viewportOffset,
                viewportScale: snapshot.viewportScale,
                checkpointLabel: snapshot.checkpointLabel
            ),
            fileName: rootFileName
        )
    }

    /// Reframes the canonical eight-node grid when the root still uses the prior 0.5 launch zoom.
    private static func refreshLaunchViewportScale(persistence: ProjectPersistenceService) throws {
        let rootFileName = CanvasFileNaming.rootFileName
        guard persistence.projectExists(fileName: rootFileName) else { return }

        let snapshot = try persistence.load(fileName: rootFileName)
        let canonicalIDs = Set(RootCanvasProvider.nodes.map(\.id))
        guard Set(snapshot.nodes.map(\.id)) == canonicalIDs else { return }

        let gridPositions: [UUID: CGPoint] = Dictionary(
            uniqueKeysWithValues: RootCanvasProvider.nodes.map { ($0.id, $0.position) }
        )
        let hasGridLayout = snapshot.nodes.allSatisfy { gridPositions[$0.id] == $0.position }
        guard hasGridLayout else { return }

        let hadDefaultViewport = snapshot.viewportScale == 0.5 && snapshot.viewportOffset == .zero
        guard hadDefaultViewport else { return }

        try persistence.save(
            ProjectSnapshot(
                schemaVersion: snapshot.schemaVersion,
                projectName: snapshot.projectName,
                nodes: snapshot.nodes,
                viewportOffset: .zero,
                viewportScale: RootCanvasProvider.defaultViewportScale,
                checkpointLabel: snapshot.checkpointLabel
            ),
            fileName: rootFileName
        )
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
