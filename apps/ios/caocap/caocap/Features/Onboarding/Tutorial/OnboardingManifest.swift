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
        case .returnToRoot:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.returnToRoot.title",
                messageKey: "onboarding.returnToRoot.message",
                icon: "arrow.uturn.backward.circle.fill"
            )
        case .typeGoBackInOmnibox:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.typeGoBackInOmnibox.title",
                messageKey: "onboarding.typeGoBackInOmnibox.message",
                icon: "keyboard"
            )
        case .tapGoBackAction:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.tapGoBackAction.title",
                messageKey: "onboarding.tapGoBackAction.message",
                icon: "arrow.uturn.backward"
            )
        case .searchFlyToNode:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.searchFlyToNode.title",
                messageKey: "onboarding.searchFlyToNode.message",
                icon: "magnifyingglass"
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
        case .openHelpCenter:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.openHelpCenter.title",
                messageKey: "onboarding.openHelpCenter.message",
                icon: "questionmark.circle.fill"
            )
        case .browseHelpGuides:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.browseHelpGuides.title",
                messageKey: "onboarding.browseHelpGuides.message",
                icon: "book.fill"
            )
        case .tapMiniAppNode:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.tapMiniAppNode.title",
                messageKey: "onboarding.tapMiniAppNode.message",
                icon: "play.circle.fill"
            )
        case .interactMiniAppPreview:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.interactMiniAppPreview.title",
                messageKey: "onboarding.interactMiniAppPreview.message",
                icon: "hand.tap"
            )
        case .openMiniAppCodeTool:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.openMiniAppCodeTool.title",
                messageKey: "onboarding.openMiniAppCodeTool.message",
                icon: "chevron.left.forwardslash.chevron.right"
            )
        case .saveMiniAppCodeEdit:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.saveMiniAppCodeEdit.title",
                messageKey: "onboarding.saveMiniAppCodeEdit.message",
                icon: "square.and.pencil"
            )
        case .returnFromMiniAppPreview:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.returnFromMiniAppPreview.title",
                messageKey: "onboarding.returnFromMiniAppPreview.message",
                icon: "arrow.uturn.backward"
            )
        case .typeCoCaptainPrompt:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.typeCoCaptainPrompt.title",
                messageKey: "onboarding.typeCoCaptainPrompt.message",
                icon: "keyboard"
            )
        case .submitCoCaptainPrompt:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.submitCoCaptainPrompt.title",
                messageKey: "onboarding.submitCoCaptainPrompt.message",
                icon: "sparkles"
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
        case .runOrganizeNodes:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.runOrganizeNodes.title",
                messageKey: "onboarding.runOrganizeNodes.message",
                icon: "wand.and.stars"
            )
        case .undoCanvasEdit:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.undoCanvasEdit.title",
                messageKey: "onboarding.undoCanvasEdit.message",
                icon: "arrow.uturn.backward"
            )
        case .redoCanvasEdit:
            return OnboardingStepContent(
                step: step,
                titleKey: "onboarding.redoCanvasEdit.title",
                messageKey: "onboarding.redoCanvasEdit.message",
                icon: "arrow.uturn.forward"
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
