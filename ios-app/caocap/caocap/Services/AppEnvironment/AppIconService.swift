import UIKit

struct AppIconOption: Identifiable, Equatable {
    /// Empty string selects the primary icon; otherwise the alternate appiconset name.
    let id: String
    let displayName: String
    let previewImageName: String

    var alternateIconName: String? {
        id.isEmpty ? nil : id
    }
}

@MainActor
enum AppIconService {
    static let storageKey = "selected_app_icon"

    static let options: [AppIconOption] = [
        AppIconOption(id: "", displayName: "Default", previewImageName: "AppIconPreviewDefault"),
        AppIconOption(id: "AppIcon_0", displayName: "Icon 1", previewImageName: "AppIconPreview0"),
        AppIconOption(id: "AppIcon_1", displayName: "Icon 2", previewImageName: "AppIconPreview1"),
        AppIconOption(id: "AppIcon_2", displayName: "Icon 3", previewImageName: "AppIconPreview2"),
        AppIconOption(id: "AppIcon_3", displayName: "Icon 4", previewImageName: "AppIconPreview3"),
        AppIconOption(id: "AppIcon_4", displayName: "Icon 5", previewImageName: "AppIconPreview4")
    ]

    static var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    static var currentAlternateIconName: String? {
        UIApplication.shared.alternateIconName
    }

    static var currentSelectionID: String {
        currentAlternateIconName ?? ""
    }

    static func applySavedIcon(defaults: UserDefaults = .standard) {
        guard supportsAlternateIcons else { return }
        let saved = defaults.string(forKey: storageKey) ?? ""
        let targetName = saved.isEmpty ? nil : saved
        guard targetName != currentAlternateIconName else { return }
        UIApplication.shared.setAlternateIconName(targetName) { _ in }
    }

    static func setIcon(_ option: AppIconOption, defaults: UserDefaults = .standard) async throws {
        guard supportsAlternateIcons else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UIApplication.shared.setAlternateIconName(option.alternateIconName) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    defaults.set(option.id, forKey: storageKey)
                    continuation.resume()
                }
            }
        }
    }
}
