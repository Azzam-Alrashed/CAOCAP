import CoreGraphics

/// The tutorial workspace stays uncluttered while the anchored onboarding steps
/// teach the user through the app's real controls.
public enum TutorialCanvasProvider {
    public static var snapshot: ProjectSnapshot {
        ProjectSnapshot(
            projectName: "Tutorial",
            nodes: [],
            viewportOffset: .zero,
            viewportScale: 1
        )
    }
}
