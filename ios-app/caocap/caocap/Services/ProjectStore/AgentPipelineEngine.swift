import Foundation
import SwiftUI
import OSLog

/// Manages autonomous, event-driven agent invocations that fan out from
/// upstream node mutations to connected downstream nodes.
///
/// Downstream triggers are debounced so rapid edits don't spam the LLM.
/// This engine is only active when the experimental agent pipes feature flag
/// is enabled in `UserDefaults`.
@Observable
@MainActor
public final class AgentPipelineEngine {
    /// Keyed by node ID; tracks the current execution state of each in-flight agent run.
    public var activeAgentStates: [UUID: AgentExecutionState] = [:]
    /// One cancellable task per source node, used to debounce rapid upstream edits.
    private var agentTriggerTasks: [UUID: Task<Void, Never>] = [:]
    
    private let logger = Logger(subsystem: "com.caocap.AgentPipelineEngine", category: "Engine")
    
    public init() {}
    
    /// Autonomously triggers agents on downstream nodes when an upstream node updates.
    public func triggerDownstreamAgents(from sourceNodeID: UUID, nodes: [SpatialNode], store: ProjectStore) {
        guard UserDefaults.standard.bool(forKey: ProjectStore.experimentalAgentPipesEnabledKey) else {
            return
        }

        // Cancel any pending trigger for this source node so a burst of edits
        // only fires a single agent run after the user stops typing.
        agentTriggerTasks[sourceNodeID]?.cancel()
        
        agentTriggerTasks[sourceNodeID] = Task { @MainActor [weak self] in
            // Wait for 3 seconds of inactivity before triggering heavy LLM calls
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            guard let self = self else { return }
            
            guard let sourceNode = nodes.first(where: { $0.id == sourceNodeID }) else { return }
            let title = sourceNode.displayTitle
            
            // A downstream node qualifies if auto-trigger is on AND it is directly
            // linked to the source via any edge direction or the nextNodeId pointer.
            let downstreamNodes = nodes.filter { node in
                node.agentProfile.isAutoTriggerEnabled &&
                (node.connectedNodeIds?.contains(sourceNodeID) == true || sourceNode.connectedNodeIds?.contains(node.id) == true || sourceNode.nextNodeId == node.id)
            }
            
            guard !downstreamNodes.isEmpty else { return }
            
            for downstreamNode in downstreamNodes {
                let prompt = "AUTO-TRIGGER: The upstream node '\(title)' was just updated. Please review its new state in the context and apply any necessary changes to your own code/content to stay synchronized."
                
                let triggerMsg = NodeAgentMessage(text: prompt, isUser: true)
                store.appendNodeAgentMessage(id: downstreamNode.id, message: triggerMsg)
                self.activeAgentStates[downstreamNode.id] = .thinking
                
                let coordinator = CoCaptainAgentCoordinator()
                
                do {
                    let result = try await coordinator.run(
                        userMessage: prompt,
                        store: store,
                        dispatcher: nil, 
                        scope: .node(downstreamNode.id),
                        onVisibleText: { _ in } 
                    )
                    
                    if let payloadMessage = result.payloadMessage, !payloadMessage.isEmpty {
                        let aiMsg = NodeAgentMessage(text: payloadMessage, isUser: false)
                        store.appendNodeAgentMessage(id: downstreamNode.id, message: aiMsg)
                    }
                    
                    if let reviewBundle = result.reviewBundle, !reviewBundle.items.isEmpty {
                        self.stageReviewBundle(
                            reviewBundle,
                            timelineItemID: UUID(),
                            nodeID: downstreamNode.id,
                            store: store
                        )
                        let summaries = reviewBundle.items
                            .map { "- \($0.targetLabel): \($0.summary)" }
                            .joined(separator: "\n")
                        let reviewMsg = NodeAgentMessage(
                            text: "CoCaptain prepared changes that require review before anything is applied:\n\(summaries)",
                            isUser: false
                        )
                        store.appendNodeAgentMessage(id: downstreamNode.id, message: reviewMsg)
                    }
                    
                    if self.activeAgentStates[downstreamNode.id] != .awaitingReview {
                        self.activeAgentStates[downstreamNode.id] = .idle
                    }
                } catch {
                    let errorMsg = NodeAgentMessage(text: "Auto-trigger failed: \(error.localizedDescription)", isUser: false)
                    store.appendNodeAgentMessage(id: downstreamNode.id, message: errorMsg)
                    self.activeAgentStates[downstreamNode.id] = .error(error.localizedDescription)
                    
                    // Clear error after a short delay
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        guard let self = self else { return }
                        if case .error = self.activeAgentStates[downstreamNode.id] {
                            self.activeAgentStates[downstreamNode.id] = .idle
                        }
                    }
                }
            }
        }
    }

    /// Persists a review bundle on the node and marks the pipeline state as awaiting review.
    func stageReviewBundle(
        _ reviewBundle: ReviewBundleItem,
        timelineItemID: UUID,
        nodeID: UUID,
        store: ProjectStore
    ) {
        NodeAgentReviewPersistence.persist(
            timelineItemID: timelineItemID,
            bundle: reviewBundle,
            nodeID: nodeID,
            store: store
        )
        activeAgentStates[nodeID] = .awaitingReview
    }
}
