import Foundation
import OSLog
import SwiftUI

public enum ExportFormat {
    case html
    case webBundle(includeProjectContext: Bool = true)
    case caocap
}

public struct ExportService {
    private static let logger = Logger(subsystem: "com.caocap.app", category: "ExportService")

    @MainActor
    public static func export(from store: ProjectStore, format: ExportFormat) async -> URL? {
        let projectName = store.projectName
        let fileName = store.fileName
        let nodes = store.nodes
        let srsText = nodes.first(where: { $0.role == .srs })?.textContent?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        return await export(
            projectName: projectName,
            fileName: fileName,
            nodes: nodes,
            srsText: srsText,
            format: format
        )
    }

    public static func export(
        projectName: String,
        fileName: String,
        nodes: [SpatialNode],
        srsText: String?,
        format: ExportFormat
    ) async -> URL? {
        return await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let safeName = projectName.replacingOccurrences(of: " ", with: "_").lowercased()
            
            switch format {
            case .html:
                let compiler = LivePreviewCompiler()
                guard let compilation = compiler.compile(nodes: nodes), !compilation.html.isEmpty else {
                    return nil
                }
                
                let tempURL = fileManager.temporaryDirectory.appendingPathComponent("\(safeName).html")
                do {
                    try compilation.html.write(to: tempURL, atomically: true, encoding: .utf8)
                    return tempURL
                } catch {
                    logger.error("Failed to export HTML: \(error.localizedDescription)")
                    return nil
                }
                
            case .webBundle(let includeProjectContext):
                let compiler = LivePreviewCompiler()
                guard let compilation = compiler.compile(nodes: nodes), !compilation.html.isEmpty else {
                    return nil
                }
                
                let bundleURL = fileManager.temporaryDirectory
                    .appendingPathComponent("\(safeName)-web-bundle", isDirectory: true)
                
                do {
                    if fileManager.fileExists(atPath: bundleURL.path) {
                        try fileManager.removeItem(at: bundleURL)
                    }
                    try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)
                    try compilation.html.write(
                        to: bundleURL.appendingPathComponent("index.html"),
                        atomically: true,
                        encoding: .utf8
                    )
                    
                    if includeProjectContext,
                       let srsText,
                       !srsText.isEmpty {
                        let readme = """
                        # \(projectName)
                        
                        Exported from CAOCAP.
                        
                        ## Software Requirements
                        
                        \(srsText)
                        """
                        try readme.write(
                            to: bundleURL.appendingPathComponent("README.md"),
                            atomically: true,
                            encoding: .utf8
                        )
                    }
                    
                    return bundleURL
                } catch {
                    logger.error("Failed to export web bundle: \(error.localizedDescription)")
                    return nil
                }
                
            case .caocap:
                let persistence = ProjectPersistenceService()
                let originalURL = persistence.fileURL(for: fileName)
                
                let exportURL = fileManager.temporaryDirectory.appendingPathComponent("\(safeName).caocap")
                do {
                    if fileManager.fileExists(atPath: exportURL.path) {
                        try fileManager.removeItem(at: exportURL)
                    }
                    try fileManager.copyItem(at: originalURL, to: exportURL)
                    return exportURL
                } catch {
                    logger.error("Failed to export CAOCAP project: \(error.localizedDescription)")
                    return nil
                }
            }
        }.value
    }
}

public struct ActivityView: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public let applicationActivities: [UIActivity]? = nil

    public init(activityItems: [Any]) {
        self.activityItems = activityItems
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
