import CoreGraphics
import Foundation
import Testing
@testable import caocap

struct RootCanvasProviderTests {
    @Test func rootDefinesTheCuratedSixNodeVerticalColumn() throws {
        let nodes = RootCanvasProvider.nodes
        #expect(nodes.count == 6)

        let spacing: CGFloat = 220
        let startY = -CGFloat(nodes.count - 1) * spacing / 2

        #expect(nodes[0].id == RootCanvasProvider.profileNodeID)
        #expect(nodes[0].position == CGPoint(x: 0, y: startY))
        #expect(nodes[0].theme == .blue)

        #expect(nodes[1].id == RootCanvasProvider.proNodeID)
        #expect(nodes[1].position == CGPoint(x: 0, y: startY + spacing))
        #expect(nodes[1].theme == .orange)

        #expect(nodes[2].id == RootCanvasProvider.settingsNodeID)
        #expect(nodes[2].position == CGPoint(x: 0, y: startY + spacing * 2))
        #expect(nodes[2].theme == .pink)

        let pacMan = try #require(nodes.first { $0.id == RootCanvasProvider.pacManNodeID })
        #expect(pacMan.position == CGPoint(x: 0, y: startY + spacing * 3))
        #expect(pacMan.type == .subCanvas)
        #expect(pacMan.linkedCanvasFileName == RootCanvasProvider.pacManFileName)
        #expect(pacMan.theme == .purple)

        let tutorial = try #require(nodes.first { $0.id == RootCanvasProvider.tutorialNodeID })
        #expect(tutorial.position == CGPoint(x: 0, y: startY + spacing * 4))
        #expect(tutorial.type == .subCanvas)
        #expect(tutorial.linkedCanvasFileName == RootCanvasProvider.tutorialFileName)
        #expect(tutorial.theme == .green)

        let activity = try #require(nodes.first { $0.id == RootCanvasProvider.activityNodeID })
        #expect(activity.position == CGPoint(x: 0, y: startY + spacing * 5))
        #expect(activity.theme == .cyan)

        #expect(!nodes.contains { $0.title == "Resume" || $0.title == "Projects" || $0.title == "New Project" })
    }

    @Test func rootActionNodesRetainTheirTypedDestinations() {
        let actions = Dictionary(
            uniqueKeysWithValues: RootCanvasProvider.nodes.compactMap { node in
                node.action.map { (node.id, $0) }
            }
        )

        #expect(actions[RootCanvasProvider.profileNodeID] == .openProfile)
        #expect(actions[RootCanvasProvider.settingsNodeID] == .openSettings)
        #expect(actions[RootCanvasProvider.proNodeID] == .proSubscription)
        #expect(actions[RootCanvasProvider.activityNodeID] == .openActivity)
        #expect(actions.count == 4)
    }

    @Test func pacManCanvasContainsATouchFirstRunnableMiniApp() throws {
        let node = try #require(PacManCanvasProvider.snapshot.nodes.first)
        let code = try #require(node.miniApp?.codeText)

        #expect(node.type == .miniApp)
        #expect(code.contains("pointerdown"))
        #expect(code.contains("pointerup"))
        #expect(code.contains("touch-action:none"))
        #expect(code.contains("viewport-fit=cover"))
        #expect(code.contains("data-dir=\"up\""))
        #expect(!code.contains("https://"))
    }
}
