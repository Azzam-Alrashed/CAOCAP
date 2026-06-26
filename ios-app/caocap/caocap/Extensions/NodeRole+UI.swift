import SwiftUI

/// UI presentation properties for `NodeRole`.
/// Keeps SF Symbol icon names and accent colors co-located with the role they represent.
extension NodeRole {
    /// SF Symbol name representing this role in the canvas node header and pickers.
    public var icon: String {
        switch self {
        case .miniApp: return "app.connected.to.app.below.fill"
        case .subCanvas: return "folder.fill"
        case .custom: return "square.grid.2x2.fill"
        }
    }

    /// Primary accent color derived from the role's canonical `NodeType` default theme.
    public var themeColor: Color {
        matchingNodeType.defaultTheme.color
    }

    /// Maps a `NodeRole` to its canonical `NodeType` so default theme colors can be
    /// looked up without duplicating the theme-to-role mapping.
    private var matchingNodeType: NodeType {
        switch self {
        case .miniApp: return .miniApp
        case .subCanvas: return .subCanvas
        case .custom: return .standard
        }
    }
}
