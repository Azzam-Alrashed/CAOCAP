import SwiftUI
import UIKit

/// Renders one spatial workspace and owns the transient gesture state needed to
/// pan, zoom, select, and drag nodes without changing the durable project model
/// until a gesture is committed.
struct InfiniteCanvasView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(OnboardingCoordinator.self) private var onboarding: OnboardingCoordinator?
    
    /// Tracks the current panning and zooming state of the canvas.
    @Binding var viewport: ViewportState
    
    /// Real-time scale feedback for external overlays.
    @Binding var currentScale: CGFloat
    
    /// The central store managing node data and persistence.
    var store: ProjectStore
    
    /// Node to pulse-highlight after fly-to navigation from CoCaptain or search.
    var canvasFocusNodeID: UUID?
    var commandPalette: CommandPaletteViewModel? = nil
    
    /// Callback triggered when a specialized action node is tapped. Its
    /// presence also marks the canvas as non-persistent onboarding mode.
    var onNodeAction: ((NodeAction) -> Void)? = nil
    
    var onNavigateToSubCanvas: ((String) -> Void)? = nil
    var onRecoverUnsupportedProject: (() -> Void)? = nil
    var onFlyToNode: ((UUID) -> Void)? = nil
    
    init(
        store: ProjectStore,
        viewport: Binding<ViewportState>,
        currentScale: Binding<CGFloat>,
        canvasFocusNodeID: UUID? = nil,
        commandPalette: CommandPaletteViewModel? = nil,
        onNodeAction: ((NodeAction) -> Void)? = nil,
        onNavigateToSubCanvas: ((String) -> Void)? = nil,
        onRecoverUnsupportedProject: (() -> Void)? = nil,
        onFlyToNode: ((UUID) -> Void)? = nil
    ) {
        self.store = store
        self._viewport = viewport
        self._currentScale = currentScale
        self.canvasFocusNodeID = canvasFocusNodeID
        self.commandPalette = commandPalette
        self.onNodeAction = onNodeAction
        self.onNavigateToSubCanvas = onNavigateToSubCanvas
        self.onRecoverUnsupportedProject = onRecoverUnsupportedProject
        self.onFlyToNode = onFlyToNode
    }
    
    // Drag offsets stay local until the drag ends so links and nodes can track
    // the finger smoothly without writing every intermediate frame to ProjectStore.
    
    /// The node currently presented in the detail sheet context menu/inspector.
    @State private var selectedNode: SpatialNode?
    /// The mini-app node currently presented in a full-screen editing experience.
    @State private var presentedMiniApp: SpatialNode?
    /// Temporary translation offsets applied to nodes currently being dragged.
    @State private var nodeDragOffsets: [UUID: CGSize] = [:]
    /// Flag indicating an active node drag, used to disable canvas panning during the gesture.
    @State private var isDraggingNode = false
    /// Caches rendered dimensions of nodes to calculate precise fly-to padding.
    @State private var nodeFrames: [UUID: NodeFrameData] = [:]

    private var shouldAnchorTutorialNode: Bool {
        guard let step = onboarding?.currentStep else { return false }
        return step == .openTutorial || step == .openPortal
    }
    
    var body: some View {
        GeometryReader { geometry in
            // Node positions are stored as offsets from the visible center, so
            // the center point is the bridge between canvas-space and screen-space.
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // Layer 1: The Infinite Dotted Grid
                DottedBackground(offset: viewport.offset, scale: viewport.scale)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                viewport.handleDragChanged(value)
                            }
                            .onEnded { _ in
                                viewport.handleDragEnded()
                                persistViewportIfNeeded()
                                completeOnboardingPanIfNeeded()
                            }
                    )
                
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
                    
                    CanvasNodeLayer(
                        nodes: store.nodes,
                        activeAgentStates: store.activeAgentStates,
                        nodeDragOffsets: nodeDragOffsets,
                        focusedNodeID: canvasFocusNodeID,
                        containerSize: geometry.size,
                        onTap: handleNodeTap,
                        onDoubleTap: handleNodeDoubleTap,
                        onDelete: handleNodeDelete,
                        onInspect: handleNodeInspect,
                        onDragChanged: handleNodeDragChanged,
                        onDragEnded: handleNodeDragEnded
                    )
                    .equatable()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(viewport.scale)
                .offset(viewport.offset)

                if let message = store.unsupportedProjectMessage {
                    UnsupportedProjectCard(
                        message: message,
                        onCreateFreshCanvas: { onRecoverUnsupportedProject?() }
                    )
                    .frame(maxWidth: 460)
                    .padding(24)
                }

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(name: "canvas")
            .onboardingExplicitAnchorFrames(canvasExplicitAnchorFrames(canvasSize: geometry.size))
            .contentShape(Rectangle()) // Ensure the entire area is gesture-sensitive.
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                    viewport.fitTo(nodes: store.nodes, containerSize: geometry.size)
                }
                HapticsManager.shared.trigger(.medium)
                if onboarding?.currentStep == .fitAllNodes {
                    onboarding?.completeCurrentStep()
                }
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
                        completeOnboardingPanIfNeeded()
                    }
                )
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
                        completeOnboardingPinchIfNeeded()
                    }
            )
            .onPreferenceChange(NodeFramePreferenceKey.self) { value in
                nodeFrames = value
            }
        }
        .background(backgroundColor)
        .onboardingTooltipOverlay(
            isCommandPalettePresented: commandPalette?.isPresented ?? false,
            rendersAnchor: { $0.isCanvasLocal }
        )
        .edgesIgnoringSafeArea(.all)
        .sheet(item: $selectedNode) { node in
            NodeDetailView(
                node: node,
                store: store,
                commandPalette: commandPalette,
                onFlyToNode: handleFlyToFromDetail
            )
        }
        .sheet(item: $presentedMiniApp) { node in
            NodeDetailView(
                node: node,
                store: store,
                commandPalette: commandPalette,
                onFlyToNode: handleFlyToFromDetail
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            currentScale = viewport.scale
        }
        .onChange(of: presentedMiniApp?.id) { _, nodeID in
            guard nodeID == TutorialCanvasProvider.miniAppNodeID,
                  onboarding?.currentStep == .tapMiniAppNode else { return }
            onboarding?.completeCurrentStep()
        }
        .onChange(of: onboarding?.showPopover ?? false) { _, showPopover in
            guard showPopover == true,
                  let onboarding,
                  let step = onboarding.currentStep,
                  step == .panCanvas || step == .pinchZoom else { return }
            onboarding.captureGestureBaseline(offset: viewport.offset, scale: viewport.scale)
        }
    }
    
    private func completeOnboardingPanIfNeeded() {
        guard let onboarding, onboarding.currentStep == .panCanvas else { return }
        if OnboardingNavigationGestureThresholds.didMeetPanThreshold(
            from: onboarding.gestureStepBaselineOffset,
            to: viewport.offset
        ) {
            onboarding.completeCurrentStep()
        }
    }

    private func completeOnboardingPinchIfNeeded() {
        guard let onboarding, onboarding.currentStep == .pinchZoom else { return }
        if OnboardingNavigationGestureThresholds.didMeetPinchThreshold(
            from: onboarding.gestureStepBaselineScale,
            to: viewport.scale
        ) {
            onboarding.completeCurrentStep()
        }
    }

    private func completeOnboardingDragIfNeeded(translation: CGSize) {
        guard let onboarding, onboarding.currentStep == .dragCanvasNode else { return }
        let distance = hypot(translation.width, translation.height)
        if distance >= OnboardingNavigationGestureThresholds.minimumPanDistance {
            onboarding.completeCurrentStep()
        }
    }

    private func canvasExplicitAnchorFrames(canvasSize: CGSize) -> [OnboardingTooltipAnchor: CGRect] {
        var frames: [OnboardingTooltipAnchor: CGRect] = [
            .canvasGestureArea: CGRect(origin: .zero, size: canvasSize)
        ]

        if shouldAnchorTutorialNode,
           let frameData = nodeFrames[RootCanvasProvider.tutorialNodeID] {
            frames[.tutorialNode] = frameData.frame
        }

        if onboarding?.currentStep == .openPortal {
            if let frameData = nodeFrames[RootCanvasProvider.pacManNodeID] {
                frames[.demoGameNode] = frameData.frame
            } else if let frameData = nodeFrames[RootCanvasProvider.xoNodeID] {
                frames[.demoGameNode] = frameData.frame
            }
        }

        if let step = onboarding?.currentStep,
           step == .tapMiniAppNode || step == .dragCanvasNode,
           let frameData = nodeFrames[TutorialCanvasProvider.miniAppNodeID] {
            frames[.practiceCanvasNode] = frameData.frame
        }

        return frames
    }

    private func handleNodeTap(_ node: SpatialNode) {
        if let action = node.action {
            onNodeAction?(action)
        } else if node.type == .subCanvas, let fileName = node.linkedCanvasFileName {
            onNavigateToSubCanvas?(fileName)
        } else if node.type == .miniApp {
            presentedMiniApp = node
        } else {
            selectedNode = node
        }
    }

    private func handleNodeDoubleTap(_ node: SpatialNode, containerSize: CGSize) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            let targetScale = computeTargetScale(for: node.id, containerSize: containerSize)
            viewport.flyTo(
                nodePosition: node.position,
                containerSize: containerSize,
                targetScale: targetScale
            )
        }
        HapticsManager.shared.trigger(.medium)
    }

    private func handleNodeDelete(_ node: SpatialNode) {
        HapticsManager.shared.notification(.warning)
        store.deleteNode(id: node.id, persist: true)
    }

    private func handleNodeInspect(_ node: SpatialNode) {
        selectedNode = node
    }

    private func handleNodeDragChanged(_ node: SpatialNode, translation: CGSize) {
        isDraggingNode = true
        nodeDragOffsets[node.id] = canvasTranslation(for: translation)
    }

    private func handleNodeDragEnded(_ node: SpatialNode, translation: CGSize) {
        let canvasTranslation = canvasTranslation(for: translation)
        let finalPosition = CGPoint(
            x: node.position.x + canvasTranslation.width,
            y: node.position.y + canvasTranslation.height
        )

        store.updateNodePosition(
            id: node.id,
            position: finalPosition,
            persist: true
        )

        completeOnboardingDragIfNeeded(translation: canvasTranslation)

        nodeDragOffsets[node.id] = nil
        isDraggingNode = false
        HapticsManager.shared.selectionChanged()
    }
    
    /// Resolves the color of the infinite canvas background grid.
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.05) : Color(white: 0.95)
    }

    /// Flushes the transient gesture scale and offset to the `ProjectStore`.
    private func persistViewportIfNeeded() {
        store.updateViewport(
            offset: viewport.offset,
            scale: viewport.scale,
            persist: true
        )
    }

    /// Dismisses node detail chrome, then flies the workspace camera to the target node.
    private func handleFlyToFromDetail(_ nodeID: UUID) {
        selectedNode = nil
        presentedMiniApp = nil
        onFlyToNode?(nodeID)
    }

    /// Converts screen-space gesture movement into the unscaled coordinate
    /// system used by node positions and connection offsets.
    private func canvasTranslation(for translation: CGSize) -> CGSize {
        CGSize(
            width: translation.width / viewport.scale,
            height: translation.height / viewport.scale
        )
    }

    /// Computes the exact zoom level required to fit a specific node within the screen bounds.
    /// - Parameters:
    ///   - nodeId: The ID of the node to frame.
    ///   - containerSize: The physical screen dimensions available.
    /// - Returns: A zoom scale factor capped at 1.2x.
    private func computeTargetScale(for nodeId: UUID, containerSize: CGSize) -> CGFloat {
        guard let frameData = nodeFrames[nodeId], containerSize != .zero else {
            return 1.0
        }
        let paddingFactor: CGFloat = 0.8
        let scaleX = (containerSize.width * paddingFactor) / frameData.size.width
        let scaleY = (containerSize.height * paddingFactor) / frameData.size.height
        return min(min(scaleX, scaleY), 1.2)
    }
}

