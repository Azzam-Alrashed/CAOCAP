import SwiftUI

extension NodeRole {
    public var icon: String {
        switch self {
        case .srs: return "doc.text.fill"
        case .code: return "chevron.left.slash.chevron.right"
        case .livePreview: return "play.display"
        case .firebase: return "flame.fill"
        case .subCanvas: return "folder.fill"
        case .custom: return "square.grid.2x2.fill"
        }
    }

    public var themeColor: Color {
        matchingNodeType.defaultTheme.color
    }

    private var matchingNodeType: NodeType {
        switch self {
        case .srs: return .srs
        case .code: return .code
        case .livePreview: return .webView
        case .firebase: return .firebase
        case .subCanvas: return .subCanvas
        case .custom: return .standard
        }
    }
}
