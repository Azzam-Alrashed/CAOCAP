import Foundation

/// Centralizes nested workspace file naming (`canvas_*.json`) and legacy
/// `project_*.json` resolution for sub-canvas navigation.
public enum CanvasFileNaming {
    public static let legacyProjectPrefix = "project_"
    public static let canvasPrefix = "canvas_"
    public static let rootFileName = "root_v6.json"

    /// Generates a fresh, unique canvas file name using the `canvas_` prefix and
    /// a truncated UUID suffix (e.g. `canvas_a1b2c3d4.json`).
    public static func newCanvasFileName() -> String {
        "\(canvasPrefix)\(UUID().uuidString.prefix(8)).json"
    }

    /// Converts a legacy `project_*` file name to the current `canvas_*` convention.
    /// Returns the input unchanged when it doesn't start with the legacy prefix.
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
