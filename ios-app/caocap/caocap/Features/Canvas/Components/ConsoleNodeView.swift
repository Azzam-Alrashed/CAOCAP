import SwiftUI

struct ConsoleNodeView: View {
    let node: SpatialNode
    var isScrollable: Bool = false
    
    @State private var store = ConsoleLogStore.shared
    
    @MainActor
    private var logs: [ConsoleLogEntry] {
        store.filteredLogs
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            
            if isScrollable {
                filterBar
            }
            
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
                .dismissKeyboardOnTap()
            }
        }
        .padding(.top, 12)
        .onDisappear {
            if isScrollable {
                store.filterQuery = ""
                store.filterType = nil
            }
        }
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
    
    private var filterBar: some View {
        VStack(spacing: 10) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                
                TextField("Search logs...", text: $store.filterQuery)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                
                if !store.filterQuery.isEmpty {
                    Button {
                        store.filterQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Level filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "All", type: nil)
                    filterChip(title: "Logs", type: "log")
                    filterChip(title: "Info", type: "info")
                    filterChip(title: "Warnings", type: "warn")
                    filterChip(title: "Errors", type: "error")
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.bottom, 8)
    }
    
    private func filterChip(title: String, type: String?) -> some View {
        let isSelected = store.filterType == type
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                store.filterType = type
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .white : .primary.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.primary.opacity(0.04))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
