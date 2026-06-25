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
        switch self {
        case .srs: return .blue
        case .code: return .orange
        case .livePreview: return .green
        case .firebase: return .orange
        case .subCanvas: return .cyan
        case .custom: return .purple
        }
    }
}
