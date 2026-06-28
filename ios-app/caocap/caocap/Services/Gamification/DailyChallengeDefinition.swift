import Foundation

public struct DailyChallengeDefinition: Identifiable, Equatable, Sendable {
    public let id: String
    public let tier: DailyChallengeTier
    public let titleKey: String
    public let descriptionKey: String

    public var title: String {
        LocalizationManager.shared.localizedString(titleKey)
    }

    public var description: String {
        LocalizationManager.shared.localizedString(descriptionKey)
    }

    public static let catalog: [DailyChallengeDefinition] = [
        DailyChallengeDefinition(
            id: "update_title",
            tier: .iron,
            titleKey: "challenge.update_title",
            descriptionKey: "challenge.update_title_desc"
        ),
        DailyChallengeDefinition(
            id: "change_background",
            tier: .gold,
            titleKey: "challenge.change_background",
            descriptionKey: "challenge.change_background_desc"
        ),
        DailyChallengeDefinition(
            id: "add_image",
            tier: .diamond,
            titleKey: "challenge.add_image",
            descriptionKey: "challenge.add_image_desc"
        )
    ]
}
