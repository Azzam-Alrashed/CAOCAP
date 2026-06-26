import Foundation
import OSLog
import SwiftUI

/// The output format for a project export.
public enum ExportFormat {
    /// A single self-contained HTML file containing the compiled Mini-App preview.
    case html
    /// A ZIP archive containing `index.html` and an optional `README.md` with the
    /// project's SRS text. Set `includeProjectContext: false` to omit the README.
    case webBundle(includeProjectContext: Bool = true)
    /// A raw copy of the project's `.json` file renamed with the `.caocap` extension
    /// for sharing and re-importing in another CAOCAP installation.
    case caocap
}

/// Produces shareable export artefacts from a `ProjectStore` in multiple formats.
/// All heavy I/O is dispatched on a detached background task to avoid blocking the main actor.
public struct ExportService {
    private static let logger = Logger(subsystem: "com.caocap.app", category: "ExportService")

    /// Convenience entry point that pulls required state from a live `ProjectStore`
    /// on the main actor, then hands off to the background-safe overload.
    @MainActor
    public static func export(from store: ProjectStore, format: ExportFormat) async -> URL? {
        let projectName = store.projectName
        let fileName = store.fileName
        let nodes = store.nodes
        // Use the first Mini-App's SRS text as the README content.
        let srsText = nodes.first(where: { $0.type == .miniApp })?.miniApp?.srsText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        return await export(
            projectName: projectName,
            fileName: fileName,
            nodes: nodes,
            srsText: srsText,
            format: format
        )
    }

    /// Performs the actual export work off the main actor.
    /// - Parameters:
    ///   - projectName: Used to derive the output file name (spaces → underscores).
    ///   - fileName: The project's on-disk file name, needed for `.caocap` export.
    ///   - nodes: The canvas nodes to compile or copy.
    ///   - srsText: Optional SRS content written into the `README.md` of a web bundle.
    ///   - format: The desired output format.
    /// - Returns: A temporary-directory URL pointing to the exported file, or `nil` on failure.
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
                    
                    // Use NSFileCoordinator to produce a ZIP without spawning a process.
                    // The system provides a temporary zipped URL inside the coordinator block.
                    var coordinatorError: NSError?
                    var zipURL: URL?
                    let coordinator = NSFileCoordinator()
                    coordinator.coordinate(readingItemAt: bundleURL, options: .forUploading, error: &coordinatorError) { coordinatedURL in
                        let destinationURL = fileManager.temporaryDirectory.appendingPathComponent("\(safeName)-web-bundle.zip")
                        try? fileManager.removeItem(at: destinationURL)
                        do {
                            try fileManager.copyItem(at: coordinatedURL, to: destinationURL)
                            zipURL = destinationURL
                        } catch {
                            logger.error("Failed to copy coordinated zip: \(error.localizedDescription)")
                        }
                    }
                    
                    if let error = coordinatorError {
                        logger.error("Coordinator failed to zip: \(error.localizedDescription)")
                    }
                    
                    // Clean up the unzipped directory
                    try? fileManager.removeItem(at: bundleURL)
                    
                    return zipURL
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

/// Thin `UIViewControllerRepresentable` wrapper around `UIActivityViewController`
/// so SwiftUI views can present the system share sheet with arbitrary activity items.
public struct ActivityView: UIViewControllerRepresentable {
    /// Items to share (URLs, strings, images, etc.).
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
