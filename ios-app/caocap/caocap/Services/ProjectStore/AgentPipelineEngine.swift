import Foundation
import SwiftUI
import OSLog

@Observable
@MainActor
public final class AgentPipelineEngine {
    public var activeAgentStates: [UUID: AgentExecutionState] = [:]
    private var agentTriggerTasks: [UUID: Task<Void, Never>] = [:]
    
    private let logger = Logger(subsystem: "com.caocap.AgentPipelineEngine", category: "Engine")
    
    public init() {}
    
    /// Autonomously triggers agents on downstream nodes when an upstream node updates.
    public func triggerDownstreamAgents(from sourceNodeID: UUID, nodes: [SpatialNode], store: ProjectStore) {
        guard UserDefaults.standard.bool(forKey: ProjectStore.experimentalAgentPipesEnabledKey) else {
            return
        }

        agentTriggerTasks[sourceNodeID]?.cancel()
        
        agentTriggerTasks[sourceNodeID] = Task { @MainActor [weak self] in
            // Wait for 3 seconds of inactivity before triggering heavy LLM calls
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            guard let self = self else { return }
            
            guard let sourceNode = nodes.first(where: { $0.id == sourceNodeID }) else { return }
            let title = sourceNode.displayTitle
            
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
                        self.activeAgentStates[downstreamNode.id] = .awaitingReview
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
    
    public func evaluateAINode(id: UUID, store: ProjectStore) {
        guard let index = store.nodes.firstIndex(where: { $0.id == id }),
              store.nodes[index].type == .aiAgent,
              let template = store.nodes[index].promptTemplate, !template.isEmpty else { return }
        
        // Build the prompt by injecting input node content
        var finalPrompt = template
        let inputIds = store.nodes[index].inputNodeIds ?? []
        
        for (idx, inputId) in inputIds.enumerated() {
            if let inputNode = store.nodes.first(where: { $0.id == inputId }) {
                let content = inputNode.textContent ?? inputNode.aiResponse ?? inputNode.subtitle ?? ""
                
                // For tables, we can wrap the content in a data block to help the AI
                let processedContent = inputNode.type == .table ? "### DATA TABLE: \(inputNode.title) ###\n\(content)\n###################" : content
                
                // Replace both index-based and title-based tags
                finalPrompt = finalPrompt.replacingOccurrences(of: "{{input\(idx + 1)}}", with: processedContent)
                finalPrompt = finalPrompt.replacingOccurrences(of: "{{\(inputNode.title)}}", with: processedContent)
            }
        }
        
        // Trigger async AI call
        Task { @MainActor [weak store] in
            guard let store = store else { return }
            // Find index again in case nodes array changed
            guard let taskIndex = store.nodes.firstIndex(where: { $0.id == id }) else { return }
            store.nodes[taskIndex].aiResponse = "Thinking..."
            
            do {
                var response = ""
                let stream = LLMService.shared.streamResponse(for: finalPrompt)
                for try await chunk in stream {
                    response += chunk
                    // Throttle updates for UI performance if needed, but for small nodes this is fine
                    if let updateIndex = store.nodes.firstIndex(where: { $0.id == id }) {
                        store.nodes[updateIndex].aiResponse = response
                    }
                }
                
                // Final result
                if let finalIndex = store.nodes.firstIndex(where: { $0.id == id }) {
                    store.nodes[finalIndex].aiResponse = response
                    store.recalculateGraph()
                    store.requestSave()
                }
            } catch {
                if let errorIndex = store.nodes.firstIndex(where: { $0.id == id }) {
                    store.nodes[errorIndex].aiResponse = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
