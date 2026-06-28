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
    public static let dailyNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-000000000007")!

    private static let verticalSpacing: CGFloat = 220
    private static let columnSpacing: CGFloat = 250
    private static let rowY: [CGFloat] = [-220, 0, 220]

    static func verticalColumnPosition(index: Int, count: Int) -> CGPoint {
        let totalHeight = CGFloat(count - 1) * verticalSpacing
        let startY = -totalHeight / 2
        return CGPoint(x: 0, y: startY + CGFloat(index) * verticalSpacing)
    }

    static func constellationPosition(for nodeID: UUID) -> CGPoint {
        switch nodeID {
        case proNodeID:
            CGPoint(x: -columnSpacing, y: rowY[0])
        case settingsNodeID:
            CGPoint(x: -columnSpacing, y: rowY[1])
        case profileNodeID:
            CGPoint(x: -columnSpacing, y: rowY[2])
        case tutorialNodeID:
            CGPoint(x: columnSpacing, y: rowY[0])
        case pacManNodeID:
            CGPoint(x: columnSpacing, y: rowY[1])
        case dailyNodeID:
            CGPoint(x: columnSpacing, y: rowY[2])
        case activityNodeID:
            CGPoint(x: 0, y: rowY[2] + verticalSpacing)
        default:
            .zero
        }
    }

    public static var nodes: [SpatialNode] {
        return [
            SpatialNode(
                id: profileNodeID,
                position: constellationPosition(for: profileNodeID),
                title: "Profile",
                subtitle: "Account & Preferences",
                icon: "person.crop.circle.fill",
                theme: .blue,
                action: .openProfile
            ),
            SpatialNode(
                id: proNodeID,
                position: constellationPosition(for: proNodeID),
                title: "Pro Subscription",
                subtitle: "Unlock CoCaptain & Premium Features",
                icon: "crown.fill",
                theme: .orange,
                action: .proSubscription
            ),
            SpatialNode(
                id: settingsNodeID,
                position: constellationPosition(for: settingsNodeID),
                title: "Settings",
                subtitle: "App Tools & Config",
                icon: "gearshape.fill",
                theme: .pink,
                action: .openSettings
            ),
            SpatialNode(
                id: pacManNodeID,
                type: .subCanvas,
                position: constellationPosition(for: pacManNodeID),
                title: "Pac-Man",
                subtitle: "A mobile-ready Mini-App",
                icon: "gamecontroller.fill",
                theme: .purple,
                linkedCanvasFileName: pacManFileName
            ),
            SpatialNode(
                id: tutorialNodeID,
                type: .subCanvas,
                position: constellationPosition(for: tutorialNodeID),
                title: "Tutorial",
                subtitle: "Learn CAOCAP by using it",
                icon: "graduationcap.fill",
                theme: .green,
                linkedCanvasFileName: tutorialFileName
            ),
            SpatialNode(
                id: dailyNodeID,
                position: constellationPosition(for: dailyNodeID),
                title: "Daily",
                subtitle: "Today's building challenges",
                icon: "rosette",
                theme: .indigo,
                action: .openDaily
            ),
            SpatialNode(
                id: activityNodeID,
                position: constellationPosition(for: activityNodeID),
                title: "Activity",
                subtitle: "Saved changes across all canvases",
                icon: "chart.bar.xaxis",
                theme: .cyan,
                action: .openActivity
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
