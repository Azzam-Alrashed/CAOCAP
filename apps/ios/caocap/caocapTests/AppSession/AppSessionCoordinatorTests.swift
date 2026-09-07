import CoreGraphics
import Foundation
import Testing
@testable import caocap

@MainActor
struct AppSessionCoordinatorTests {

    private func makeSession() -> AppSessionCoordinator {
        let defaults = UserDefaults(suiteName: "AppSessionTests.\(UUID().uuidString)")!
        return AppSessionCoordinator(agentLibrary: AgentLibrary(defaults: defaults))
    }

    @Test func homeDoesNotOpenAgentChat() {
        let session = makeSession()
        session.handleFABTapOrCommandJ()
        #expect(session.selectedTab == .home)
        #expect(session.selectedAgent == nil)
        #expect(!session.coCaptain.isPresented)
    }

    @Test func agentsKeepSeparateCanvasesAndDrafts() async {
        let suite = "AgentSessionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let library = AgentLibrary(defaults: defaults)
        let first = LibraryAgent(id: UUID().uuidString, name: "First", persona: .cocaptain)
        let second = LibraryAgent(id: UUID().uuidString, name: "Second", persona: .costar)
        library.restore(first)
        library.restore(second)
        let session = AppSessionCoordinator(agentLibrary: library)
        session.ensureActionsConfigured()
        session.openAgent(first)
        let firstStore = session.router.activeStore
        let firstNode = SpatialNode(type: .standard, position: .zero, title: "Only first agent")
        firstStore.nodes = [firstNode]
        firstStore.save()
        await firstStore.prepareForDataReset() // Wait for the explicit save; no files are erased.
        let restored = ProjectStore(fileName: first.workspaceFileName)
        #expect(restored.nodes.map(\.id) == [firstNode.id])
        session.coCaptain.composerText = "Draft for first agent"
        session.handleFABTapOrCommandJ()
        #expect(session.coCaptain.isPresented)
        session.showingCopilotCall = true
        session.returnToHome()
        #expect(session.selectedAgent == nil)
        #expect(!session.coCaptain.isPresented)
        #expect(!session.showingCopilotCall)
        session.openAgent(second)
        #expect(session.router.activeStore !== firstStore)
        #expect(session.router.activeStore.nodes.isEmpty)
        #expect(session.router.activeStore.undoManager !== firstStore.undoManager)
        #expect(session.router.activeStore.fileName == second.workspaceFileName)
        #expect(session.coCaptain.store === session.router.activeStore)
        #expect(session.coCaptain.composerText.isEmpty)
        #expect(session.selectedCopilot == .costar)
        #expect(session.coCaptain.agentDisplayName == "Second")
        session.returnToHome()
        session.openAgent(first)
        #expect(session.router.activeStore === firstStore)
        #expect(session.router.activeStore.nodes.map(\.id) == [firstNode.id])
        #expect(session.coCaptain.composerText == "Draft for first agent")
        #expect(session.selectedCopilot == .cocaptain)
    }

    @Test func deferredChatDoesNotFollowUserIntoAnotherAgent() async {
        let session = makeSession()
        session.ensureActionsConfigured()
        session.openAgent(LibraryAgent.defaults[0])
        session.showingProfile = true
        session.presentCoCaptainReplacingListedSheets(preferredDetent: .medium)
        session.returnToHome()
        session.openAgent(LibraryAgent.defaults[1])
        try? await Task.sleep(for: .milliseconds(400))
        #expect(!session.coCaptain.isPresented)
        #expect(session.selectedAgent == LibraryAgent.defaults[1])
    }

    @Test func toggleGridActionPersistsOpacity() {
        let session = makeSession()
        session.ensureActionsConfigured()
        session.gridOpacity = 0.5

        _ = session.actionDispatcher.perform(.toggleGrid, source: .user)

        #expect(session.gridOpacity == 0.0)

        _ = session.actionDispatcher.perform(.toggleGrid, source: .user)

        #expect(session.gridOpacity == 0.5)
    }

    @Test func goRootActionResetsScale() {
        let session = makeSession()
        session.ensureActionsConfigured()
        session.currentScale = 2.0

        _ = session.actionDispatcher.perform(.goRoot, source: .user)

        #expect(session.currentScale == 1.0)
        #expect(session.router.currentWorkspace == .root)
    }

