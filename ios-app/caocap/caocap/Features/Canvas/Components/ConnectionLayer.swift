import SwiftUI

/// Renders smooth, curved arrows between connected nodes in screen space. Links
/// are not placed inside the scaled node layer because large curves can clip
/// when their endpoints sit far apart on the infinite canvas.
struct ConnectionLayer: View {
    /// User-facing preference that controls whether connections are drawn as
    /// `"Solid"`, `"Dashed"` (default), or `"Neon"`.
    @AppStorage("connection_style") private var connectionStyle = "Dashed"
    /// The current snapshot of all spatial nodes in the project.
    let nodes: [SpatialNode]
    /// Live per-node translation offsets during a drag gesture, used to move
    /// connection endpoints in sync with a dragged node before the position is
    /// committed to the store.
    let dragOffsets: [UUID: CGSize]
    /// Current pan/zoom state, used to convert canvas coordinates to screen points.
    let viewport: ViewportState
    /// The screen-space midpoint of the canvas view, acting as the coordinate origin.
    let center: CGPoint
    /// Live agent execution states, keyed by node ID, used to style connections
    /// differently when a downstream agent is actively running.
    let activeAgentStates: [UUID: AgentExecutionState]
    /// Actual rendered frame data for each node, populated via preference keys.
    /// Preferred over the mathematical fallback when available.
    let nodeFrames: [UUID: NodeFrameData]
    
    var body: some View {
        Canvas { context, size in
            let nodeDict = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
            
            for node in nodes {
                // 1. Structural Links (Next/Connected)
                var structuralTargets: [UUID] = []
                if let next = node.nextNodeId { structuralTargets.append(next) }
                if let connected = node.connectedNodeIds { structuralTargets.append(contentsOf: connected) }
                
                for targetId in structuralTargets {
                    if let targetNode = nodeDict[targetId] {
                        let start = screenPoint(for: node)
                        let end = screenPoint(for: targetNode)
                        
                        let isEventPipe = targetNode.agentProfile.isAutoTriggerEnabled
                        let isActive = activeAgentStates[targetNode.id] == .thinking
                            || activeAgentStates[targetNode.id] == .applying
                            || activeAgentStates[targetNode.id] == .awaitingReview
                        
                        drawArrow(context: context, from: start, to: end, themeColor: node.theme.color, scale: viewport.scale, isEventPipe: isEventPipe, isActive: isActive, isLogic: false)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    /// Converts a node's canvas-space position to a screen-space point.
    /// Prefers the measured frame center reported via `NodeFramePreferenceKey`
    /// because it accounts for the node's actual rendered size. Falls back to a
    /// mathematical transform when the preference data is not yet available
    /// (e.g., on the first layout pass).
    private func screenPoint(for node: SpatialNode) -> CGPoint {
        if let frameData = nodeFrames[node.id] {
            return frameData.center
        }

        let nodeOffset = dragOffsets[node.id] ?? .zero
        return CGPoint(
            x: center.x + (node.position.x + nodeOffset.width) * viewport.scale + viewport.offset.width,
            y: center.y + (node.position.y + nodeOffset.height) * viewport.scale + viewport.offset.height
        )
    }
    
    private func drawArrow(context: GraphicsContext, from: CGPoint, to: CGPoint, themeColor: Color, scale: CGFloat, isEventPipe: Bool, isActive: Bool, isLogic: Bool) {
        var path = Path()
        path.move(to: from)
        
        // Calculate control points for a smooth curve
        let midX = (from.x + to.x) / 2
        let cp1 = CGPoint(x: midX, y: from.y)
        let cp2 = CGPoint(x: midX, y: to.y)
        
        path.addCurve(to: to, control1: cp1, control2: cp2)
        
        let stroke: StrokeStyle
        let color: Color
        
        if isLogic {
            // Logic links use a tighter dash and distinct orange color
            stroke = StrokeStyle(lineWidth: 2 * scale, lineCap: .round, lineJoin: .round, dash: [5 * scale, 5 * scale])
            color = .orange.opacity(0.8)
        } else if isEventPipe {
            let pipeColor = isActive ? Color.blue : themeColor
            stroke = StrokeStyle(lineWidth: (isActive ? 5 : 3) * scale, lineCap: .round, lineJoin: .round, dash: isActive ? [15 * scale, 15 * scale] : [])
            color = pipeColor.opacity(isActive ? 1.0 : 0.8)
            
            var arrowContext = context
            arrowContext.addFilter(.shadow(color: pipeColor, radius: (isActive ? 8 : 4) * scale))
            arrowContext.stroke(path, with: .color(color), style: stroke)
            drawArrowhead(context: arrowContext, at: to, direction: calculateDirection(from: cp2, to: to), color: color, scale: scale * (isActive ? 1.5 : 1.2))
            return
        } else {
            switch connectionStyle {
            case "Solid":
                stroke = StrokeStyle(lineWidth: 2 * scale, lineCap: .round, lineJoin: .round)
                color = themeColor.opacity(0.6)
            case "Neon":
                stroke = StrokeStyle(lineWidth: 3 * scale, lineCap: .round, lineJoin: .round)
                color = themeColor
            default: // Dashed
                stroke = StrokeStyle(lineWidth: 3 * scale, lineCap: .round, lineJoin: .round, dash: [10 * scale, 10 * scale])
                color = themeColor.opacity(0.4)
            }
        }
        
        var arrowContext = context
        if !isLogic && connectionStyle == "Neon" {
            arrowContext.addFilter(.shadow(color: themeColor, radius: 4 * scale))
        }
        
        arrowContext.stroke(path, with: .color(color), style: stroke)
        
        // Draw an arrowhead at the end
        drawArrowhead(context: arrowContext, at: to, direction: calculateDirection(from: cp2, to: to), color: color, scale: scale)
    }
    
    private func drawArrowhead(context: GraphicsContext, at point: CGPoint, direction: CGFloat, color: Color, scale: CGFloat) {
        let size: CGFloat = 12 * scale
        var path = Path()
        path.move(to: CGPoint(x: -size, y: -size/1.5))
        path.addLine(to: .zero)
        path.addLine(to: CGPoint(x: -size, y: size/1.5))
        
        var arrowContext = context
        arrowContext.translateBy(x: point.x, y: point.y)
        arrowContext.rotate(by: Angle(radians: Double(direction)))
        arrowContext.fill(path, with: .color(color))
    }
    
    /// Returns the angle (in radians) a line segment makes with the positive x-axis,
    /// used to orient the arrowhead so it points in the same direction as the curve's
    /// terminal tangent.
    private func calculateDirection(from: CGPoint, to: CGPoint) -> CGFloat {
        atan2(to.y - from.y, to.x - from.x)
    }
}
