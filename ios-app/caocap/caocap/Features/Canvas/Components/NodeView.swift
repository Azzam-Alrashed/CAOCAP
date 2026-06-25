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
                            .fill(
                                LinearGradient(
                                    colors: gradientColors.map { $0.opacity(0.22) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(nodeTitle)
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
                    
                    if let subtitle = nodeSubtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(3)
                    }

                    if node.type == .miniApp, let miniApp = node.miniApp {
                        let state = miniApp.srsReadinessState
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
            .frame(width: node.type == .miniApp ? 240 : nil, alignment: .leading)
            .environment(\.layoutDirection, LocalizationManager.shared.layoutDirection(for: selectedLanguage))
            .padding(.bottom, node.type == .miniApp ? 12 : 0)
            
            NodePreviewContent(
                node: node,
                agentState: agentState,
                themeColor: themeColor
            )
        }
        .padding(.horizontal, node.type == .miniApp ? 12 : 20)
        .padding(.vertical, node.type == .miniApp ? 12 : 20)
        .background(backgroundStack)
        .overlay(borderOverlay)
        .overlay(statusOverlay)
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: NodeFramePreferenceKey.self,
                    value: [node.id: NodeFrameData(
                        nodeId: node.id,
                        frame: geometry.frame(in: .named("canvas")),
                        size: geometry.size
                    )]
                )
            }
        )
        .scaleEffect(isDragging ? 1.05 : (isHovering ? 1.02 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
    }
    
    private var themeColor: Color {
        if node.action == .proSubscription && SubscriptionManager.shared.isSubscribed {
            return .yellow
        }
        return node.theme.color
    }

    private var gradientColors: [Color] {
        if node.action == .proSubscription && SubscriptionManager.shared.isSubscribed {
            return [Color(hex: "FACC15"), Color(hex: "F59E0B")]
        }
        return node.theme.gradientColors
    }

    private var nodeTitle: String {
        if node.action == .proSubscription && SubscriptionManager.shared.isSubscribed {
            return LocalizationManager.shared.localizedString("CAOCAP Pro")
        }
        return node.displayTitle
    }
    
    private var nodeSubtitle: String? {
        if node.action == .proSubscription && SubscriptionManager.shared.isSubscribed {
            return LocalizationManager.shared.localizedString("Manage Subscription")
        }
        return node.displaySubtitle
    }

    private var backgroundStack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors.map { $0.opacity(isDragging ? 0.16 : 0.09) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [gradientColors.first?.opacity(isDragging ? 0.14 : 0.08) ?? .clear, .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 220
                    )
                )
        }
        .shadow(
            color: (gradientColors.first ?? .black).opacity(isDragging ? 0.28 : 0.18),
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
                        gradientColors.last?.opacity(isDragging ? 0.55 : 0.35) ?? themeColor.opacity(0.3),
                        gradientColors.first?.opacity(isDragging ? 0.45 : 0.25) ?? themeColor.opacity(0.2)
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
                case .miniApp:
                    if let html = node.miniApp?.compiledHTML {
                        HTMLWebView(htmlContent: html)
                            .frame(width: 375, height: 667)
                            .scaleEffect(240.0 / 375.0)
                            .frame(width: 240, height: 427)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }

                case .subCanvas:
                    VStack(alignment: .leading, spacing: 8) {
                        Label("SUB-CANVAS", systemImage: "folder.fill")
                            .font(.system(size: 10, weight: .black))
                            .opacity(0.4)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(themeColor)
                            Text("Tap to open")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 12)
                    
                default:
                    EmptyView()
                }
            }
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
