import CoreGraphics
import Foundation
import Testing
@testable import caocap

struct RootCanvasProviderTests {
    @Test func rootDefinesTheCuratedTenNodeGrid() throws {
        let nodes = RootCanvasProvider.nodes
        #expect(nodes.count == 10)
        #expect(RootCanvasProvider.defaultViewportScale == 0.45)
        #expect(RootCanvasProvider.snapshot.viewportScale == RootCanvasProvider.defaultViewportScale)

        let columnSpacing: CGFloat = 250
        let rowY: [CGFloat] = [-330, -110, 110, 330]

        #expect(nodes[0].id == RootCanvasProvider.proNodeID)
        #expect(nodes[0].position == CGPoint(x: -columnSpacing, y: rowY[0]))
        #expect(nodes[0].theme == .orange)

        #expect(nodes[1].id == RootCanvasProvider.settingsNodeID)
        #expect(nodes[1].position == CGPoint(x: -columnSpacing, y: rowY[1]))
        #expect(nodes[1].theme == .pink)

        #expect(nodes[2].id == RootCanvasProvider.profileNodeID)
        #expect(nodes[2].position == CGPoint(x: -columnSpacing, y: rowY[2]))
        #expect(nodes[2].theme == .blue)

        let activity = try #require(nodes.first { $0.id == RootCanvasProvider.activityNodeID })
        #expect(activity.position == CGPoint(x: -columnSpacing, y: rowY[3]))
        #expect(activity.theme == .cyan)

        let tutorial = try #require(nodes.first { $0.id == RootCanvasProvider.tutorialNodeID })
        #expect(tutorial.position == CGPoint(x: columnSpacing, y: rowY[0]))
        #expect(tutorial.type == .subCanvas)
        #expect(tutorial.linkedCanvasFileName == RootCanvasProvider.tutorialFileName)
        #expect(tutorial.theme == .green)

        let pacMan = try #require(nodes.first { $0.id == RootCanvasProvider.pacManNodeID })
        #expect(pacMan.position == CGPoint(x: columnSpacing, y: rowY[1]))
        #expect(pacMan.type == .subCanvas)
        #expect(pacMan.linkedCanvasFileName == RootCanvasProvider.pacManFileName)
        #expect(pacMan.theme == .purple)

        let xo = try #require(nodes.first { $0.id == RootCanvasProvider.xoNodeID })
        #expect(xo.position == CGPoint(x: columnSpacing, y: rowY[2]))
        #expect(xo.type == .subCanvas)
        #expect(xo.linkedCanvasFileName == RootCanvasProvider.xoFileName)
        #expect(xo.theme == .secondary)

        let daily = try #require(nodes.first { $0.id == RootCanvasProvider.dailyNodeID })
        #expect(daily.position == CGPoint(x: columnSpacing, y: rowY[3]))
        #expect(daily.theme == .indigo)
        #expect(daily.action == .openDaily)

        let whatsApp = try #require(nodes.first { $0.id == RootCanvasProvider.whatsAppNodeID })
        #expect(whatsApp.position == CGPoint(x: 0, y: -550))
        #expect(whatsApp.theme == .green)
        #expect(whatsApp.action == .openWhatsApp)

        let help = try #require(nodes.first { $0.id == RootCanvasProvider.helpNodeID })
        #expect(help.position == CGPoint(x: 0, y: 550))
        #expect(help.theme == .indigo)
        #expect(help.action == .openHelp)

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
        #expect(actions[RootCanvasProvider.dailyNodeID] == .openDaily)
        #expect(actions[RootCanvasProvider.whatsAppNodeID] == .openWhatsApp)
        #expect(actions[RootCanvasProvider.helpNodeID] == .openHelp)
        #expect(actions.count == 7)
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

    @Test func xoCanvasContainsATouchFirstRunnableMiniApp() throws {
        let node = try #require(XOCanvasProvider.snapshot.nodes.first)
        let code = try #require(node.miniApp?.codeText)

        #expect(node.type == .miniApp)
        #expect(code.contains("pointerdown"))
        #expect(code.contains("touch-action:none"))
        #expect(code.contains("viewport-fit=cover"))
        #expect(code.contains("role=\"grid\""))
        #expect(!code.contains("https://"))
    }
}
