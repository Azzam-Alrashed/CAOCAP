import Foundation
import Testing
@testable import caocap

struct NodeAgentReviewPersistenceTests {
    @MainActor
    @Test func persistAndReloadReviewBundleOnNode() {
        let store = ProjectStore(
            fileName: "review-persist-\(UUID().uuidString).json",
            projectName: "Persist Test",
            initialNodes: [
                SpatialNode(type: .miniApp, position: .zero, title: "Mini-App", miniApp: MiniAppState(codeText: "<h1>Hi</h1>"))
            ]
        )
        let nodeID = store.nodes[0].id
        let timelineItemID = UUID()
        let bundle = ReviewBundleItem(
            items: [
                PendingReviewItem(
                    targetLabel: "Mini-App CODE",
                    summary: "Update",
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

        NodeAgentReviewPersistence.persist(
            timelineItemID: timelineItemID,
            bundle: bundle,
            nodeID: nodeID,
            store: store
        )

        let records = NodeAgentReviewPersistence.decode(from: store.nodes[0].agentState)
        #expect(records.count == 1)
        #expect(records[0].timelineItemID == timelineItemID)
        #expect(records[0].bundle.items.first?.preview.contains("Updated") == true)

        var resolvedBundle = records[0].bundle
        resolvedBundle.items[0].status = .applied
        NodeAgentReviewPersistence.persist(
            timelineItemID: timelineItemID,
            bundle: resolvedBundle,
            nodeID: nodeID,
            store: store
        )

        #expect(NodeAgentReviewPersistence.decode(from: store.nodes[0].agentState).isEmpty)
    }
}
