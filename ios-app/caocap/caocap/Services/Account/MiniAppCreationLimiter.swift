import Foundation

/// Result of checking whether a free-tier user may create another Mini-App.
public enum MiniAppCreationGate: Equatable {
    case ready
    case requiresPro(used: Int, limit: Int)
}

/// Enforces the free-tier Mini-App creation cap.
///
/// Pro subscribers are unlimited. Free users may keep up to
/// `freeMiniAppLimit` Mini-Apps across all canvases. Curated seed Mini-Apps
/// (Tutorial / Hello World / XO) do not count toward the cap.
public struct MiniAppCreationLimiter: Sendable {
    public static let freeMiniAppLimit = 5

    /// Stable IDs for app-owned example Mini-Apps that free users receive.
    public static let curatedSeedMiniAppIDs: Set<UUID> = [
        TutorialCanvasProvider.miniAppNodeID,
        RootCanvasProvider.helloWorldMiniAppNodeID,
        XOCanvasProvider.miniAppNodeID
    ]

    public init() {}

    public func gate(
        isSubscribed: Bool,
        miniAppCount: Int,
        limit: Int = MiniAppCreationLimiter.freeMiniAppLimit
    ) -> MiniAppCreationGate {
        guard !isSubscribed else { return .ready }
        guard miniAppCount < limit else {
            return .requiresPro(used: miniAppCount, limit: limit)
        }
        return .ready
    }

    /// Counts Mini-Apps toward the free-tier quota.
    ///
    /// Live in-memory node arrays win over disk for the same file name so an
    /// unsaved create/delete is reflected immediately. Curated seed IDs are skipped.
    public func countUserMiniApps(
        persistence: ProjectPersistenceService,
        liveNodesByFileName: [String: [SpatialNode]]
    ) -> Int {
        var countedIDs = Set<UUID>()
        var total = 0

        func consume(_ nodes: [SpatialNode]) {
            for node in nodes where node.type == .miniApp {
                guard !Self.curatedSeedMiniAppIDs.contains(node.id) else { continue }
                guard countedIDs.insert(node.id).inserted else { continue }
                total += 1
            }
        }

        for (_, nodes) in liveNodesByFileName {
            consume(nodes)
        }

        for fileName in persistence.listProjectFileNames() {
            if liveNodesByFileName[fileName] != nil { continue }
            guard let snapshot = try? persistence.load(fileName: fileName) else { continue }
            consume(snapshot.nodes)
        }

        return total
    }
}
