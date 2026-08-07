import SwiftUI

/// Opens a canvas node. Mini-App nodes enter a large-sheet running preview with
/// Mini-App tools behind the floating command button.
struct NodeDetailView: View {
    /// The canvas node whose detail is being shown. Used as the initial value;
    /// the live version is always read from `store.nodes`.
    let node: SpatialNode
    /// The owning project store, passed through to child sheets.
    let store: ProjectStore
    var commandPalette: CommandPaletteViewModel? = nil
    var onFlyToNode: ((UUID) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    /// Always reads the node from the store so that any edits made inside a
    /// child sheet (e.g. title change in settings) are reflected here without
    /// needing to re-open the detail view.
    private var currentNode: SpatialNode {
        store.nodes.first(where: { $0.id == node.id }) ?? node
    }

    var body: some View {
        if currentNode.type == .miniApp {
            MiniAppPreviewShell(
                node: currentNode,
                store: store,
                commandPalette: commandPalette,
                onFlyToNode: onFlyToNode
            )
        } else {
            MiniAppSettingsView(node: currentNode, store: store) {
                dismiss()
            }
        }
    }
}

/// Identifies which tool sheet should be presented over the live Mini-App preview.
private enum MiniAppTool: String, Identifiable {
    /// Software Requirements Specification editor.
    case srs
    /// HTML/JS source code editor.
    case code
    /// Firebase Web SDK configuration editor.
    case firebase
    /// CoCaptain agent chat panel.
    case agent
    /// Node identity and agent profile settings form.
    case settings

    var id: String { rawValue }

    init?(_ previewTool: MiniAppPreviewTool) {
        switch previewTool {
        case .srs: self = .srs
        case .code: self = .code
        case .firebase: self = .firebase
        case .agent: self = .agent
        case .settings: self = .settings
        case .publish, .backToCanvas: return nil
        }
    }
}

/// Large-sheet shell that hosts the live Mini-App HTML preview and surfaces all
/// Mini-App tools through the shared omnibox and floating command button.
private struct MiniAppPreviewShell: View {
    let node: SpatialNode
    let store: ProjectStore
    var commandPalette: CommandPaletteViewModel?
    var onFlyToNode: ((UUID) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager
    @Environment(OnboardingCoordinator.self) private var onboarding: OnboardingCoordinator?
    /// Drives which tool sheet is currently presented.
    @State private var activeTool: MiniAppTool?
    @State private var showingPublish = false

    /// Live-refreshed node so any background store mutation (e.g. CoCaptain applying
    /// a patch) is immediately reflected in the preview without dismissing the sheet.
    private var currentNode: SpatialNode {
        store.nodes.first(where: { $0.id == node.id }) ?? node
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            if let html = currentNode.miniApp?.compiledHTML {
                HTMLWebView(
                    htmlContent: html,
                    onUserInteraction: {
                        if onboarding?.currentStep == .interactMiniAppPreview {
                            onboarding?.completeCurrentStep()
                        }
                    }
                )
                    .ignoresSafeArea()
                    .onboardingTooltipAnchor(.miniAppPreviewArea)
            } else {
                Text("No preview to display.")
                    .foregroundStyle(.secondary)
            }

            if let commandPalette {
                CommandPaletteView(viewModel: commandPalette)
            }

            FloatingCommandButton(
                onTap: openOmnibox,
                onSelectMode: { _ in openOmnibox() },
                isOnboardingHighlighted: onboarding?.showPopover == true
                    && onboarding?.currentStep == .runOrganizeNodes,
                tooltipAnchor: .miniAppPreviewFAB
            )
        }
        .onboardingTooltipOverlay(
            isCommandPalettePresented: commandPalette?.isPresented ?? false,
            rendersAnchor: { $0 == .miniAppPreviewArea || $0 == .miniAppPreviewFAB }
        )
        .onChange(of: onboarding?.currentStep) { _, step in
            guard step == .openMiniAppCodeTool else { return }
            commandPalette?.setPresented(true)
        }
        .onAppear {
            guard let commandPalette else { return }
            commandPalette.miniAppPreviewContext = MiniAppPreviewPaletteContext(
                nodeID: currentNode.id,
                onSelectTool: handlePreviewToolSelection
            )
        }
        .onDisappear {
            commandPalette?.miniAppPreviewContext = nil
            commandPalette?.setPresented(false)
        }
        .sheet(isPresented: $showingPublish) {
            MiniAppPublishView(node: currentNode, store: store)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $activeTool) { tool in
            switch tool {
            case .srs:
                SRSEditorView(node: currentNode, store: store)
            case .code:
                CodeEditorView(node: currentNode, store: store)
            case .firebase:
                FirebaseConfigNodeEditorView(node: currentNode, store: store)
            case .agent:
                NavigationStack {
                    NodeAgentChatView(
                        nodeID: currentNode.id,
                        store: store,
                        actionDispatcher: nil,
                        onFlyToNode: { nodeID in
                            activeTool = nil
                            onFlyToNode?(nodeID)
                        }
                    )
                }
            case .settings:
                MiniAppSettingsView(node: currentNode, store: store) {
                    dismiss()
                }
            }
        }
    }

