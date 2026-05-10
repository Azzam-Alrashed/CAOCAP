import SwiftUI

extension NodeRole {
    var icon: String {
        switch self {
        case .srs: return "doc.text.fill"
        case .code: return "chevron.left.slash.chevron.right"
        case .html: return "chevron.left.slash.chevron.right"
        case .css: return "number"
        case .javascript: return "curlybraces"
        case .livePreview: return "play.display"
        case .text: return "text.cursor"
        case .calculation: return "plus.forwardslash.minus"
        case .display: return "opticaldisc.fill"
        case .aiAgent: return "brain.head.profile.fill"
        case .chart: return "chart.line.uptrend.xyaxis"
        case .custom: return "square.grid.2x2.fill"
        }
    }
    
    var themeColor: Color {
        switch self {
        case .srs: return .blue
        case .code: return .orange
        case .html: return .orange
        case .css: return .pink
        case .javascript: return .yellow
        case .livePreview: return .green
        case .text: return .blue
        case .calculation: return .orange
        case .display: return .green
        case .aiAgent: return .indigo
        case .chart: return .purple
        case .custom: return .purple
        }
    }
}
