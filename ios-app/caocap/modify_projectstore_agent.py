import re

with open('/Users/azzam-dev/CAOCAP/ios-app/caocap/caocap/Services/ProjectStore/ProjectStore.swift', 'r') as f:
    content = f.read()

# 1. Add agentPipeline engine
content = re.sub(
    r'(public let mutationEngine = NodeMutationEngine\(\))',
    r'\1\n    public let agentPipeline = AgentPipelineEngine()',
    content
)

# 2. Replace activeAgentStates property with computed property
content = re.sub(
    r'public var activeAgentStates: \[UUID: AgentExecutionState\] = \[:\]',
    r'public var activeAgentStates: [UUID: AgentExecutionState] { agentPipeline.activeAgentStates }',
    content
)

# 3. Remove agentTriggerTasks
content = re.sub(
    r'    private var agentTriggerTasks: \[UUID: Task<Void, Never>\] = \[:\]\n',
    r'',
    content
)

# 4. Replace triggerDownstreamAgents
trigger_pattern = r'    public func triggerDownstreamAgents\(from sourceNodeID: UUID\) \{.*?(?=\n    /// Creates a durable checkpoint)'
trigger_repl = '''    public func triggerDownstreamAgents(from sourceNodeID: UUID) {
        agentPipeline.triggerDownstreamAgents(from: sourceNodeID, nodes: nodes, store: self)
    }
'''
content = re.sub(trigger_pattern, trigger_repl, content, flags=re.DOTALL)

# 5. Replace evaluateAINode
eval_pattern = r'    public func evaluateAINode\(id: UUID\) \{.*?(?=\n    private func findInputs)'
eval_repl = '''    public func evaluateAINode(id: UUID) {
        agentPipeline.evaluateAINode(
            id: id,
            nodes: &nodes,
            onRequestSave: { [weak self] in self?.requestSave() },
            onRecalculateGraph: { [weak self] nodes in self?.reactiveGraphEngine.recalculate(nodes: &nodes) ?? false }
        )
    }
'''
content = re.sub(eval_pattern, eval_repl, content, flags=re.DOTALL)


with open('/Users/azzam-dev/CAOCAP/ios-app/caocap/caocap/Services/ProjectStore/ProjectStore.swift', 'w') as f:
    f.write(content)