    private func openOmnibox() {
        commandPalette?.nodes = store.nodes
        commandPalette?.setPresented(true)
    }

    private func handlePreviewToolSelection(_ tool: MiniAppPreviewTool) {
        switch tool {
        case .publish:
            showingPublish = true
        case .backToCanvas:
            if onboarding?.currentStep == .returnFromMiniAppPreview {
                onboarding?.completeCurrentStep()
            }
            dismiss()
        default:
            if let miniAppTool = MiniAppTool(tool) {
                activeTool = miniAppTool
                if miniAppTool == .code, onboarding?.currentStep == .openMiniAppCodeTool {
                    onboarding?.completeCurrentStep()
                }
            }
        }
    }
}

/// A navigation-wrapped `Form` for editing a node's identity (name, subtitle, icon,
/// theme), agent profile (role, system prompt, auto-trigger flag), and — for
/// non-protected nodes — a destructive delete action.
private struct MiniAppSettingsView: View {
    let node: SpatialNode
    let store: ProjectStore
    /// Invoked after the user confirms node deletion so the caller (e.g.,
    /// `InfiniteCanvasView`) can dismiss the sheet that was showing this detail.
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var currentNode: SpatialNode {
        store.nodes.first(where: { $0.id == node.id }) ?? node
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: Binding(
                        get: { currentNode.title },
                        set: { store.updateNodeTitle(id: node.id, title: $0) }
                    ))

                    TextField("Subtitle", text: Binding(
                        get: { currentNode.subtitle ?? "" },
                        set: { store.updateNodeSubtitle(id: node.id, subtitle: $0.isEmpty ? nil : $0) }
                    ))

                    TextField("SF Symbol", text: Binding(
                        get: { currentNode.icon ?? "" },
                        set: { store.updateNodeIcon(id: node.id, icon: $0.isEmpty ? nil : $0) }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    Picker("Theme", selection: Binding(
                        get: { currentNode.theme },
                        set: { store.updateNodeTheme(id: node.id, theme: $0) }
                    )) {
                        ForEach(NodeTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue.capitalized).tag(theme)
                        }
                    }
                }

                Section("Agent Profile") {
                    TextField("Role Name", text: Binding(
                        get: { currentNode.agentProfile.roleName },
                        set: {
                            store.updateNodeAgentProfile(
                                id: node.id,
                                profile: AgentProfile(
                                    systemPrompt: currentNode.agentProfile.systemPrompt,
                                    roleName: $0,
                                    isAutoTriggerEnabled: currentNode.agentProfile.isAutoTriggerEnabled
                                )
                            )
                        }
                    ))

                    TextEditor(text: Binding(
                        get: { currentNode.agentProfile.systemPrompt ?? "" },
                        set: {
                            store.updateNodeAgentProfile(
                                id: node.id,
                                profile: AgentProfile(
                                    systemPrompt: $0.isEmpty ? nil : $0,
                                    roleName: currentNode.agentProfile.roleName,
                                    isAutoTriggerEnabled: currentNode.agentProfile.isAutoTriggerEnabled
                                )
                            )
                        }
                    ))
                    .frame(minHeight: 120)

                    Toggle("Auto-Trigger Downstream", isOn: Binding(
                        get: { currentNode.agentProfile.isAutoTriggerEnabled },
                        set: {
                            store.updateNodeAgentProfile(
                                id: node.id,
                                profile: AgentProfile(
                                    systemPrompt: currentNode.agentProfile.systemPrompt,
                                    roleName: currentNode.agentProfile.roleName,
                                    isAutoTriggerEnabled: $0
                                )
                            )
                        }
                    ))
                }

                if !currentNode.isProtected {
                    Section {
                        Button("Delete Node", role: .destructive) {
                            HapticsManager.shared.notification(.warning)
                            store.deleteNode(id: node.id)
                            dismiss()
                            onDelete()
                        }
                    }
                }
            }
            .navigationTitle(currentNode.type == .miniApp ? "Mini-App Settings" : "Node Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
