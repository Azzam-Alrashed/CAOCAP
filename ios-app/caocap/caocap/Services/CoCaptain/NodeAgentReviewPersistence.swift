import Foundation

/// Encodes and stores pending CoCaptain review bundles on a node's agent state.
enum NodeAgentReviewPersistence {
    static func decode(from agentState: NodeAgentState) -> [NodeAgentReviewRecord] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return agentState.pendingReviewBundlesData.compactMap { data in
            try? decoder.decode(NodeAgentReviewRecord.self, from: data)
        }
    }

    static func persist(
        timelineItemID: UUID,
        bundle: ReviewBundleItem,
        nodeID: UUID,
        store: ProjectStore
    ) {
        guard let nodeIndex = store.nodes.firstIndex(where: { $0.id == nodeID }) else { return }

        var agentState = store.nodes[nodeIndex].agentState
        var records = decode(from: agentState)

        if bundle.items.allSatisfy({ $0.status != .pending }) {
            records.removeAll { $0.timelineItemID == timelineItemID }
        } else if let index = records.firstIndex(where: { $0.timelineItemID == timelineItemID }) {
            records[index].bundle = bundle
        } else {
            records.append(NodeAgentReviewRecord(timelineItemID: timelineItemID, bundle: bundle))
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        agentState.pendingReviewBundlesData = records.compactMap { try? encoder.encode($0) }
        store.updateNodeAgentState(id: nodeID, agentState: agentState)
    }
}
