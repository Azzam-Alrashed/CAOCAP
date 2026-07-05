import UIKit

struct AppIconOption: Identifiable, Equatable {
    /// Empty string selects the primary icon; otherwise the alternate appiconset name.
    let id: String
    let displayName: String
    let subtitle: String
    let previewImageName: String

    var alternateIconName: String? {
        id.isEmpty ? nil : id
    }
}

@MainActor
enum AppIconService {
    static let storageKey = "selected_app_icon"

    static let options: [AppIconOption] = [
        AppIconOption(id: "", displayName: "Classic", subtitle: "Astronaut portrait", previewImageName: "AppIconPreviewDefault"),
        AppIconOption(id: "AppIcon_8", displayName: "Classic Star", subtitle: "Curious co-pilot porthole", previewImageName: "AppIconPreview8"),
        AppIconOption(id: "AppIcon_0", displayName: "Blueprint", subtitle: "Plant logo on sketch grid", previewImageName: "AppIconPreview0"),
        AppIconOption(id: "AppIcon_1", displayName: "Launch", subtitle: "Rocket on star grid", previewImageName: "AppIconPreview1"),
        AppIconOption(id: "AppIcon_2", displayName: "Orbit", subtitle: "Deep space rocket", previewImageName: "AppIconPreview2"),
        AppIconOption(id: "AppIcon_3", displayName: "Nova", subtitle: "Bright rocket trail", previewImageName: "AppIconPreview3"),
        AppIconOption(id: "AppIcon_5", displayName: "CoStar", subtitle: "Scout porthole, purple glow", previewImageName: "AppIconPreview5"),
        AppIconOption(id: "AppIcon_6", displayName: "CoCaptain", subtitle: "Captain porthole, cyan glow", previewImageName: "AppIconPreview6"),
        AppIconOption(id: "AppIcon_7", displayName: "Duo", subtitle: "Cocaptain and CoStar together", previewImageName: "AppIconPreview7")
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
        var saved = defaults.string(forKey: storageKey) ?? ""
        if saved == "AppIcon_4" {
            saved = ""
            defaults.set(saved, forKey: storageKey)
        }
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
