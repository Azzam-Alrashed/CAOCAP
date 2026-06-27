import Foundation

enum AppDataResetError: LocalizedError {
    case localModelDownloadInProgress

    var errorDescription: String? {
        switch self {
        case .localModelDownloadInProgress:
            return "Wait for the local model download to finish, then try again."
        }
    }
}

/// Removes app-owned local state while deliberately leaving the user's remote
/// Firebase account and App Store entitlements intact.
enum AppDataResetService {
    static func eraseLocalData(
        persistence: ProjectPersistenceService = ProjectPersistenceService(),
        defaults: UserDefaults = .standard,
        defaultsDomain: String? = Bundle.main.bundleIdentifier,
        containerDirectories: [URL]? = nil
    ) async throws {
        let fileManager = FileManager.default
        let workspace = persistence.workspaceDirectory()
        let directories = containerDirectories ?? [
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first,
            fileManager.temporaryDirectory
        ].compactMap { $0 }

        try await Task.detached(priority: .userInitiated) {
            let worker = FileManager.default
            if worker.fileExists(atPath: workspace.path) {
                try worker.removeItem(at: workspace)
            }
            for directory in directories {
                guard worker.fileExists(atPath: directory.path) else { continue }
                for item in try worker.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: nil
                ) {
                    try worker.removeItem(at: item)
                }
            }
        }.value

        if let defaultsDomain {
            defaults.removePersistentDomain(forName: defaultsDomain)
        }
    }
}
