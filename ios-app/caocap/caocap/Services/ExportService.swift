import Foundation
import SwiftUI

public enum ExportFormat {
    case html
    case caocap
}

public struct ExportService {
    public static func export(from store: ProjectStore, format: ExportFormat) -> URL? {
        let fileManager = FileManager.default
        let safeName = store.projectName.replacingOccurrences(of: " ", with: "_").lowercased()
        
        switch format {
        case .html:
            let compiler = LivePreviewCompiler()
            guard let compilation = compiler.compile(nodes: store.nodes), !compilation.html.isEmpty else {
                return nil
            }
            
            let tempURL = fileManager.temporaryDirectory.appendingPathComponent("\(safeName).html")
            do {
                try compilation.html.write(to: tempURL, atomically: true, encoding: .utf8)
                return tempURL
            } catch {
                print("ExportService Error: \(error.localizedDescription)")
                return nil
            }
            
        case .caocap:
            let persistence = ProjectPersistenceService()
            guard let originalURL = persistence.fileURL(for: store.fileName) else { return nil }
            
            let exportURL = fileManager.temporaryDirectory.appendingPathComponent("\(safeName).caocap")
            do {
                if fileManager.fileExists(atPath: exportURL.path) {
                    try fileManager.removeItem(at: exportURL)
                }
                try fileManager.copyItem(at: originalURL, to: exportURL)
                return exportURL
            } catch {
                print("ExportService Error: \(error.localizedDescription)")
                return nil
            }
        }
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
