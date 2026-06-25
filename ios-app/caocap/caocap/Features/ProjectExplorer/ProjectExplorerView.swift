import SwiftUI
import OSLog

struct ProjectExplorerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (String) -> Void
    
    private let logger = Logger(subsystem: "com.caocap.app", category: "ProjectExplorerView")
    
    @State private var projects: [ProjectMetadata] = []
    @State private var isLoading = true
    @State private var searchText = ""
    
    // Alert & Action States
    @State private var showingCreateSheet = false
    
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
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                NewProjectSheetView(
                    onCreate: { name, template in
                        createProject(name: name, template: template)
                        showingCreateSheet = false
                    },
                    onCancel: {
                        showingCreateSheet = false
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
        isLoading = true
        Task {
            let list = await ProjectManager.shared.listProjects()
            self.projects = list
            self.isLoading = false
        }
    }
    
    private func createProject(name: String, template: ProjectTemplate = .helloWorld) {
        isLoading = true
        Task {
            do {
                let newFileName = try await ProjectManager.shared.createNewProject(name: name, template: template)
                onSelect(newFileName)
                dismiss()
            } catch {
                logger.error("Failed to create project: \(error.localizedDescription, privacy: .public)")
                isLoading = false
            }
        }
    }
    
    private func deleteProject(_ project: ProjectMetadata) {
        isLoading = true
        Task {
            await ProjectManager.shared.deleteProject(fileName: project.id)
            loadProjects()
        }
    }
    
    private func duplicateProject(_ project: ProjectMetadata) {
        isLoading = true
        Task {
            do {
                let copyName = "\(project.name) Copy"
                _ = try await ProjectManager.shared.duplicateProject(fileName: project.id, newName: copyName)
                loadProjects()
            } catch {
                logger.error("Failed to duplicate project: \(error.localizedDescription, privacy: .public)")
                isLoading = false
            }
        }
    }
    
    private func renameProject(_ project: ProjectMetadata, to newName: String) {
        isLoading = true
        Task {
            do {
                try await ProjectManager.shared.renameProject(fileName: project.id, newName: newName)
                loadProjects()
            } catch {
                logger.error("Failed to rename project: \(error.localizedDescription, privacy: .public)")
                isLoading = false
            }
        }
    }
    
    private func exportProject(_ project: ProjectMetadata) {
        isLoading = true
        Task {
            let persistence = ProjectPersistenceService()
            let snapshot = await Task.detached(priority: .userInitiated) { () -> ProjectSnapshot? in
                try? persistence.load(fileName: project.id)
            }.value
            
            guard let snapshot else {
                logger.error("Failed to load project snapshot for export.")
                isLoading = false
                return
            }
            
            let url = await ExportService.export(
                projectName: snapshot.projectName ?? "Untitled Project",
                fileName: project.id,
                nodes: snapshot.nodes,
                srsText: snapshot.nodes.first(where: { $0.role == .srs })?.textContent?.trimmingCharacters(in: .whitespacesAndNewlines),
                format: .webBundle(includeProjectContext: true)
            )
            
            isLoading = false
            if let url {
                self.exportURL = url
                self.showingExportSheet = true
            }
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
            
            Text("Start a new project from the Root workspace to see it here.")
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
        .interactiveKeyboardDismiss()
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
