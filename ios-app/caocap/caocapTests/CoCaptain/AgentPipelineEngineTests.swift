import XCTest
import SwiftUI
@testable import caocap

@MainActor
final class AgentPipelineEngineTests: XCTestCase {
    var engine: AgentPipelineEngine!
    var store: ProjectStore!

    override func setUp() async throws {
        engine = AgentPipelineEngine()
        store = ProjectStore(
            fileName: "pipeline-test-\(UUID().uuidString).json",
            projectName: "Pipeline Test",
            initialNodes: [
                SpatialNode(type: .miniApp, position: .zero, title: "Dest", miniApp: MiniAppState(codeText: "<h1>Hi</h1>"))
            ]
        )
    }

    func testTriggerDownstreamAgentsFindsNodes() async throws {
        UserDefaults.standard.set(true, forKey: ProjectStore.experimentalAgentPipesEnabledKey)
        defer { UserDefaults.standard.removeObject(forKey: ProjectStore.experimentalAgentPipesEnabledKey) }

        let sourceNode = SpatialNode(type: .miniApp, position: .zero, title: "Source")
        var destNode = SpatialNode(type: .miniApp, position: .zero, title: "Dest")
        destNode.agentProfile.isAutoTriggerEnabled = true

        engine.triggerDownstreamAgents(from: sourceNode.id, nodes: [sourceNode, destNode], store: store)
    }

    func testStageReviewBundlePersistsAndSetsAwaitingReview() {
        let nodeID = store.nodes[0].id
        let timelineItemID = UUID()
        let bundle = ReviewBundleItem(
            items: [
                PendingReviewItem(
                    targetLabel: "Mini-App CODE",
                    summary: "Sync upstream change",
                    preview: "<h1>Updated</h1>",
                    source: .nodeEdit(
                        role: .miniApp,
                        section: .code,
                        operations: [NodePatchOperation(type: .replaceAll, content: "<h1>Updated</h1>")],
                        baseText: "<h1>Hi</h1>"
                    )
                )
            ]
        )

        engine.stageReviewBundle(bundle, timelineItemID: timelineItemID, nodeID: nodeID, store: store)

        XCTAssertEqual(engine.activeAgentStates[nodeID], .awaitingReview)
        let records = NodeAgentReviewPersistence.decode(from: store.nodes[0].agentState)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].timelineItemID, timelineItemID)
        XCTAssertEqual(records[0].bundle.items.first?.summary, "Sync upstream change")
    }
}
