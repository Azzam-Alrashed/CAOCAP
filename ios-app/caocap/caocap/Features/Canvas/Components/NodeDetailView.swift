import SwiftUI

/// Opens a canvas node. Mini-App nodes enter a full-screen running preview with
/// Mini-App tools behind the floating command button.
struct NodeDetailView: View {
    /// The canvas node whose detail is being shown. Used as the initial value;
    /// the live version is always read from `store.nodes`.
    let node: SpatialNode
    /// The owning project store, passed through to child sheets.
    let store: ProjectStore
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
            MiniAppPreviewShell(node: currentNode, store: store, onFlyToNode: onFlyToNode)
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
}

/// Full-screen shell that hosts the live Mini-App HTML preview and surfaces all
/// Mini-App tools (SRS, code, Firebase, agent, settings) behind a single floating
/// command button and a confirmation dialog.
private struct MiniAppPreviewShell: View {
    let node: SpatialNode
    let store: ProjectStore
    var onFlyToNode: ((UUID) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager
    /// Controls visibility of the tool selection confirmation dialog.
    @State private var showingActions = false
    /// Drives which tool sheet is currently presented.
    @State private var activeTool: MiniAppTool?
    @State private var showingPublish = false
    @State private var subscriptionManager = SubscriptionManager.shared

    /// Live-refreshed node so any background store mutation (e.g. CoCaptain applying
    /// a patch) is immediately reflected in the preview without dismissing the sheet.
    private var currentNode: SpatialNode {
        store.nodes.first(where: { $0.id == node.id }) ?? node
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            if let html = currentNode.miniApp?.compiledHTML {
                HTMLWebView(htmlContent: html)
                    .ignoresSafeArea()
            } else {
                Text("No preview to display.")
                    .foregroundStyle(.secondary)
            }

            FloatingCommandButton(
                onTap: { showingActions = true },
                onUndo: {
                    undoManager?.undo()
                    store.undoStackChanged += 1
                },
                onSummonCoCaptain: { activeTool = .agent },
                onRedo: {
                    undoManager?.redo()
                    store.undoStackChanged += 1
                },
                canUndo: undoManager?.canUndo ?? false,
                canRedo: undoManager?.canRedo ?? false
            )
        }
        .confirmationDialog("Mini-App", isPresented: $showingActions, titleVisibility: .visible) {
            Button("SRS") { activeTool = .srs }
            Button("Code") { activeTool = .code }
            Button("Firebase") { activeTool = .firebase }
            Button("Agent") { activeTool = .agent }
            Button("Settings") { activeTool = .settings }
            Button {
                showingPublish = true
            } label: {
                if subscriptionManager.isSubscribed {
                    Text("Publish")
                } else {
                    Label("Publish", systemImage: "lock.fill")
                }
            }
            Button("Back to Canvas") { dismiss() }
            Button("Cancel", role: .cancel) {}
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
