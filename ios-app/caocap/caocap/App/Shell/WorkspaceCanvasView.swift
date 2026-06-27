import SwiftUI

/// Shared canvas shell for root and project workspaces.
struct WorkspaceCanvasView: View {
    let store: ProjectStore
    let canvasID: String
    @Binding var viewport: ViewportState
    @Binding var currentScale: CGFloat
    let onNodeAction: (NodeAction) -> Void
    let onNavigateToSubCanvas: (String) -> Void
    let onRecoverUnsupportedProject: () -> Void

    var body: some View {
        InfiniteCanvasView(
            store: store,
            viewport: $viewport,
            currentScale: $currentScale,
            onNodeAction: onNodeAction,
            onNavigateToSubCanvas: onNavigateToSubCanvas,
            onRecoverUnsupportedProject: onRecoverUnsupportedProject
        )
        .id(canvasID)
    }
}
