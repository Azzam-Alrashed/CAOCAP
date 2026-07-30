import Foundation
import Observation

enum PersonalizationPage {
    case copilot
    case codingLevel
}

enum PersonalizationCodingLevel: Int, CaseIterable, Equatable {
    case zero
    case beginner
    case intermediate
    case experienced

    var title: String {
        switch self {
        case .zero: return "Zero"
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .experienced: return "Experienced"
        }
    }

    var answerID: String {
        switch self {
        case .zero: return "zero"
        case .beginner: return "beginner"
        case .intermediate: return "intermediate"
        case .experienced: return "experienced"
        }
    }
}

/// Tracks whether the temporary personalization placeholder should be presented.
@MainActor
@Observable
final class PersonalizationOnboardingCoordinator {
    private(set) var isCompleted: Bool
    private(set) var selectedCopilot: CopilotPersona?
    private(set) var selectedCodingLevel: PersonalizationCodingLevel = .beginner
    private(set) var currentPage: PersonalizationPage = .copilot

    @ObservationIgnored
    private let profileStore: UserProfileStore

    init(profileStore: UserProfileStore = UserProfileStore()) {
        self.profileStore = profileStore
        isCompleted = profileStore.isSurveyCompleted
        selectedCopilot = nil
    }

    var shouldPresent: Bool {
        !isCompleted
    }

    func toggleCopilot(_ persona: CopilotPersona) {
        selectedCopilot = selectedCopilot == persona ? nil : persona
    }

    func showCodingLevel() {
        guard selectedCopilot != nil else { return }
        currentPage = .codingLevel
    }

    func showCopilot() {
        currentPage = .copilot
    }

    func selectCodingLevel(_ level: PersonalizationCodingLevel) {
        selectedCodingLevel = level
    }

    func complete() {
        guard let selectedCopilot else { return }
        profileStore.saveAnswers(
            PersonalizationSurveyAnswers(
                selections: ["coding_level": selectedCodingLevel.answerID],
                selectedCopilot: selectedCopilot
            )
        )
        isCompleted = true
        profileStore.isSurveyCompleted = true
    }

    func skip() {
        isCompleted = true
        profileStore.isSurveyCompleted = true
    }

    func reset() {
        isCompleted = false
        selectedCopilot = nil
        selectedCodingLevel = .beginner
        currentPage = .copilot
        profileStore.resetSurvey()
    }
}
