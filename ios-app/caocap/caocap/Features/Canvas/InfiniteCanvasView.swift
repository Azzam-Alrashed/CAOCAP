import SwiftUI
import UIKit

/// Renders one spatial workspace and owns the transient gesture state needed to
/// pan, zoom, select, and drag nodes without changing the durable project model
/// until a gesture is committed.
struct InfiniteCanvasView: View {
    @Environment(\.colorScheme) var colorScheme
    
    /// Tracks the current panning and zooming state of the canvas.
    @Binding var viewport: ViewportState
    
    /// Real-time scale feedback for external overlays.
    @Binding var currentScale: CGFloat
    
    /// The central store managing node data and persistence.
    var store: ProjectStore
    
    /// Callback triggered when a specialized action node is tapped. Its
    /// presence also marks the canvas as non-persistent onboarding mode.
    var onNodeAction: ((NodeAction) -> Void)? = nil
    
    var onNavigateToSubCanvas: ((String) -> Void)? = nil
    
    init(store: ProjectStore, viewport: Binding<ViewportState>, currentScale: Binding<CGFloat>, onNodeAction: ((NodeAction) -> Void)? = nil, onNavigateToSubCanvas: ((String) -> Void)? = nil) {
        self.store = store
        self._viewport = viewport
        self._currentScale = currentScale
        self.onNodeAction = onNodeAction
        self.onNavigateToSubCanvas = onNavigateToSubCanvas
    }
    
    // Drag offsets stay local until the drag ends so links and nodes can track
    // the finger smoothly without writing every intermediate frame to ProjectStore.
    @State private var selectedNode: SpatialNode?
    @State private var nodeDragOffsets: [UUID: CGSize] = [:]
    @State private var isDraggingNode = false
    @State private var nodeFrames: [UUID: NodeFrameData] = [:]
    
