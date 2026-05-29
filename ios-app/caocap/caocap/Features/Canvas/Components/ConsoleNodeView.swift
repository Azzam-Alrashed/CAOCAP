import SwiftUI

struct ConsoleNodeView: View {
    let node: SpatialNode
    var isScrollable: Bool = false
    
    @MainActor
    private var logs: [ConsoleLogEntry] {
        ConsoleLogStore.shared.logs
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            
            if logs.isEmpty {
                emptyState
            } else {
                let displayedLogs = isScrollable ? logs : Array(logs.suffix(6))
                
                VStack(spacing: 4) {
                    ForEach(displayedLogs) { entry in
                        logRow(for: entry)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 12)
    }
    
    private var headerRow: some View {
        HStack {
            Label(
                "CONSOLE OUTPUT",
                systemImage: "terminal.fill"
            )
            .font(.system(size: 10, weight: .black))
            .opacity(0.4)
            
            Spacer()
            
            if !logs.isEmpty {
                Button {
                    Task { @MainActor in
                        ConsoleLogStore.shared.clear()
                    }
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red.opacity(0.7))
                        .padding(4)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 24))
                .foregroundColor(node.theme.color.opacity(0.3))
            
            Text("Console is empty")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(Color.black.opacity(0.05))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func logRow(for entry: ConsoleLogEntry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: iconName(for: entry.type))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color(for: entry.type))
                .padding(.top, 2)
            
            Text(entry.message)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(textColor(for: entry.type))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(backgroundColor(for: entry.type))
        .cornerRadius(6)
    }
    
    private func iconName(for type: String) -> String {
        switch type {
        case "error": return "exclamationmark.octagon.fill"
        case "warn": return "exclamationmark.triangle.fill"
        case "info": return "info.circle.fill"
        default: return "chevron.right"
        }
    }
    
    private func color(for type: String) -> Color {
        switch type {
        case "error": return .red
        case "warn": return .orange
        case "info": return .blue
        default: return .secondary
        }
    }
    
    private func textColor(for type: String) -> Color {
        switch type {
        case "error": return .red
        case "warn": return .orange
        case "info": return .blue
        default: return .primary
        }
    }
    
    private func backgroundColor(for type: String) -> Color {
        switch type {
        case "error": return Color.red.opacity(0.08)
        case "warn": return Color.orange.opacity(0.08)
        case "info": return Color.blue.opacity(0.08)
        default: return Color.primary.opacity(0.03)
        }
    }
}
