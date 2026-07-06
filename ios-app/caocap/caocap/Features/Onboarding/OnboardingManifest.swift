import Foundation

/// Content data for a single onboarding step shown inside `OnboardingPopoverCard`.
struct OnboardingStepContent: Equatable {
    /// The onboarding step this content belongs to; used for lookup in `OnboardingManifest`.
    let step: OnboardingCoordinator.Step
    /// Catalog key for the short headline shown in bold at the top of the popover card.
    let titleKey: String
    /// Catalog key for the descriptive body copy explaining what the user should do on this step.
    let messageKey: String
    /// SF Symbol name for the step icon displayed in the card header.
    let icon: String
}

/// Static registry of all first-run onboarding steps.
/// Each step has its content defined here; `OnboardingCoordinator` drives the sequence.
/// To add a new step: add the case to `OnboardingCoordinator.Step`, add the content here,
/// assign it to a lesson in `OnboardingLessonsManifest`, and handle the anchor in `OnboardingPopoverCard`.
enum OnboardingManifest {
    static let steps: [OnboardingStepContent] = [
        OnboardingStepContent(
            step: .openTutorial,
            titleKey: "onboarding.openTutorial.title",
            messageKey: "onboarding.openTutorial.message",
            icon: "graduationcap.fill"
        ),
        OnboardingStepContent(
            step: .tapFAB,
            titleKey: "onboarding.tapFAB.title",
            messageKey: "onboarding.tapFAB.message",
            icon: "hand.tap"
        ),
        OnboardingStepContent(
            step: .typeCoCaptainPrompt,
            titleKey: "onboarding.typeCoCaptainPrompt.title",
            messageKey: "onboarding.typeCoCaptainPrompt.message",
            icon: "keyboard"
        ),
        OnboardingStepContent(
            step: .submitCoCaptainPrompt,
            titleKey: "onboarding.submitCoCaptainPrompt.title",
            messageKey: "onboarding.submitCoCaptainPrompt.message",
            icon: "sparkles"
        ),
        OnboardingStepContent(
            step: .chatCoCaptain,
            titleKey: "onboarding.chatCoCaptain.title",
            messageKey: "onboarding.chatCoCaptain.message",
            icon: "bubble.left.and.text.bubble.right"
        ),
        OnboardingStepContent(
            step: .dismissCoCaptain,
            titleKey: "onboarding.dismissCoCaptain.title",
            messageKey: "onboarding.dismissCoCaptain.message",
            icon: "arrow.down"
        ),
        OnboardingStepContent(
            step: .longPressFAB,
            titleKey: "onboarding.longPressFAB.title",
            messageKey: "onboarding.longPressFAB.message",
            icon: "hand.tap.fill"
        ),
        OnboardingStepContent(
            step: .panCanvas,
            titleKey: "onboarding.panCanvas.title",
            messageKey: "onboarding.panCanvas.message",
            icon: "hand.draw"
        ),
        OnboardingStepContent(
            step: .pinchZoom,
            titleKey: "onboarding.pinchZoom.title",
            messageKey: "onboarding.pinchZoom.message",
            icon: "arrow.up.left.and.arrow.down.right"
        ),
        OnboardingStepContent(
            step: .fitAllNodes,
            titleKey: "onboarding.fitAllNodes.title",
            messageKey: "onboarding.fitAllNodes.message",
            icon: "arrow.up.left.and.down.right.magnifyingglass"
        ),
        OnboardingStepContent(
            step: .searchFlyToNode,
            titleKey: "onboarding.searchFlyToNode.title",
            messageKey: "onboarding.searchFlyToNode.message",
            icon: "magnifyingglass"
        ),
        OnboardingStepContent(
            step: .openPortal,
            titleKey: "onboarding.openPortal.title",
            messageKey: "onboarding.openPortal.message",
            icon: "arrow.right.circle.fill"
        ),
        OnboardingStepContent(
            step: .returnToRoot,
            titleKey: "onboarding.returnToRoot.title",
            messageKey: "onboarding.returnToRoot.message",
            icon: "arrow.uturn.backward.circle.fill"
        ),
        OnboardingStepContent(
            step: .tapMiniAppNode,
            titleKey: "onboarding.tapMiniAppNode.title",
            messageKey: "onboarding.tapMiniAppNode.message",
            icon: "play.circle.fill"
        ),
        OnboardingStepContent(
            step: .interactMiniAppPreview,
            titleKey: "onboarding.interactMiniAppPreview.title",
            messageKey: "onboarding.interactMiniAppPreview.message",
            icon: "hand.tap"
        ),
        OnboardingStepContent(
            step: .openMiniAppOmnibox,
            titleKey: "onboarding.openMiniAppOmnibox.title",
            messageKey: "onboarding.openMiniAppOmnibox.message",
            icon: "command"
        ),
        OnboardingStepContent(
            step: .openMiniAppCodeTool,
            titleKey: "onboarding.openMiniAppCodeTool.title",
            messageKey: "onboarding.openMiniAppCodeTool.message",
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        OnboardingStepContent(
            step: .saveMiniAppCodeEdit,
            titleKey: "onboarding.saveMiniAppCodeEdit.title",
            messageKey: "onboarding.saveMiniAppCodeEdit.message",
            icon: "square.and.pencil"
        ),
        OnboardingStepContent(
            step: .returnFromMiniAppPreview,
            titleKey: "onboarding.returnFromMiniAppPreview.title",
            messageKey: "onboarding.returnFromMiniAppPreview.message",
            icon: "arrow.uturn.backward"
        ),
        OnboardingStepContent(
            step: .dragCanvasNode,
            titleKey: "onboarding.dragCanvasNode.title",
            messageKey: "onboarding.dragCanvasNode.message",
            icon: "arrow.up.and.down.and.arrow.left.and.right"
        ),
        OnboardingStepContent(
            step: .openWorkspaceOmnibox,
            titleKey: "onboarding.openWorkspaceOmnibox.title",
            messageKey: "onboarding.openWorkspaceOmnibox.message",
            icon: "command"
        ),
        OnboardingStepContent(
            step: .runOrganizeNodes,
            titleKey: "onboarding.runOrganizeNodes.title",
            messageKey: "onboarding.runOrganizeNodes.message",
            icon: "wand.and.stars"
        ),
        OnboardingStepContent(
            step: .runToggleGrid,
            titleKey: "onboarding.runToggleGrid.title",
            messageKey: "onboarding.runToggleGrid.message",
            icon: "grid"
        ),
        OnboardingStepContent(
            step: .undoCanvasEdit,
            titleKey: "onboarding.undoCanvasEdit.title",
            messageKey: "onboarding.undoCanvasEdit.message",
            icon: "arrow.uturn.backward"
        ),
        OnboardingStepContent(
            step: .redoCanvasEdit,
            titleKey: "onboarding.redoCanvasEdit.title",
            messageKey: "onboarding.redoCanvasEdit.message",
            icon: "arrow.uturn.forward"
        )
    ]

    /// The step to show first; `nil` if the steps array is somehow empty.
    static var firstStep: OnboardingCoordinator.Step? {
        OnboardingLessonsManifest.allSteps.first
    }

    /// Returns the content for a given step. Crashes with a `preconditionFailure` if
    /// the manifest is missing a step entry, which would indicate a programming error.
    static func content(for step: OnboardingCoordinator.Step) -> OnboardingStepContent {
        guard let content = steps.first(where: { $0.step == step }) else {
            preconditionFailure("Missing onboarding manifest content for \(step)")
        }
        return content
    }

    /// Returns the next step after the given one across the full tutorial sequence.
    static func nextStep(after step: OnboardingCoordinator.Step) -> OnboardingCoordinator.Step? {
        guard let index = OnboardingLessonsManifest.allSteps.firstIndex(of: step) else { return nil }
        let nextIndex = OnboardingLessonsManifest.allSteps.index(after: index)
        guard OnboardingLessonsManifest.allSteps.indices.contains(nextIndex) else { return nil }
        return OnboardingLessonsManifest.allSteps[nextIndex]
    }

    /// Human-readable progress label such as "3 of 4" scoped to the active lesson.
    static func stepLabel(
        for step: OnboardingCoordinator.Step,
        lessonID: OnboardingLessonID?,
        language: String? = nil
    ) -> String {
        guard let lessonID else { return "" }
        return OnboardingLessonsManifest.stepLabel(for: step, in: lessonID, language: language)
    }
}
