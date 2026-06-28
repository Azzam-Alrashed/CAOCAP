import CoreGraphics
import Foundation

/// Canonical launch canvas and the stable filenames used by its curated portals.
public enum RootCanvasProvider {
    public static let tutorialFileName = "canvas_tutorial.json"
    public static let pacManFileName = "canvas_pacman.json"

    public static let tutorialNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-000000000001")!
    public static let pacManNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-000000000002")!
    public static let profileNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-000000000003")!
    public static let settingsNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-000000000004")!
    public static let proNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-000000000005")!
    public static let activityNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-000000000006")!

    private static let verticalSpacing: CGFloat = 220

    static func verticalColumnPosition(index: Int, count: Int) -> CGPoint {
        let totalHeight = CGFloat(count - 1) * verticalSpacing
        let startY = -totalHeight / 2
        return CGPoint(x: 0, y: startY + CGFloat(index) * verticalSpacing)
    }

    public static var nodes: [SpatialNode] {
        let count = 6
        return [
            SpatialNode(
                id: activityNodeID,
                position: verticalColumnPosition(index: 0, count: count),
                title: "Activity",
                subtitle: "Saved changes across all canvases",
                icon: "chart.bar.xaxis",
                theme: .green,
                action: .openActivity
            ),
            SpatialNode(
                id: profileNodeID,
                position: verticalColumnPosition(index: 1, count: count),
                title: "Profile",
                subtitle: "Account & Preferences",
                icon: "person.crop.circle.fill",
                theme: .blue,
                action: .openProfile
            ),
            SpatialNode(
                id: proNodeID,
                position: verticalColumnPosition(index: 2, count: count),
                title: "Pro Subscription",
                subtitle: "Unlock CoCaptain & Premium Features",
                icon: "crown.fill",
                theme: .indigo,
                action: .proSubscription
            ),
            SpatialNode(
                id: settingsNodeID,
                position: verticalColumnPosition(index: 3, count: count),
                title: "Settings",
                subtitle: "App Tools & Config",
                icon: "gearshape.fill",
                theme: .orange,
                action: .openSettings
            ),
            SpatialNode(
                id: tutorialNodeID,
                type: .subCanvas,
                position: verticalColumnPosition(index: 4, count: count),
                title: "Tutorial",
                subtitle: "Learn CAOCAP by using it",
                icon: "graduationcap.fill",
                theme: .green,
                linkedCanvasFileName: tutorialFileName
            ),
            SpatialNode(
                id: pacManNodeID,
                type: .subCanvas,
                position: verticalColumnPosition(index: 5, count: count),
                title: "Pac-Man",
                subtitle: "A mobile-ready Mini-App",
                icon: "gamecontroller.fill",
                theme: .purple,
                linkedCanvasFileName: pacManFileName
            )
        ]
    }

    public static var snapshot: ProjectSnapshot {
        ProjectSnapshot(
            projectName: "Root",
            nodes: nodes,
            viewportOffset: .zero,
            viewportScale: 0.5
        )
    }
}
