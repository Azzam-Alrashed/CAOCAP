import SwiftUI

/// Identifies one interactive tutorial lesson shown in Help and during first-run onboarding.
public enum OnboardingLessonID: String, CaseIterable, Hashable {
    case canvasBasics
    case omniboxNavigation
    case miniAppPreview
    case coCaptainChat
    case moveAndOrganize
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
        .canvasBasics,
        .omniboxNavigation,
        .miniAppPreview
    ]
    static let optionalLessonIDs: [OnboardingLessonID] = [
        .coCaptainChat,
        .moveAndOrganize
    ]

    static let lessons: [OnboardingLesson] = [
        OnboardingLesson(
            id: .canvasBasics,
            titleKey: "onboarding.lesson.canvasBasics.title",
            subtitleKey: "onboarding.lesson.canvasBasics.subtitle",
            icon: "graduationcap.fill",
            accentHex: "00B894",
            steps: [
                .openTutorial,
                .tapFAB,
                .typeCoCaptainPrompt,
                .submitCoCaptainPrompt,
                .chatCoCaptain,
                .applyCoCaptainChange,
                .tapGoBackAction
            ]
        ),
        OnboardingLesson(
            id: .omniboxNavigation,
            titleKey: "onboarding.lesson.omniboxNavigation.title",
            subtitleKey: "onboarding.lesson.omniboxNavigation.subtitle",
            icon: "command",
            accentHex: "F39C12",
            steps: [
                .searchFlyToNode,
                .openPortal,
                .chatCoCaptainGameEdit,
                .reviewCoCaptainChange
            ]
        ),
        OnboardingLesson(
            id: .miniAppPreview,
            titleKey: "onboarding.lesson.miniAppPreview.title",
            subtitleKey: "onboarding.lesson.miniAppPreview.subtitle",
            icon: "book.fill",
            accentHex: "E84393",
            steps: [
                .openHelpCenter,
                .browseHelpGuides
            ]
        ),
        OnboardingLesson(
            id: .coCaptainChat,
            titleKey: "onboarding.lesson.coCaptainChat.title",
            subtitleKey: "onboarding.lesson.coCaptainChat.subtitle",
            icon: "sparkles",
            accentHex: "6C5CE7",
            steps: [
                .returnToRoot,
                .longPressFAB,
                .dismissCoCaptain,
                .tapMiniAppNode,
                .interactMiniAppPreview,
                .openMiniAppCodeTool,
                .saveMiniAppCodeEdit,
                .returnFromMiniAppPreview
            ]
        ),
        OnboardingLesson(
            id: .moveAndOrganize,
            titleKey: "onboarding.lesson.moveAndOrganize.title",
            subtitleKey: "onboarding.lesson.moveAndOrganize.subtitle",
            icon: "arrow.up.and.down.and.arrow.left.and.right",
            accentHex: "74B9FF",
            steps: [
                .typeGoBackInOmnibox,
                .panCanvas,
                .pinchZoom,
                .fitAllNodes,
                .dragCanvasNode,
                .runOrganizeNodes,
                .undoCanvasEdit,
                .redoCanvasEdit
            ]
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
