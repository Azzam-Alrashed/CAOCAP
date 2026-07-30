import Foundation
import Observation

enum PersonalizationPage {
    case copilot
    case codingLevel
    case final
}

enum PersonalizationFlowResult {
    case continueInPersonalization
    case returnToIntro
    case finished
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

/// Owns Personalization state, valid page transitions, and persisted completion.
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

    var canAdvance: Bool {
        switch currentPage {
        case .copilot:
            return selectedCopilot != nil
        case .codingLevel:
            return true
        case .final:
            return false
        }
    }

    func toggleCopilot(_ persona: CopilotPersona) {
        selectedCopilot = selectedCopilot == persona ? nil : persona
    }

    func advance() -> PersonalizationFlowResult {
        switch currentPage {
        case .copilot:
            guard canAdvance else { return .continueInPersonalization }
            currentPage = .codingLevel
        case .codingLevel:
            currentPage = .final
        case .final:
            return .continueInPersonalization
        }

        return .continueInPersonalization
    }

    func back() -> PersonalizationFlowResult {
        switch currentPage {
        case .copilot:
            return .returnToIntro
        case .codingLevel:
            currentPage = .copilot
        case .final:
            currentPage = .codingLevel
        }

        return .continueInPersonalization
    }

    func selectCodingLevel(_ level: PersonalizationCodingLevel) {
        selectedCodingLevel = level
    }

    func complete() -> PersonalizationFlowResult {
        guard currentPage == .final, let selectedCopilot else {
            return .continueInPersonalization
        }
        profileStore.saveAnswers(
            PersonalizationSurveyAnswers(
                selections: ["coding_level": selectedCodingLevel.answerID],
                selectedCopilot: selectedCopilot
            )
        )
        isCompleted = true
        profileStore.isSurveyCompleted = true
        return .finished
    }

    func skip() -> PersonalizationFlowResult {
        isCompleted = true
        profileStore.isSurveyCompleted = true
        return .finished
    }

    func reset() {
        isCompleted = false
        selectedCopilot = nil
        selectedCodingLevel = .beginner
        currentPage = .copilot
        profileStore.resetSurvey()
    }
}
