import SwiftUI

/// Routes a selected node to the correct full-screen inspector/editor. Adding a
/// node type should usually update this router and the matching store/context
/// behavior together.
struct NodeDetailView: View {
    let node: SpatialNode
    let store: ProjectStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var isEditingTitle = false
    @FocusState private var isTitleFocused: Bool
    
    private var currentNode: SpatialNode {
        store.nodes.first(where: { $0.id == node.id }) ?? node
    }
    
    var body: some View {
        if horizontalSizeClass == .compact {
            TabView {
                editorContent
                    .tabItem {
                        Label(node.type == .webView ? "Preview" : "Artifact", systemImage: node.type == .webView ? "play.rectangle" : "square.and.pencil")
                    }

                NavigationStack {
                    NodeAgentChatView(nodeID: node.id, store: store)
                }
                .tabItem {
                    Label("Agent", systemImage: "sparkles")
                }
            }
        } else {
            HStack(spacing: 0) {
                editorContent
                    .frame(maxWidth: .infinity)
                
                Divider()
                
                NavigationStack {
                    NodeAgentChatView(nodeID: node.id, store: store)
                }
                .frame(width: 400)
            }
        }
    }

    @ViewBuilder
    private var editorContent: some View {
        if currentNode.type == .firebase {
            FirebaseConfigNodeEditorView(node: currentNode, store: store)
        } else if currentNode.type == .webView {
            NavigationView {
                ZStack {
                    Color(uiColor: .systemBackground).ignoresSafeArea()
                    
                    if let html = node.htmlContent {
                        HTMLWebView(htmlContent: html)
                            .ignoresSafeArea()
                    } else {
                        Text("No content to display.")
                            .foregroundColor(.gray)
                    }
                }
                .navigationTitle(currentNode.displayTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        } else if currentNode.type == .code {
            CodeEditorView(node: currentNode, store: store)
        } else if currentNode.type == .srs {
            SRSEditorView(node: currentNode, store: store)
        } else {
            NavigationView {
                ZStack {
                    // Background
                    themeColor.opacity(0.05).ignoresSafeArea()
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Header Section
                            
                            Section(header: Text("Agent Profile").font(.caption).foregroundStyle(.secondary)) {
                                VStack(alignment: .leading, spacing: 12) {
                                    TextField("Role Name (e.g. QA Agent)", text: Binding(
                                        get: { node.agentProfile.roleName },
                                        set: { store.updateNodeAgentProfile(id: node.id, profile: AgentProfile(systemPrompt: node.agentProfile.systemPrompt, roleName: $0, isAutoTriggerEnabled: node.agentProfile.isAutoTriggerEnabled)) }
                                    ))
                                    .textFieldStyle(.roundedBorder)

                                    Text("System Prompt")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    TextEditor(text: Binding(
                                        get: { node.agentProfile.systemPrompt ?? "" },
                                        set: { store.updateNodeAgentProfile(id: node.id, profile: AgentProfile(systemPrompt: $0.isEmpty ? nil : $0, roleName: node.agentProfile.roleName, isAutoTriggerEnabled: node.agentProfile.isAutoTriggerEnabled)) }
                                    ))
                                    .frame(minHeight: 100)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                                    
                                    Toggle("Auto-Trigger Downstream", isOn: Binding(
                                        get: { node.agentProfile.isAutoTriggerEnabled },
                                        set: { store.updateNodeAgentProfile(id: node.id, profile: AgentProfile(systemPrompt: node.agentProfile.systemPrompt, roleName: node.agentProfile.roleName, isAutoTriggerEnabled: $0)) }
                                    ))
                                }
                            }
                            
                            HStack(spacing: 20) {
                                if let icon = node.icon {
                                    ZStack {
                                        Circle()
                                            .fill(themeColor.opacity(0.15))
                                            .frame(width: 80, height: 80)
                                        
                                        Image(systemName: icon)
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(themeColor)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        if isEditingTitle {
                                            TextField("Node Name", text: Binding(
                                                get: { currentNode.title },
                                                set: { store.updateNodeTitle(id: node.id, title: $0) }
                                            ))
                                            .font(.system(size: 28, weight: .bold, design: .rounded))
                                            .focused($isTitleFocused)
                                            .submitLabel(.done)
                                            .onSubmit { isEditingTitle = false }
                                        } else {
                                            Text(currentNode.title)
                                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                        }
                                        
                                        Button {
                                            isEditingTitle.toggle()
                                            isTitleFocused = isEditingTitle
                                        } label: {
                                            Image(systemName: isEditingTitle ? "checkmark.circle.fill" : "pencil.line")
                                                .font(.system(size: 18))
                                                .foregroundColor(isEditingTitle ? .green : .secondary)
                                                .opacity(0.8)
                                        }
                                    }
                                    
                                    Text(currentNode.type.displayName)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 20)
                            
                            Divider()
                            
                            // Aesthetics & Role Section (Only for protected/navigation nodes)
                            if currentNode.isProtected {
                                Section(header: Text("Configuration").font(.caption).foregroundStyle(.secondary)) {
                                    HStack(spacing: 12) {
                                        Picker("Theme", selection: Binding(
                                            get: { currentNode.theme },
                                            set: { store.updateNodeTheme(id: node.id, theme: $0) }
                                        )) {
                                            ForEach(NodeTheme.allCases, id: \.self) { theme in
                                                Circle().fill(theme.color).frame(width: 20, height: 20).tag(theme)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .buttonStyle(.bordered)
                                        
                                        Picker("Role", selection: Binding(
                                            get: { currentNode.type },
                                            set: { store.updateNodeType(id: node.id, type: $0) }
                                        )) {
                                            ForEach(NodeType.allCases, id: \.self) { type in
                                                Text(type.displayName).tag(type)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                            
                            if !currentNode.isProtected {
                                Divider()
                                
                                Button(role: .destructive) {
                                    HapticsManager.shared.notification(.warning)
                                    store.deleteNode(id: node.id)
                                    dismiss()
                                } label: {
                                    Label("Delete Node", systemImage: "trash")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(12)
                                }
                                .padding(.vertical)
                            }
                            
                            Spacer()
                        }
                        .padding(24)
                    }
                    .interactiveKeyboardDismiss()
                }
                .navigationTitle("Node Inspector")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }.fontWeight(.semibold)
                    }
                }
            }
        }
    }
    
    private var themeColor: Color {
        currentNode.theme.color
    }
}

struct DetailTag: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizationManager.shared.localizedString(label).uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
        }
    }
}
