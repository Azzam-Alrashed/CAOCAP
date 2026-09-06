import SwiftUI

/// Opens a canvas node as a card inspector. Mini-app leftover nodes do not
/// enter a live preview, SRS, code, Firebase, or publish workspace.
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
        MiniAppSettingsView(node: currentNode, store: store) {
            dismiss()
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
            .navigationTitle("Node Settings")
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
