import Foundation
import Testing
@testable import caocap

struct MiniAppCreationLimiterTests {
    @Test func subscribersBypassTheFreeCap() {
        let limiter = MiniAppCreationLimiter()
        let gate = limiter.gate(isSubscribed: true, miniAppCount: 50)
        #expect(gate == .ready)
    }

    @Test func freeUsersCanCreateUntilLimit() {
        let limiter = MiniAppCreationLimiter()
        #expect(limiter.gate(isSubscribed: false, miniAppCount: 4) == .ready)
        #expect(
            limiter.gate(isSubscribed: false, miniAppCount: 5)
                == .requiresPro(used: 5, limit: MiniAppCreationLimiter.freeMiniAppLimit)
        )
    }

    @Test func countingSkipsCuratedSeedsAndPrefersLiveNodes() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiniAppCreationLimiterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let persistence = ProjectPersistenceService(baseDirectory: directory)
        let curated = SpatialNode(
            id: TutorialCanvasProvider.miniAppNodeID,
            type: .miniApp,
            position: .zero,
            title: "Seed"
        )
        let staleDiskNode = SpatialNode(
            id: UUID(),
            type: .miniApp,
            position: .zero,
            title: "Stale"
        )
        try persistence.save(
            ProjectSnapshot(
                projectName: "Live",
                nodes: [curated, staleDiskNode],
                viewportOffset: .zero,
                viewportScale: 1
            ),
            fileName: "canvas_live.json"
        )

        let liveReplacement = SpatialNode(
            id: UUID(),
            type: .miniApp,
            position: .zero,
            title: "Live A"
        )
        let liveExtra = SpatialNode(
            id: UUID(),
            type: .miniApp,
            position: .zero,
            title: "Live B"
        )

        let otherDiskNode = SpatialNode(
            id: UUID(),
            type: .miniApp,
            position: .zero,
            title: "Other"
        )
        try persistence.save(
            ProjectSnapshot(
                projectName: "Other",
                nodes: [otherDiskNode, SpatialNode(type: .standard, position: .zero, title: "Pin")],
                viewportOffset: .zero,
                viewportScale: 1
            ),
            fileName: "canvas_other.json"
        )

        let limiter = MiniAppCreationLimiter()
        let count = limiter.countUserMiniApps(
            persistence: persistence,
            liveNodesByFileName: [
                "canvas_live.json": [curated, liveReplacement, liveExtra]
            ]
        )

        // curated seed skipped; live file uses in-memory (2); other disk file (1)
        #expect(count == 3)
    }
}
