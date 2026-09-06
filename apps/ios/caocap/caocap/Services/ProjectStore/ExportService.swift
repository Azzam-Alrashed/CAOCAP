import Foundation
import OSLog
import SwiftUI

/// The output format for a project export.
public enum ExportFormat {
    /// A raw copy of the project's `.json` file renamed with the `.caocap` extension
    /// for sharing and re-importing in another CAOCAP installation.
    case caocap
}

/// Produces shareable export artefacts from a `ProjectStore`.
public struct ExportService {
    private static let logger = Logger(subsystem: "com.caocap.app", category: "ExportService")

    @MainActor
    public static func export(from store: ProjectStore, format: ExportFormat) async -> URL? {
        await export(
            projectName: store.projectName,
            fileName: store.fileName,
            format: format
        )
    }

    public static func export(
        projectName: String,
        fileName: String,
        format: ExportFormat
    ) async -> URL? {
        await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let safeName = projectName.replacingOccurrences(of: " ", with: "_").lowercased()

            switch format {
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
