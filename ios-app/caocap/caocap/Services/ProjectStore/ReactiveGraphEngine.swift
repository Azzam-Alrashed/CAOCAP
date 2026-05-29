import Foundation

@MainActor
struct ReactiveGraphEngine {
    
    /// Evaluates the reactive graph: Text → Calculation → Display.
    /// Mutates nodes in-place. Returns true if any output values changed.
    func recalculate(nodes: inout [SpatialNode]) -> Bool {
        var overallChanged = false
        
        // Multi-pass to handle chains (e.g. A + B -> C, then C + D -> E)
        for _ in 0..<3 {
            var currentPassChanged = false
            
            for i in 0..<nodes.count {
                let node = nodes[i]
                
                if node.type == .calculation {
                    let inputs = (node.inputNodeIds ?? []).compactMap { id in
                        nodes.first(where: { $0.id == id })
                    }
                    
                    let values = inputs.compactMap { inputNode -> Double? in
                        if let outputValue = inputNode.outputValue {
                            return outputValue
                        }
                        return numericValue(from: inputNode)
                    }
                    
                    let result: Double
                    let op = node.operation ?? .add
                    
                    if values.isEmpty {
                        result = 0
                    } else {
                        switch op {
                        case .add:
                            result = values.reduce(0, +)
                        case .subtract:
                            result = values.count > 1 ? values.dropFirst().reduce(values[0], -) : (values.first ?? 0)
                        case .multiply:
                            result = values.reduce(1, *)
                        case .divide:
                            let first = values.first ?? 0
                            let others = values.dropFirst()
                            result = others.contains(0) ? 0 : others.reduce(first, /)
                        }
                    }
                    
                    if nodes[i].outputValue != result {
                        nodes[i].outputValue = result
                        currentPassChanged = true
                        overallChanged = true
                    }
                } else if node.type == .display {
                    // Display nodes mirror their first input
                    if let inputId = node.inputNodeIds?.first,
                       let inputNode = nodes.first(where: { $0.id == inputId }) {
                        let value = inputNode.outputValue ?? numericValue(from: inputNode) ?? 0
                        if nodes[i].outputValue != value {
                            nodes[i].outputValue = value
                            currentPassChanged = true
                            overallChanged = true
                        }
                    }
                } else if node.type == .aiAgent {
                    // AI Agents use aiResponse, but they can flow into Display nodes as well.
                    // RecalculateGraph primarily handles numeric propagation.
                }
            }
            
            if !currentPassChanged { break }
        }
        
        return overallChanged
    }

    /// Extracts a numeric value from a node's text/AI response/subtitle.
    func numericValue(from node: SpatialNode) -> Double? {
        let text = node.textContent ?? node.aiResponse ?? node.subtitle ?? ""
        let cleaned = text.filter { "0123456789.-".contains($0) }
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }
}
