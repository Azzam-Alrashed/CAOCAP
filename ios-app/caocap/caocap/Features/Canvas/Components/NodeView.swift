import SwiftUI

/// The primary card-shaped visual representation of a `SpatialNode` on the canvas.
/// Renders the node's icon, title, subtitle, SRS readiness badge, and — for
/// Mini-App nodes — a scaled live HTML preview. Applies glass-morphism styling and
/// animated overlays that reflect the current CoCaptain agent execution state.
struct NodeView: View {
    /// The underlying domain model whose data is displayed.
    let node: SpatialNode
    /// `true` while the user is actively dragging this node; drives slightly
    /// elevated scale and shadow to convey "lifted" state.
    var isDragging: Bool = false
    /// Current agent execution state for this node, controls badge icons and
    /// pulsing border overlays.
    var agentState: AgentExecutionState = .idle
    @State private var isHovering = false
    /// Drives the repeating animation of the "thinking" state border overlay.
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
                themeColor: themeColor,
                activityStore: ActivityStore.shared,
                gamificationStore: GamificationStore.shared
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
    
    /// The accent color used for badge tinting, border gradients, and icon fills.
    /// Overrides the node's theme color with yellow when the user holds an active
    /// Pro subscription and this is the Pro upsell node.
    private var themeColor: Color {
        if node.action == .proSubscription && SubscriptionManager.shared.isSubscribed {
            return .yellow
        }
        return node.theme.color
    }

    /// Gradient color pair used for the icon background, card gradient, and shadow.
    /// Uses gold tones for the Pro upsell node when the user is already subscribed.
    private var gradientColors: [Color] {
        if node.action == .proSubscription && SubscriptionManager.shared.isSubscribed {
            return [Color(hex: "FACC15"), Color(hex: "F59E0B")]
        }
        return node.theme.gradientColors
    }

    /// The text shown in the title row, overridden for the Pro upsell node when
    /// the user is already subscribed (to show "CAOCAP Pro" instead of the raw title).
    private var nodeTitle: String {
        if node.action == .proSubscription && SubscriptionManager.shared.isSubscribed {
            return LocalizationManager.shared.localizedString("CAOCAP Pro")
        }
        return node.displayTitle
    }
    
    /// The text shown below the title, overridden for the Pro upsell node when
    /// the user is already subscribed (to show "Manage Subscription").
    private var nodeSubtitle: String? {
        if node.action == .proSubscription && SubscriptionManager.shared.isSubscribed {
            return LocalizationManager.shared.localizedString("Manage Subscription")
        }
        return node.displaySubtitle
    }

    /// Layered background: frosted glass base + theme-tinted linear gradient +
    /// radial highlight from the top-leading corner. All color intensities increase
    /// while the node is being dragged to reinforce the lifted appearance.
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

    /// A rounded-rectangle stroke whose gradient colors and line width intensify
    /// during a drag to emphasise the node boundary.
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

    /// Applies a colored, animated border ring that reflects the current agent state:
    /// - Blue pulsing border while the agent is **thinking**.
    /// - Solid green border while the agent is **applying** a patch.
    /// - Orange border while a review bundle is **awaiting** user approval.
    /// - Red border when an **error** occurred.
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

/// Renders supplementary content beneath the header row of a `NodeView`.
/// For Mini-App nodes, shows a scaled-down live HTML thumbnail (375×667 ➝ 240px wide).
/// For sub-canvas nodes, shows a "Tap to open" affordance. Action nodes and plain
/// nodes render nothing (the header row is sufficient).
private struct NodePreviewContent: View {
    let node: SpatialNode
    let agentState: AgentExecutionState
    let themeColor: Color
    let activityStore: ActivityStore
    let gamificationStore: GamificationStore
    
    var body: some View {
        Group {
            if node.action == .openDaily {
                DailyNodeCardContent(store: gamificationStore)
            } else if node.action == .openActivity {
                VStack(alignment: .leading, spacing: 10) {
                    ActivityHeatmapView(
                        days: activityStore.days(),
                        cellSize: 9,
                        spacing: 3,
                        accentColor: themeColor
                    )

                    HStack(spacing: 6) {
                        Text(activityStore.todayCount, format: .number)
                            .fontWeight(.bold)
                        Text("saved today")
                    }
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 14)
            } else if node.action != nil {
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
