import SwiftUI

extension NodeRole {
    public var icon: String {
        switch self {
        case .miniApp: return "app.connected.to.app.below.fill"
        case .subCanvas: return "folder.fill"
        case .custom: return "square.grid.2x2.fill"
        }
    }

    public var themeColor: Color {
        matchingNodeType.defaultTheme.color
    }

    private var matchingNodeType: NodeType {
        switch self {
        case .miniApp: return .miniApp
        case .subCanvas: return .subCanvas
        case .custom: return .standard
        }
    }
}
