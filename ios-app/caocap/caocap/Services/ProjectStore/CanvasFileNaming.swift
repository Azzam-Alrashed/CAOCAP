import Foundation

/// Centralizes nested workspace file naming (`canvas_*.json`) and legacy
/// `project_*.json` resolution for sub-canvas navigation.
public enum CanvasFileNaming {
    public static let legacyProjectPrefix = "project_"
    public static let canvasPrefix = "canvas_"
    public static let rootFileName = "root_v6.json"

    public static func newCanvasFileName() -> String {
        "\(canvasPrefix)\(UUID().uuidString.prefix(8)).json"
    }

    public static func migrateLegacyFileName(_ fileName: String) -> String {
        guard fileName.hasPrefix(legacyProjectPrefix) else { return fileName }
        return canvasPrefix + fileName.dropFirst(legacyProjectPrefix.count)
    }

    /// Returns the on-disk file name to open, preferring `canvas_*` and falling
    /// back to a matching legacy `project_*` file when needed.
    public static func resolveExistingFileName(
        _ fileName: String,
        persistence: ProjectPersistenceService = ProjectPersistenceService()
    ) -> String {
        if persistence.projectExists(fileName: fileName) {
            return fileName
        }

        let migrated = migrateLegacyFileName(fileName)
        if migrated != fileName, persistence.projectExists(fileName: migrated) {
            return migrated
        }

        if fileName.hasPrefix(canvasPrefix) {
            let legacy = legacyProjectPrefix + fileName.dropFirst(canvasPrefix.count)
            if persistence.projectExists(fileName: String(legacy)) {
                return String(legacy)
            }
        }

        return fileName
    }
}
