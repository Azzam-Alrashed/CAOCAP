import Foundation
import OSLog

public struct ProjectMetadata: Identifiable {
    public let id: String // filename
    public let name: String
    public let lastModified: Date
    public let nodeCount: Int
    public let sizeString: String
}

public actor ProjectManager {
    public static let shared = ProjectManager()
    private let logger = Logger(subsystem: "com.caocap.app", category: "ProjectManager")
    
    private var baseDir: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("com.ficruty.caocap", isDirectory: true)
        return appSupport
    }
    
    public func listProjects() -> [ProjectMetadata] {
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)
            
            return files.compactMap { url in
                let fileName = url.lastPathComponent
                guard fileName.hasPrefix("project_") && fileName.hasSuffix(".json") else { return nil }
                
                let attributes = try? fileManager.attributesOfItem(atPath: url.path)
                let modificationDate = attributes?[.modificationDate] as? Date ?? Date()
                let sizeBytes = attributes?[.size] as? Int64 ?? 0
                
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB]
                formatter.countStyle = .file
                let sizeString = formatter.string(fromByteCount: sizeBytes)
                
                let peek = getProjectPeekInfo(from: url)
                let rawName = peek?.name ?? "Untitled Project"
                let nodeCount = peek?.nodeCount ?? 0
                let name = LocalizationManager.shared.localizedProjectName(rawName, fileName: fileName)
                
                return ProjectMetadata(id: fileName, name: name, lastModified: modificationDate, nodeCount: nodeCount, sizeString: sizeString)
            }.sorted { $0.lastModified > $1.lastModified }
            
        } catch {
            logger.error("Failed to list projects: \(error.localizedDescription)")
            return []
        }
    }
    
    public func deleteProject(fileName: String) {
        let url = baseDir.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }
    
    public func createNewProject(name: String, template: ProjectTemplate = .helloWorld) throws -> String {
        let id = UUID().uuidString.prefix(8)
        let fileName = "project_\(id).json"
        
        let persistence = ProjectPersistenceService()
        let snapshot = ProjectSnapshot(
            schemaVersion: ProjectPersistenceService.currentSchemaVersion,
            projectName: name,
            nodes: ProjectTemplateProvider.nodes(for: template),
            viewportOffset: .zero,
            viewportScale: 0.3
        )
        try persistence.save(snapshot, fileName: fileName)
        return fileName
    }
    
    public func renameProject(fileName: String, newName: String) throws {
        let persistence = ProjectPersistenceService()
        let result = try persistence.load(fileName: fileName)
        let original = result.snapshot
        let updated = ProjectSnapshot(
            schemaVersion: original.schemaVersion,
            projectName: newName,
            nodes: original.nodes,
            viewportOffset: original.viewportOffset,
            viewportScale: original.viewportScale
        )
        try persistence.save(updated, fileName: fileName)
    }
    
    public func duplicateProject(fileName: String, newName: String) throws -> String {
        let persistence = ProjectPersistenceService()
        let result = try persistence.load(fileName: fileName)
        let original = result.snapshot
        
        let id = UUID().uuidString.prefix(8)
        let newFileName = "project_\(id).json"
        
        let duplicated = ProjectSnapshot(
            schemaVersion: original.schemaVersion,
            projectName: newName,
            nodes: original.nodes,
            viewportOffset: original.viewportOffset,
            viewportScale: original.viewportScale
        )
        try persistence.save(duplicated, fileName: newFileName)
        return newFileName
    }
    
    private struct ProjectPeekInfo {
        let name: String
        let nodeCount: Int
    }
    
    private func getProjectPeekInfo(from url: URL) -> ProjectPeekInfo? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let name = json["projectName"] as? String ?? "Untitled Project"
        let nodes = json["nodes"] as? [[String: Any]] ?? []
        return ProjectPeekInfo(name: name, nodeCount: nodes.count)
    }
}