/// Renders every node and its interaction modifiers behind a single equality
/// boundary so viewport-only updates can reuse the complete node hierarchy.
private struct CanvasNodeLayer: View, Equatable {
    let nodes: [SpatialNode]
    let activeAgentStates: [UUID: AgentExecutionState]
    let nodeDragOffsets: [UUID: CGSize]
    let focusedNodeID: UUID?
    let containerSize: CGSize
    let onTap: (SpatialNode) -> Void
    let onDoubleTap: (SpatialNode, CGSize) -> Void
    let onDelete: (SpatialNode) -> Void
    let onInspect: (SpatialNode) -> Void
    let onDragChanged: (SpatialNode, CGSize) -> Void
    let onDragEnded: (SpatialNode, CGSize) -> Void

    static func == (lhs: CanvasNodeLayer, rhs: CanvasNodeLayer) -> Bool {
        lhs.nodes == rhs.nodes
            && lhs.activeAgentStates == rhs.activeAgentStates
            && lhs.nodeDragOffsets == rhs.nodeDragOffsets
            && lhs.focusedNodeID == rhs.focusedNodeID
            && lhs.containerSize == rhs.containerSize
    }

    var body: some View {
        ForEach(nodes) { node in
            spatialNode(node)
        }
    }

    private func spatialNode(_ node: SpatialNode) -> some View {
        let currentOffset = nodeDragOffsets[node.id] ?? .zero
        let isDragging = nodeDragOffsets[node.id] != nil

        return NodeView(
            node: node,
            isDragging: isDragging,
            agentState: activeAgentStates[node.id] ?? .idle,
            isTransientlyFocused: focusedNodeID == node.id
        )
        .equatable()
        .offset(
            x: node.position.x + currentOffset.width,
            y: node.position.y + currentOffset.height
        )
        .zIndex(isDragging ? 1 : 0)
        .onTapGesture(count: 2) {
            onDoubleTap(node, containerSize)
        }
        .onTapGesture {
            onTap(node)
        }
        .contextMenu(menuItems: {
            if !node.isProtected {
                Button(role: .destructive) {
                    onDelete(node)
                } label: {
                    Label("Delete Node", systemImage: "trash")
                }
            }

            Button {
                onInspect(node)
            } label: {
                Label("Inspect", systemImage: "info.circle")
            }
        }, preview: {
            NodeView(node: node)
                .environment(\.colorScheme, .dark)
                .frame(width: 280)
                .padding()
        })
        .gesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .named("canvas"))
                .onChanged { value in
                    onDragChanged(node, value.translation)
                }
                .onEnded { value in
                    onDragEnded(node, value.translation)
                }
        )
    }
}

/// A custom UIKit pan gesture wrapper specifically for two-finger trackpad panning on iPadOS/macOS.
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

/// An overlay view displayed when the current project file contains schema elements
/// this version of CAOCAP does not understand, offering the user a safe escape hatch.
private struct UnsupportedProjectCard: View {
    let message: String
    let onCreateFreshCanvas: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Project format changed", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onCreateFreshCanvas) {
                Label("Create Fresh Mini-App Canvas", systemImage: "plus.square.fill")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(22)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
    }
}
