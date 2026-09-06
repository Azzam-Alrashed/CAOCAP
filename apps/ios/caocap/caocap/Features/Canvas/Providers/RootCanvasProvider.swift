import CoreGraphics
import Foundation

/// Empty home canvas. Launch cards and old grid math are gone.
public enum RootCanvasProvider {
    /// Default zoom for the empty home canvas. `1.0` crops to the center crosshairs.
    public static let defaultViewportScale: CGFloat = 0.22

    public static var nodes: [SpatialNode] {
        []
    }

    public static var snapshot: ProjectSnapshot {
        ProjectSnapshot(
            projectName: "Root",
            nodes: nodes,
            viewportOffset: .zero,
            viewportScale: defaultViewportScale
        )
    }
}
