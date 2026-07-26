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

    func testStageReviewDraftPersistsAndDerivesAwaitingReview() {
        let nodeID = store.nodes[0].id
        let draft = CoCaptainReviewLifecycle.Draft(
            nodeEdits: [
                CoCaptainNodeEditProposal(
                    nodeID: nodeID,
                    role: .miniApp,
                    section: .code,
                    summary: "Sync upstream change",
                    operations: [
                        NodePatchOperation(type: .replaceAll, content: "<h1>Updated</h1>")
                    ]
                )
            ]
        )

        let record = engine.stageReviewDraft(draft, nodeID: nodeID, store: store)

        XCTAssertNotNil(record)
        XCTAssertEqual(engine.executionState(for: nodeID, in: store), .awaitingReview)
        let restored = CoCaptainReviewLifecycle()
            .session(scope: .node(nodeID), store: store, dispatcher: nil)
        XCTAssertEqual(restored.records.count, 1)
        XCTAssertEqual(restored.records[0].id, record?.id)
        XCTAssertEqual(restored.records[0].bundle.items.first?.summary, "Sync upstream change")

        if let record, let itemID = record.bundle.items.first?.id {
            let resolver = CoCaptainReviewLifecycle()
                .session(scope: .node(nodeID), store: store, dispatcher: nil)
            _ = resolver.resolve(.reject(itemID: itemID), in: record.id)
        }
        XCTAssertEqual(engine.executionState(for: nodeID, in: store), .idle)
    }
}
