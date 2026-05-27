import SwiftUI

struct ProjectExplorerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (String) -> Void
    
    @State private var projects: [ProjectMetadata] = []
    @State private var isLoading = true
    @State private var searchText = ""
    
    // Alert & Action States
    @State private var showingCreateAlert = false
    @State private var newProjectName = ""
    
    @State private var showingRenameAlert = false
    @State private var renameText = ""
    @State private var projectToRename: ProjectMetadata?
    
    @State private var exportURL: URL?
    @State private var showingExportSheet = false
    
    var filteredProjects: [ProjectMetadata] {
        if searchText.isEmpty {
            return projects
        } else {
            return projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                } else if projects.isEmpty {
                    EmptyStateView()
                } else if filteredProjects.isEmpty {
                    SearchEmptyStateView(searchText: searchText)
                } else {
                    ProjectListView(
                        projects: filteredProjects,
                        onSelect: { project in
                            onSelect(project.id)
                            dismiss()
                        },
                        onDelete: deleteProject,
                        onRename: { project in
                            projectToRename = project
                            renameText = project.name
                            showingRenameAlert = true
                        },
                        onDuplicate: duplicateProject,
                        onExport: exportProject
                    )
                }
            }
            .navigationTitle("Your Projects")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search projects...")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingCreateAlert = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .alert("New Project", isPresented: $showingCreateAlert) {
                TextField("Project Name", text: $newProjectName)
                Button("Cancel", role: .cancel) {
                    newProjectName = ""
                }
                Button("Create") {
                    createProject(name: newProjectName.isEmpty ? "Untitled Project" : newProjectName)
                    newProjectName = ""
                }
            } message: {
                Text("Enter a name for your new project.")
            }
            .alert("Rename Project", isPresented: $showingRenameAlert) {
                TextField("New Name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    projectToRename = nil
                    renameText = ""
                }
                Button("Save") {
                    if let project = projectToRename {
                        renameProject(project, to: renameText.isEmpty ? project.name : renameText)
                    }
                    projectToRename = nil
                    renameText = ""
                }
            } message: {
                Text("Enter a new name for this project.")
            }
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ActivityView(activityItems: [url])
                        .presentationDetents([.medium, .large])
                }
            }
            .onAppear {
                loadProjects()
            }
        }
    }
    
    private func loadProjects() {
        projects = ProjectManager.shared.listProjects()
        isLoading = false
    }
    
    private func createProject(name: String) {
        do {
            let newFileName = try ProjectManager.shared.createNewProject(name: name)
            // Navigate directly to the new project and close explorer
            onSelect(newFileName)
            dismiss()
        } catch {
            // Silently fail or log error
        }
    }
    
    private func deleteProject(_ project: ProjectMetadata) {
        ProjectManager.shared.deleteProject(fileName: project.id)
        loadProjects()
    }
    
    private func duplicateProject(_ project: ProjectMetadata) {
        do {
            let copyName = "\(project.name) Copy"
            _ = try ProjectManager.shared.duplicateProject(fileName: project.id, newName: copyName)
            loadProjects()
        } catch {
            // Silently fail or log error
        }
    }
    
    private func renameProject(_ project: ProjectMetadata, to newName: String) {
        do {
            try ProjectManager.shared.renameProject(fileName: project.id, newName: newName)
            loadProjects()
        } catch {
            // Silently fail or log error
        }
    }
    
    private func exportProject(_ project: ProjectMetadata) {
        let tempStore = ProjectStore(fileName: project.id)
        if let url = ExportService.export(from: tempStore, format: .webBundle(includeProjectContext: true)) {
            self.exportURL = url
            self.showingExportSheet = true
        } else if let url = ExportService.export(from: tempStore, format: .caocap) {
            self.exportURL = url
            self.showingExportSheet = true
        }
    }
}

// MARK: - Subviews

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 64))
                .foregroundStyle(.secondary.opacity(0.3))
            
            Text("No Projects Found")
                .font(.headline)
            
            Text("Start a new project from the Home workspace to see it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

private struct SearchEmptyStateView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary.opacity(0.3))
            
            Text("No Results for \"\(searchText)\"")
                .font(.headline)
            
            Text("Check the spelling or try searching for another project name.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

private struct ProjectListView: View {
    let projects: [ProjectMetadata]
    let onSelect: (ProjectMetadata) -> Void
    let onDelete: (ProjectMetadata) -> Void
    let onRename: (ProjectMetadata) -> Void
    let onDuplicate: (ProjectMetadata) -> Void
    let onExport: (ProjectMetadata) -> Void
    
    var body: some View {
        List {
            ForEach(projects) { project in
                ProjectRow(project: project, action: { onSelect(project) })
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(.primary.opacity(0.05))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            onDelete(project)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            onRename(project)
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                        
                        Button {
                            onDuplicate(project)
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        .tint(.orange)
                    }
                    .contextMenu {
                        Button {
                            onSelect(project)
                        } label: {
                            Label("Open Project", systemImage: "folder.badge.plus")
                        }
                        
                        Button {
                            onRename(project)
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        
                        Button {
                            onDuplicate(project)
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        
                        Button {
                            onExport(project)
                        } label: {
                            Label("Export Project", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            onDelete(project)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }
}

private struct ProjectIconView: View {
    let projectName: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(gradient(for: projectName))
                .frame(width: 48, height: 48)
                .shadow(color: color(for: projectName).opacity(0.15), radius: 4, x: 0, y: 2)
            
            Image(systemName: iconName(for: projectName))
                .foregroundStyle(.white)
                .font(.system(size: 20, weight: .semibold))
        }
    }
    
    private func gradient(for name: String) -> LinearGradient {
        let colors = colors(for: name)
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func colors(for name: String) -> [Color] {
        let hash = abs(name.hashValue)
        let themes: [[Color]] = [
            [.blue, .indigo],
            [.purple, .pink],
            [.orange, .red],
            [.teal, .green],
            [.indigo, .purple],
            [.mint, .teal]
        ]
        return themes[hash % themes.count]
    }
    
    private func color(for name: String) -> Color {
        colors(for: name).first ?? .blue
    }
    
    private func iconName(for name: String) -> String {
        let hash = abs(name.hashValue)
        let icons = [
            "folder.fill",
            "doc.text.fill",
            "circle.grid.2x2.fill",
            "command",
            "app.window.description",
            "sparkles",
            "cpu"
        ]
        return icons[hash % icons.count]
    }
}

private struct ProjectRow: View {
    let project: ProjectMetadata
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ProjectIconView(projectName: project.name)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text("\(project.nodeCount) nodes • \(project.sizeString) • \(LocalizationManager.shared.localizedString("project.lastEditedDate", arguments: [LocalizationManager.shared.relativeDateString(for: project.lastModified)]))")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    ProjectExplorerView(onSelect: { _ in })
}
