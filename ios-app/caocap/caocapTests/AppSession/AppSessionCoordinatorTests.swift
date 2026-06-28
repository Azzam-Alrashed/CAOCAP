import CoreGraphics
import Foundation
import Testing
@testable import caocap

@MainActor
struct AppSessionCoordinatorTests {

    @Test func toggleGridActionPersistsOpacity() {
        let session = AppSessionCoordinator()
        session.ensureActionsConfigured()
        session.gridOpacity = 0.5

        _ = session.actionDispatcher.perform(.toggleGrid, source: .user)

        #expect(session.gridOpacity == 0.0)

        _ = session.actionDispatcher.perform(.toggleGrid, source: .user)

        #expect(session.gridOpacity == 0.5)
    }

    @Test func goRootActionResetsScale() {
        let session = AppSessionCoordinator()
        session.ensureActionsConfigured()
        session.currentScale = 2.0

        _ = session.actionDispatcher.perform(.goRoot, source: .user)

        #expect(session.currentScale == 1.0)
        #expect(session.router.currentWorkspace == .root)
    }

    @Test func moveNodeActionUpdatesPosition() {
        let session = AppSessionCoordinator()
        session.ensureActionsConfigured()
        let nodeID = UUID()
        session.router.activeStore.nodes = [
            SpatialNode(id: nodeID, type: .miniApp, position: .zero, title: "Test")
        ]

        let result = session.actionDispatcher.perform(
            .moveNode,
            source: .user,
            arguments: [
                "nodeId": nodeID.uuidString,
                "x": "120",
                "y": "80"
            ]
        )

        #expect(result.executed)
        #expect(session.router.activeStore.nodes.first?.position == CGPoint(x: 120, y: 80))
    }

    @Test func filteredPaletteActionsHideRootNavigationAtRoot() {
        let session = AppSessionCoordinator()
        session.router.currentWorkspace = .root

        let actionIDs = session.filteredPaletteActionIDs(at: .root)

        #expect(!actionIDs.contains(.goRoot))
        #expect(!actionIDs.contains(.goBack))
    }

    @Test func activityNodeActionPresentsActivitySheet() {
        let session = AppSessionCoordinator()

        session.handleNodeAction(.openActivity)

        #expect(session.showingActivity)
    }

    @Test func dailyNodeActionPresentsDailySheet() {
        let session = AppSessionCoordinator()

        session.handleNodeAction(.openDaily)

        #expect(session.showingDaily)
    }

    @Test func whatsAppNodeActionOpensSupportURL() {
        #expect(SupportContact.whatsAppURL?.absoluteString == "https://wa.me/966559279486")
    }

    @Test func flyToTargetScaleUsesMeasuredFrameWhenAvailable() {
        let session = AppSessionCoordinator()
        let nodeID = UUID()
        let node = SpatialNode(id: nodeID, type: .miniApp, position: CGPoint(x: 10, y: 20), title: "Mini")
        session.containerSize = CGSize(width: 400, height: 800)
        session.nodeFrames[nodeID] = NodeFrameData(
            nodeId: nodeID,
            frame: CGRect(x: 0, y: 0, width: 200, height: 400),
            size: CGSize(width: 200, height: 400)
        )

        let scale = session.flyToTargetScale(for: node, nodeId: nodeID)

        #expect(scale == 1.2)
    }

    @Test func flyToTargetScaleFallsBackToDefaultMiniAppSize() {
        let session = AppSessionCoordinator()
        let nodeID = UUID()
        let node = SpatialNode(id: nodeID, type: .miniApp, position: .zero, title: "Mini")
        session.containerSize = CGSize(width: 375, height: 667)

        let scale = session.flyToTargetScale(for: node, nodeId: nodeID)

        #expect(scale == 0.8)
    }
}