    @Test func moveNodeActionUpdatesPosition() {
        let session = makeSession()
        session.ensureActionsConfigured()
        let nodeID = UUID()
        session.router.activeStore.nodes = [
            SpatialNode(id: nodeID, type: .standard, position: .zero, title: "Test")
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

    @Test func fabTapOpensChatWhenNoListedSheetIsPresented() {
        let session = makeSession()
        session.ensureActionsConfigured()
        session.openAgent(LibraryAgent.defaults[0])

        session.handleFABTapOrCommandJ()

        #expect(session.coCaptain.isPresented)
        #expect(session.coCaptainDetent == .large)
        #expect(session.hasListedSheetPresented)
    }

    @Test func fabTapClosesListedSheetsWithoutOpeningChat() {
        let session = makeSession()
        session.ensureActionsConfigured()
        session.showingSettings = true

        session.handleFABTapOrCommandJ()

        #expect(!session.showingSettings)
        #expect(!session.coCaptain.isPresented)
        #expect(!session.hasListedSheetPresented)
    }

    @Test func closeListedSheetsLeavesOverlaysAlone() {
        let session = makeSession()
        session.showingSettings = true
        session.showingHelp = true
        session.showingCopilotCall = true
        session.showConfetti = true
        session.isLaunching = true

        session.closeListedSheets()

        #expect(!session.showingSettings)
        #expect(!session.showingHelp)
        #expect(session.showingCopilotCall)
        #expect(session.showConfetti)
        #expect(session.isLaunching)
    }

    @Test func summonCoCaptainReplacesListedSheetWithChat() async {
        let session = makeSession()
        session.ensureActionsConfigured()
        session.openAgent(LibraryAgent.defaults[0])
        session.showingProfile = true

        _ = session.actionDispatcher.perform(.summonCoCaptain, source: .user)

        try? await Task.sleep(for: .milliseconds(400))

        #expect(!session.showingProfile)
        #expect(session.coCaptain.isPresented)
        #expect(session.coCaptainDetent == .medium)
    }

    @Test func activityNodeActionPresentsActivitySheet() {
        let session = makeSession()
        session.ensureActionsConfigured()

        session.handleNodeAction(.openActivity)

        #expect(session.showingActivity)
    }

    @Test func navigateRootNodeActionRoutesThroughDispatcher() {
        let session = makeSession()
        session.ensureActionsConfigured()
        session.router.navigate(to: .project("test.json"), animated: false)
        session.currentScale = 2.0

        session.handleNodeAction(.navigateRoot)

        #expect(session.router.currentWorkspace == .root)
        #expect(session.currentScale == 1.0)
    }

    @Test func whatsAppNodeActionIsConfiguredInDispatcher() {
        let session = makeSession()
        session.ensureActionsConfigured()

        let result = session.actionDispatcher.perform(.openWhatsApp, source: .user)

        #expect(result.executed)
        #expect(SupportContact.whatsAppURL?.absoluteString == "https://wa.me/966559279486")
    }

    @Test func helpNodeActionPresentsHelpSheet() {
        let session = makeSession()
        session.ensureActionsConfigured()

        session.handleNodeAction(.openHelp)

        #expect(session.showingHelp)
    }

    @Test func appIconNodeActionPresentsAppIconPickerSheet() {
        let session = makeSession()
        session.ensureActionsConfigured()

        session.handleNodeAction(.openAppIcon)

        #expect(session.showingAppIconPicker)
    }

    @Test func helpAppActionPresentsHelpSheet() {
        let session = makeSession()
        session.ensureActionsConfigured()

        _ = session.actionDispatcher.perform(.help, source: .user)

        #expect(session.showingHelp)
    }

    @Test func flyToTargetScaleUsesMeasuredSizeWhenAvailable() {
        let session = makeSession()
        let nodeID = UUID()
        let node = SpatialNode(id: nodeID, type: .standard, position: CGPoint(x: 10, y: 20), title: "Mini")
        session.containerSize = CGSize(width: 400, height: 800)
        session.nodeSizes[nodeID] = CGSize(width: 200, height: 400)

        let scale = session.flyToTargetScale(for: node, nodeId: nodeID)

        #expect(scale == 1.2)
    }

    @Test func flyToTargetScaleFallsBackToDefaultCardSize() {
        let session = makeSession()
        let nodeID = UUID()
        let node = SpatialNode(id: nodeID, type: .standard, position: .zero, title: "Card")
        session.containerSize = CGSize(width: 375, height: 667)

        let scale = session.flyToTargetScale(for: node, nodeId: nodeID)

        #expect(abs(scale - ((375 * 0.8) / 280)) < 0.0001)
    }

    @Test func bootstrapDismissesLaunchAfterReadyMinimumNotFixedTwoPointFiveSeconds() async {
        let session = makeSession()
        session.launchMinimumVisibleDuration = .milliseconds(20)
        session.launchMaximumVisibleDuration = .milliseconds(200)
        #expect(session.isLaunching)

        session.bootstrap(undoManager: nil)

        try? await Task.sleep(for: .milliseconds(80))
        #expect(!session.isLaunching)
    }

    @Test func bootstrapHonorsLaunchMaximumVisibleDuration() async {
        let session = makeSession()
        session.launchMinimumVisibleDuration = .seconds(10)
        session.launchMaximumVisibleDuration = .milliseconds(30)
        #expect(session.isLaunching)

        session.bootstrap(undoManager: nil)

        try? await Task.sleep(for: .milliseconds(100))
        #expect(!session.isLaunching)
    }
}
