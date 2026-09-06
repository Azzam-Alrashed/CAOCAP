import Foundation

/// Content data for a single onboarding step shown inside `OnboardingPopoverCard`.
struct OnboardingStepContent: Equatable {
    let step: OnboardingCoordinator.Step
    let titleKey: String
    let messageKey: String
    let icon: String
}

/// Static registry of all first-run onboarding steps.
enum OnboardingManifest {
    static let steps: [OnboardingStepContent] = OnboardingCoordinator.Step.allCases.map { step in
        switch step {
        case .openTutorial:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.openTutorial.title",
                messageKey: "onboarding.openTutorial.message",
                icon: "graduationcap.fill"
            )
        case .panCanvas:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.panCanvas.title",
                messageKey: "onboarding.panCanvas.message",
                icon: "hand.draw"
            )
        case .pinchZoom:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.pinchZoom.title",
                messageKey: "onboarding.pinchZoom.message",
                icon: "arrow.up.left.and.arrow.down.right"
            )
        case .fitAllNodes:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.fitAllNodes.title",
                messageKey: "onboarding.fitAllNodes.message",
                icon: "arrow.up.left.and.down.right.magnifyingglass"
            )
        case .tapFAB:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.tapFAB.title",
                messageKey: "onboarding.tapFAB.message",
                icon: "hand.tap"
            )
        case .openPortal:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.openPortal.title",
                messageKey: "onboarding.openPortal.message",
                icon: "arrow.right.circle.fill"
            )
        case .chatCoCaptainGameEdit:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.chatCoCaptainGameEdit.title",
                messageKey: "onboarding.chatCoCaptainGameEdit.message",
                icon: "gamecontroller.fill"
            )
        case .browseHelpGuides:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.browseHelpGuides.title",
                messageKey: "onboarding.browseHelpGuides.message",
                icon: "book.fill"
            )
        case .chatCoCaptain:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.chatCoCaptain.title",
                messageKey: "onboarding.chatCoCaptain.message",
                icon: "bubble.left.and.text.bubble.right"
            )
        case .reviewCoCaptainChange:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.reviewCoCaptainChange.title",
                messageKey: "onboarding.reviewCoCaptainChange.message",
                icon: "doc.text.magnifyingglass"
            )
        case .applyCoCaptainChange:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.applyCoCaptainChange.title",
                messageKey: "onboarding.applyCoCaptainChange.message",
                icon: "checkmark.circle.fill"
            )
        case .dismissCoCaptain:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.dismissCoCaptain.title",
                messageKey: "onboarding.dismissCoCaptain.message",
                icon: "arrow.down"
            )
        case .longPressFAB:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.longPressFAB.title",
                messageKey: "onboarding.longPressFAB.message",
                icon: "hand.tap.fill"
            )
        case .dragCanvasNode:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.dragCanvasNode.title",
                messageKey: "onboarding.dragCanvasNode.message",
                icon: "arrow.up.and.down.and.arrow.left.and.right"
            )
        }
    }

    static func content(for step: OnboardingCoordinator.Step) -> OnboardingStepContent {
        guard let content = steps.first(where: { $0.step == step }) else {
            preconditionFailure("Missing onboarding manifest content for \(step)")
        }
        return content
    }
}
