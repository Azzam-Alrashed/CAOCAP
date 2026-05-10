import SwiftUI

struct NodeView: View {
    let node: SpatialNode
    var isDragging: Bool = false
    var agentState: AgentExecutionState = .idle
    @State private var isHovering = false
    @State private var isPulsing = false
    @AppStorage(LocalizationManager.languageStorageKey) private var selectedLanguage = "English"
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Icon / Symbol
                if let icon = node.icon {
                    ZStack {
                        Circle()
                            .fill(themeColor.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(themeColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(node.displayTitle)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            
                        if agentState == .thinking {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else if agentState == .applying {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if agentState == .awaitingReview {
                            Image(systemName: "doc.badge.clock")
                                .foregroundColor(.orange)
                        } else if case .error = agentState {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    if let subtitle = node.displaySubtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(3)
                    }

                    // Show SRS readiness badge for SRS nodes.
                    if node.type == .srs {
                        let state = node.srsReadinessState ?? .empty
                        HStack(spacing: 5) {
                            Image(systemName: state.icon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(state.displayTitle)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(state == .stale ? .orange : themeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((state == .stale ? Color.orange : themeColor).opacity(0.12))
                        .clipShape(Capsule())
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: 240, alignment: .leading)
            }
            .environment(\.layoutDirection, LocalizationManager.shared.layoutDirection(for: selectedLanguage))
            .padding(.bottom, node.type == .webView ? 16 : 0)
            
            NodePreviewContent(node: node, agentState: agentState, themeColor: themeColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(backgroundStack)
        .overlay(borderOverlay)
        .overlay(statusOverlay)
        .scaleEffect(isDragging ? 1.05 : (isHovering ? 1.02 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
    }
    
    private var themeColor: Color {
        node.theme.color
    }

    private var backgroundStack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
            
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isDragging ? themeColor.opacity(0.08) : themeColor.opacity(0.03))
        }
        .shadow(
            color: Color.black.opacity(isDragging ? 0.25 : 0.15),
            radius: isDragging ? 30 : 20,
            x: 0,
            y: isDragging ? 20 : 10
        )
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(isDragging ? 0.6 : 0.3),
                        .white.opacity(0.05),
                        themeColor.opacity(isDragging ? 0.6 : 0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isDragging ? 2 : 1
            )
    }

    private var statusOverlay: some View {
        Group {
            if agentState == .thinking {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.blue.opacity(0.8), lineWidth: 3)
                    .shadow(color: .blue, radius: isPulsing ? 15 : 5)
                    .opacity(isPulsing ? 1.0 : 0.5)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    }
            } else if agentState == .applying {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.green.opacity(0.8), lineWidth: 3)
                    .shadow(color: .green, radius: 15)
            } else if agentState == .awaitingReview {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.orange.opacity(0.8), lineWidth: 3)
                    .shadow(color: .orange, radius: 10)
            } else if case .error = agentState {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.red.opacity(0.8), lineWidth: 3)
                    .shadow(color: .red, radius: 10)
            }
        }
    }
}

private struct NodePreviewContent: View {
    let node: SpatialNode
    let agentState: AgentExecutionState
    let themeColor: Color
    
    var body: some View {
        Group {
            if node.action != nil {
                EmptyView()
            } else {
                switch node.type {
                case .webView:
                    if let html = node.htmlContent {
                        HTMLWebView(htmlContent: html)
                            .frame(height: 200)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.top, 12)
                    }
                    
                case .number:
                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.textContent ?? "0")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(themeColor)
                        
                        Text("NUMBER VALUE")
                            .font(.system(size: 10, weight: .black))
                            .opacity(0.4)
                    }
                    .padding(.top, 12)
                    
                case .text:
                    VStack(alignment: .leading, spacing: 6) {
                        Text(node.textContent ?? "Notes...")
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(4)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("NOTE PREVIEW")
                            .font(.system(size: 10, weight: .black))
                            .opacity(0.4)
                    }
                    .padding(.top, 12)
                    
                case .table:
                    TablePreviewView(textContent: node.textContent ?? "", themeColor: themeColor)
                        .padding(.top, 12)
                    
                case .calculation:
                    HStack(spacing: 12) {
                        Image(systemName: (node.operation ?? .add).icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(themeColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.1f", node.outputValue ?? 0.0))
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                            
                            Text("COMPUTING \(node.operation?.rawValue ?? "+")")
                                .font(.system(size: 9, weight: .bold))
                                .opacity(0.5)
                        }
                    }
                    .padding(.top, 12)
                    
                case .display:
                    DisplayPreviewView(outputValue: node.outputValue ?? 0.0, displayStyle: node.displayStyle ?? .number, themeColor: themeColor)
                        .padding(.top, 12)
                    
                case .aiAgent:
                    VStack(alignment: .leading, spacing: 6) {
                        Label("AGENT OUTPUT", systemImage: "sparkles")
                            .font(.system(size: 10, weight: .black))
                            .opacity(0.4)
                        
                        Text(node.aiResponse ?? "Ready to process...")
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(.primary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(themeColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.top, 12)
                    
                default:
                    EmptyView()
                }
            }
        }
    }
}

private struct TablePreviewView: View {
    let textContent: String
    let themeColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let rows = textContent.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            ForEach(0..<min(rows.count, 5), id: \.self) { rowIndex in
                let columns = rows[rowIndex].components(separatedBy: ",")
                HStack(spacing: 0) {
                    ForEach(0..<min(columns.count, 4), id: \.self) { colIndex in
                        Text(columns[colIndex].trimmingCharacters(in: .whitespaces))
                            .font(.system(size: 10, weight: rowIndex == 0 ? .bold : .medium))
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(rowIndex == 0 ? themeColor.opacity(0.15) : (rowIndex % 2 == 0 ? Color.black.opacity(0.05) : Color.clear))
                            .border(Color.black.opacity(0.05), width: 0.5)
                    }
                }
            }
            
            if rows.count > 5 {
                Text("+ \(rows.count - 5) more rows...")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .cornerRadius(8)
    }
}

private struct DisplayPreviewView: View {
    let outputValue: Double
    let displayStyle: DisplayStyle
    let themeColor: Color
    
    var body: some View {
        VStack(spacing: 8) {
            switch displayStyle {
            case .number:
                Text(String(format: "%.1f", outputValue))
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(themeColor)
            
            case .percentage:
                Text("\(Int(outputValue))%")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(themeColor)
            
            case .progress:
                VStack(spacing: 12) {
                    ProgressView(value: min(max(outputValue, 0), 100), total: 100)
                        .tint(themeColor)
                        .scaleEffect(x: 1, y: 4, anchor: .center)
                        .padding(.horizontal, 10)
                    
                    Text("\(Int(outputValue))/100")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(themeColor)
                }
                .frame(height: 60)
                
            case .gauge:
                ZStack {
                    Circle()
                        .stroke(themeColor.opacity(0.1), lineWidth: 12)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(min(max(outputValue, 0), 100)) / 100.0)
                        .stroke(themeColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(outputValue))")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(themeColor)
                }
                .frame(width: 80, height: 80)
                .padding(.vertical, 8)
            }
            
            Text(displayStyle.displayName.uppercased())
                .font(.system(size: 10, weight: .black))
                .opacity(0.4)
        }
    }
}

#Preview {
    ZStack {
        Color(white: 0.05).ignoresSafeArea()
        NodeView(node: SpatialNode(
            position: .zero,
            title: "Hello, world!",
            subtitle: "Welcome to the future of agentic programming.",
            icon: "sparkles",
            theme: .purple
        ))
    }
}
