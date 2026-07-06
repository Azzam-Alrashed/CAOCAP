import SwiftUI

/// Identifies one interactive tutorial lesson shown in Help and during first-run onboarding.
public enum OnboardingLessonID: String, CaseIterable, Hashable {
    case canvasBasics
    case coCaptainChat
    case powerShortcuts
}

/// A grouped tutorial lesson with at most six gesture-driven steps.
struct OnboardingLesson: Identifiable, Hashable {
    let id: OnboardingLessonID
    let titleKey: String
    let subtitleKey: String
    let icon: String
    let accentHex: String
    let steps: [OnboardingCoordinator.Step]

    var accentColor: Color {
        Color(hex: accentHex)
    }
}

/// Static registry of interactive tutorial lessons.
enum OnboardingLessonsManifest {
    static let maxStepsPerLesson = 6

    static let lessons: [OnboardingLesson] = [
        OnboardingLesson(
            id: .canvasBasics,
            titleKey: "onboarding.lesson.canvasBasics.title",
            subtitleKey: "onboarding.lesson.canvasBasics.subtitle",
            icon: "graduationcap.fill",
            accentHex: "00B894",
            steps: [.openTutorial, .tapFAB, .typeCoCaptainPrompt, .submitCoCaptainPrompt]
        ),
        OnboardingLesson(
            id: .coCaptainChat,
            titleKey: "onboarding.lesson.coCaptainChat.title",
            subtitleKey: "onboarding.lesson.coCaptainChat.subtitle",
            icon: "sparkles",
            accentHex: "6C5CE7",
            steps: [.chatCoCaptain, .dismissCoCaptain, .longPressFAB]
        ),
        OnboardingLesson(
            id: .powerShortcuts,
            titleKey: "onboarding.lesson.powerShortcuts.title",
            subtitleKey: "onboarding.lesson.powerShortcuts.subtitle",
            icon: "arrow.uturn.backward.circle.fill",
            accentHex: "F39C12",
            steps: [.returnToRoot]
        )
    ]

    static var allSteps: [OnboardingCoordinator.Step] {
        lessons.flatMap(\.steps)
    }

    static func lesson(for id: OnboardingLessonID) -> OnboardingLesson {
        guard let lesson = lessons.first(where: { $0.id == id }) else {
            preconditionFailure("Missing onboarding lesson for \(id)")
        }
        return lesson
    }

    static func lesson(containing step: OnboardingCoordinator.Step) -> OnboardingLesson? {
        lessons.first { $0.steps.contains(step) }
    }

    static func firstLessonID() -> OnboardingLessonID? {
        lessons.first?.id
    }

    static func nextLesson(after id: OnboardingLessonID) -> OnboardingLessonID? {
        guard let index = lessons.firstIndex(where: { $0.id == id }) else { return nil }
        let nextIndex = lessons.index(after: index)
        guard lessons.indices.contains(nextIndex) else { return nil }
        return lessons[nextIndex].id
    }

    static func firstIncompleteLesson(
        completedLessonIDs: Set<OnboardingLessonID>
    ) -> OnboardingLessonID? {
        lessons.first { !completedLessonIDs.contains($0.id) }?.id
    }

    static func nextStep(
        after step: OnboardingCoordinator.Step,
        in lesson: OnboardingLesson
    ) -> OnboardingCoordinator.Step? {
        guard let index = lesson.steps.firstIndex(of: step) else { return nil }
        let nextIndex = lesson.steps.index(after: index)
        guard lesson.steps.indices.contains(nextIndex) else { return nil }
        return lesson.steps[nextIndex]
    }

    static func stepLabel(
        for step: OnboardingCoordinator.Step,
        in lessonID: OnboardingLessonID,
        language: String? = nil
    ) -> String {
        let lesson = lesson(for: lessonID)
        guard let index = lesson.steps.firstIndex(of: step) else { return "" }
        return LocalizationManager.shared.localizedString(
            "onboarding.canvas.stepLabel",
            arguments: [index + 1, lesson.steps.count],
            language: language
        )
    }
}
