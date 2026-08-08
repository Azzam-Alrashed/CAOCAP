import SwiftUI

/// Identifies the interactive tutorial lesson shown in Help and during first-run onboarding.
public enum OnboardingLessonID: String, CaseIterable, Hashable {
    /// Single first-run lesson: open the Hello World mini-app fullscreen.
    case canvasBasics
}

/// A grouped tutorial lesson with at most nine gesture-driven steps.
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
    static let maxStepsPerLesson = 9
    static let mainLessonIDs: [OnboardingLessonID] = [
        .canvasBasics
    ]

    static let lessons: [OnboardingLesson] = [
        OnboardingLesson(
            id: .canvasBasics,
            titleKey: "onboarding.lesson.canvasBasics.title",
            subtitleKey: "onboarding.lesson.canvasBasics.subtitle",
            icon: "rectangle.portrait.on.rectangle.portrait.fill",
            accentHex: "00B894",
            steps: [
                .openPortal
            ]
        )
    ]

    static func lesson(for id: OnboardingLessonID) -> OnboardingLesson {
        guard let lesson = lessons.first(where: { $0.id == id }) else {
            preconditionFailure("Missing onboarding lesson for \(id)")
        }
        return lesson
    }

    static func lesson(containing step: OnboardingCoordinator.Step) -> OnboardingLesson? {
        lessons.first { $0.steps.contains(step) }
    }

    static func firstIncompleteLesson(
        completedLessonIDs: Set<OnboardingLessonID>
    ) -> OnboardingLessonID? {
        mainLessonIDs.first { !completedLessonIDs.contains($0) }
    }

    static func nextMainLesson(after id: OnboardingLessonID) -> OnboardingLessonID? {
        guard let index = mainLessonIDs.firstIndex(of: id) else { return nil }
        let nextIndex = mainLessonIDs.index(after: index)
        guard mainLessonIDs.indices.contains(nextIndex) else { return nil }
        return mainLessonIDs[nextIndex]
    }

    static func areAllMainLessonsCompleted(completedLessonIDs: Set<OnboardingLessonID>) -> Bool {
        mainLessonIDs.allSatisfy { completedLessonIDs.contains($0) }
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
