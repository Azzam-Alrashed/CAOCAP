import CoreGraphics
import Foundation

/// Canonical launch canvas and the stable filenames used by its curated portals.
public enum RootCanvasProvider {
    public static let tutorialFileName = "canvas_tutorial.json"
    public static let pacManFileName = "canvas_pacman.json"
    public static let xoFileName = "canvas_xo.json"

    public static let tutorialNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-000000000001")!
    public static let pacManNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-000000000002")!
    public static let profileNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-000000000003")!
    public static let settingsNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-000000000004")!
    public static let proNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-000000000005")!
    public static let activityNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-000000000006")!
    public static let dailyNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-000000000007")!
    public static let xoNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-000000000008")!
    public static let whatsAppNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-000000000009")!
    public static let helpNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-00000000000A")!
    public static let appIconNodeID = UUID(uuidString: "CA0CA001-0000-4000-8000-00000000000B")!

    /// Default root zoom that frames the 2×4 grid plus top/bottom anchor nodes on phone.
    public static let defaultViewportScale: CGFloat = 0.45

    private static let verticalSpacing: CGFloat = 220
    private static let columnSpacing: CGFloat = 250
    private static let rowCount = 4

    /// Y offset for anchor nodes placed above or below the launch grid.
    static var anchorRowYOffset: CGFloat {
        gridRowY[rowCount - 1] + verticalSpacing
    }

    static var topAnchorY: CGFloat {
        gridRowY[0] - verticalSpacing
    }

    static func verticalColumnPosition(index: Int, count: Int) -> CGPoint {
        let totalHeight = CGFloat(count - 1) * verticalSpacing
        let startY = -totalHeight / 2
        return CGPoint(x: 0, y: startY + CGFloat(index) * verticalSpacing)
    }

    private static var gridRowY: [CGFloat] {
        let totalHeight = CGFloat(rowCount - 1) * verticalSpacing
        let startY = -totalHeight / 2
        return (0..<rowCount).map { startY + CGFloat($0) * verticalSpacing }
    }

    static func gridPosition(column: Int, row: Int) -> CGPoint {
        let x = column == 0 ? -columnSpacing : columnSpacing
        return CGPoint(x: x, y: gridRowY[row])
    }

    /// Positions from the pre-grid two-column constellation (v6).
    static func legacyConstellationPosition(for nodeID: UUID) -> CGPoint? {
        let legacyRowY: [CGFloat] = [-220, 0, 220]
        switch nodeID {
        case proNodeID:
            return CGPoint(x: -columnSpacing, y: legacyRowY[0])
        case settingsNodeID:
            return CGPoint(x: -columnSpacing, y: legacyRowY[1])
        case profileNodeID:
            return CGPoint(x: -columnSpacing, y: legacyRowY[2])
        case tutorialNodeID:
            return CGPoint(x: columnSpacing, y: legacyRowY[0])
        case pacManNodeID:
            return CGPoint(x: columnSpacing, y: legacyRowY[1])
        case dailyNodeID:
            return CGPoint(x: columnSpacing, y: legacyRowY[2])
        case activityNodeID:
            return CGPoint(x: 0, y: legacyRowY[2] + verticalSpacing)
        default:
            return nil
        }
    }

    static func gridPosition(for nodeID: UUID) -> CGPoint {
        switch nodeID {
        case proNodeID:
            gridPosition(column: 0, row: 0)
        case settingsNodeID:
            gridPosition(column: 0, row: 1)
        case profileNodeID:
            gridPosition(column: 0, row: 2)
        case activityNodeID:
            gridPosition(column: 0, row: 3)
        case tutorialNodeID:
            gridPosition(column: 1, row: 0)
        case pacManNodeID:
            gridPosition(column: 1, row: 1)
        case xoNodeID:
            gridPosition(column: 1, row: 2)
        case dailyNodeID:
            gridPosition(column: 1, row: 3)
        case whatsAppNodeID:
            CGPoint(x: 0, y: topAnchorY)
        case appIconNodeID:
            CGPoint(x: -columnSpacing, y: topAnchorY)
        case helpNodeID:
            CGPoint(x: 0, y: anchorRowYOffset)
        default:
            .zero
        }
    }

    public static var nodes: [SpatialNode] {
        return [
            SpatialNode(
                id: proNodeID,
                position: gridPosition(for: proNodeID),
                title: "Pro Subscription",
                subtitle: "Unlock CoCaptain & Premium Features",
                icon: "crown.fill",
                theme: .orange,
                action: .proSubscription
            ),
            SpatialNode(
                id: settingsNodeID,
                position: gridPosition(for: settingsNodeID),
                title: "Settings",
                subtitle: "App Tools & Config",
                icon: "gearshape.fill",
                theme: .pink,
                action: .openSettings
            ),
            SpatialNode(
                id: profileNodeID,
                position: gridPosition(for: profileNodeID),
                title: "Profile",
                subtitle: "Account & Preferences",
                icon: "person.crop.circle.fill",
                theme: .blue,
                action: .openProfile
            ),
            SpatialNode(
                id: activityNodeID,
                position: gridPosition(for: activityNodeID),
                title: "Activity",
                subtitle: "Saved changes across all canvases",
                icon: "chart.bar.xaxis",
                theme: .cyan,
                action: .openActivity
            ),
            SpatialNode(
                id: tutorialNodeID,
                type: .subCanvas,
                position: gridPosition(for: tutorialNodeID),
                title: "Tutorial",
                subtitle: "Learn CAOCAP by using it",
                icon: "graduationcap.fill",
                theme: .green,
                linkedCanvasFileName: tutorialFileName
            ),
            SpatialNode(
                id: pacManNodeID,
                type: .subCanvas,
                position: gridPosition(for: pacManNodeID),
                title: "Pac-Man",
                subtitle: "A mobile-ready Mini-App",
                icon: "gamecontroller.fill",
                theme: .purple,
                linkedCanvasFileName: pacManFileName
            ),
            SpatialNode(
                id: xoNodeID,
                type: .subCanvas,
                position: gridPosition(for: xoNodeID),
                title: "XO",
                subtitle: "Classic tic-tac-toe Mini-App",
                icon: "square.grid.3x3.fill",
                theme: .secondary,
                linkedCanvasFileName: xoFileName
            ),
            SpatialNode(
                id: dailyNodeID,
                position: gridPosition(for: dailyNodeID),
                title: "Daily",
                subtitle: "Today's building challenges",
                icon: "rosette",
                theme: .indigo,
                action: .openDaily
            ),
            SpatialNode(
                id: whatsAppNodeID,
                position: gridPosition(for: whatsAppNodeID),
                title: "WhatsApp",
                subtitle: "Message Azzam directly",
                icon: "message.fill",
                theme: .green,
                action: .openWhatsApp
            ),
            SpatialNode(
                id: appIconNodeID,
                position: gridPosition(for: appIconNodeID),
                title: "App Icon",
                subtitle: "Choose your home screen look",
                icon: "app.fill",
                theme: .secondary,
                action: .openAppIcon
            ),
            SpatialNode(
                id: helpNodeID,
                position: gridPosition(for: helpNodeID),
                title: "Help",
                subtitle: "Tutorials, shortcuts, and guides",
                icon: "book.fill",
                theme: .indigo,
                action: .openHelp
            )
        ]
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