    var body: some View {
        GeometryReader { geometry in
            // Node positions are stored as offsets from the visible center, so
            // the center point is the bridge between canvas-space and screen-space.
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                Color.clear.coordinateSpace(name: "canvas")

                // Layer 1: The Infinite Dotted Grid
                DottedBackground(offset: viewport.offset, scale: viewport.scale)
                
                // Layer 2: Node Connections (Drawn in screen space to prevent clipping and layout bugs)
                ConnectionLayer(
                    nodes: store.nodes,
                    dragOffsets: nodeDragOffsets,
                    viewport: viewport,
                    center: center,
                    activeAgentStates: store.activeAgentStates,
                    nodeFrames: nodeFrames
                )
                
                // Layer 3: The Spatial Core (Scaled & Offset)
                ZStack {
                    // Layer 2.5: Spatial Centerpiece (Universal)
                    Color.clear
                        .frame(width: 0, height: 0)
                        .overlay(
                            Image("SpaceSketchBG")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 2000, height: 2000)
                                .opacity(colorScheme == .dark ? 0.40 : 0.25)
                                .blendMode(colorScheme == .dark ? .screen : .multiply)
                                .allowsHitTesting(false)
                        )
                    
                    ForEach(store.nodes) { node in
                        let currentOffset = nodeDragOffsets[node.id] ?? .zero
                        let isDraggingThisNode = nodeDragOffsets[node.id] != nil
                        
                        NodeView(
                            node: node,
                            isDragging: isDraggingThisNode,
                            agentState: store.activeAgentStates[node.id] ?? .idle,
                            allNodes: store.nodes,
                            onUpdateChartX: { index in
                                store.updateNodeChartXColumn(id: node.id, index: index)
                            },
                            onUpdateChartY: { index in
                                store.updateNodeChartYColumn(id: node.id, index: index)
                            }
                        )
                            .offset(
                                x: node.position.x + currentOffset.width,
                                y: node.position.y + currentOffset.height
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    var targetScale: CGFloat = 1.0
                                    if let frameData = nodeFrames[node.id], geometry.size != .zero {
                                        let paddingFactor: CGFloat = 0.8
                                        let scaleX = (geometry.size.width * paddingFactor) / frameData.size.width
                                        let scaleY = (geometry.size.height * paddingFactor) / frameData.size.height
                                        targetScale = min(min(scaleX, scaleY), 1.2)
                                    }
                                    viewport.flyTo(nodePosition: node.position, containerSize: geometry.size, targetScale: targetScale)
                                }
                                HapticsManager.shared.impact(.medium)
                            }
                            .onTapGesture {
                                if let action = node.action {
                                    onNodeAction?(action)
                                } else if node.type == .subCanvas, let fileName = node.linkedCanvasFileName {
                                    onNavigateToSubCanvas?(fileName)
                                } else {
                                    selectedNode = node
                                }
                            }
                            .contextMenu(menuItems: {
                                if !node.isProtected {
                                    Button(role: .destructive) {
                                        HapticsManager.shared.notification(.warning)
                                        store.deleteNode(id: node.id, persist: true)
                                    } label: {
                                        Label("Delete Node", systemImage: "trash")
                                    }
                                }
                                
                                Button {
                                    selectedNode = node
                                } label: {
                                    Label("Inspect", systemImage: "info.circle")
                                }
                            }, preview: {
                                // Provide a clean, unscaled preview of the node
                                NodeView(node: node, allNodes: store.nodes)
                                    .environment(\.colorScheme, .dark) // Force dark for consistency if needed
                                    .frame(width: 280) // Standard width for preview
                                    .padding()
                            })
                            .gesture(
                                DragGesture(minimumDistance: 5)
                                    .onChanged { value in
                                        isDraggingNode = true
                                        nodeDragOffsets[node.id] = value.translation
                                    }
                                    .onEnded { value in
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                            let finalX = node.position.x + value.translation.width
                                            let finalY = node.position.y + value.translation.height
                                            
                                            store.updateNodePosition(
                                                id: node.id,
                                                position: CGPoint(x: finalX, y: finalY),
                                                persist: true
                                            )
                                            
                                            nodeDragOffsets[node.id] = nil
                                            isDraggingNode = false
                                            HapticsManager.shared.selectionChanged()
                                        }
                                    }
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(viewport.scale)
                .offset(viewport.offset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle()) // Ensure the entire area is gesture-sensitive.
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                    viewport.fitTo(nodes: store.nodes, containerSize: geometry.size)
                }
                HapticsManager.shared.impact(.medium)
            }
            .gesture(
                TrackpadPanGesture(
                    onChanged: { translation in
                        guard !isDraggingNode else { return }
                        viewport.handleDragTranslation(translation)
                    },
                    onEnded: {
                        guard !isDraggingNode else { return }
                        viewport.handleDragEnded()
                        persistViewportIfNeeded()
                    }
                )
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        // Only pan the background if no node is currently being dragged.
                        if !isDraggingNode {
                            viewport.handleDragChanged(value)
                        }
                    }
                    .onEnded { _ in 
                        if !isDraggingNode {
                            viewport.handleDragEnded()
                            persistViewportIfNeeded()
                        }
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        let location = CGPoint(
                            x: value.startAnchor.x * geometry.size.width,
                            y: value.startAnchor.y * geometry.size.height
                        )
                        viewport.handleMagnificationChanged(value.magnification, at: location, in: geometry.size)
                        currentScale = viewport.scale
                    }
                    .onEnded { _ in 
                        viewport.handleMagnificationEnded()
                        currentScale = viewport.scale
                        persistViewportIfNeeded()
                    }
            )
            .onPreferenceChange(NodeFramePreferenceKey.self) { value in
                nodeFrames = value
            }
        }
        .background(backgroundColor)
        .edgesIgnoringSafeArea(.all)
        .sheet(item: $selectedNode) { node in
            NodeDetailView(node: node, store: store)
        }
        .onAppear {
            currentScale = viewport.scale
        }
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.05) : Color(white: 0.95)
    }

    private func persistViewportIfNeeded() {
        store.updateViewport(
            offset: viewport.offset,
            scale: viewport.scale,
            persist: true
        )
    }
}

private struct TrackpadPanGesture: UIGestureRecognizerRepresentable {
    var onChanged: (CGSize) -> Void
    var onEnded: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.allowedScrollTypesMask = .continuous
        recognizer.delegate = context.coordinator
        recognizer.cancelsTouchesInView = false
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view)
        let canvasTranslation = CGSize(width: translation.x, height: translation.y)

        switch recognizer.state {
        case .began, .changed:
            onChanged(canvasTranslation)
        case .ended, .cancelled, .failed:
            onEnded()
        default:
            break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}



#Preview {
    InfiniteCanvasView(store: ProjectStore(), viewport: .constant(ViewportState()), currentScale: .constant(1.0), onNodeAction: nil)
}
