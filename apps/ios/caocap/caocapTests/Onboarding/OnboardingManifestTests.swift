import Foundation
import Testing
@testable import caocap

struct OnboardingManifestTests {
    @Test func manifestDefinesEveryCoordinatorStepOnce() {
        let manifestSteps = OnboardingManifest.steps.map(\.step)

        #expect(manifestSteps == OnboardingCoordinator.Step.allCases)
        #expect(Set(manifestSteps).count == OnboardingCoordinator.Step.allCases.count)
    }

    @Test func lessonsCoverEveryStepOnceWithNineOrFewerStepsEach() {
        let lessonSteps = OnboardingLessonsManifest.lessons.flatMap(\.steps)

        #expect(Set(lessonSteps) == Set(OnboardingCoordinator.Step.allCases))
        #expect(lessonSteps.count == OnboardingCoordinator.Step.allCases.count)

        for lesson in OnboardingLessonsManifest.lessons {
            #expect(lesson.steps.count <= OnboardingLessonsManifest.maxStepsPerLesson)
        }
    }

    @Test func lessonsDriveScopedProgressionAndLabels() {
        #expect(OnboardingLessonsManifest.lessons.count == 5)
        #expect(OnboardingLessonsManifest.mainLessonIDs == [.canvasBasics, .omniboxNavigation, .miniAppPreview])
        #expect(OnboardingLessonsManifest.optionalLessonIDs == [.coCaptainChat, .moveAndOrganize])

        #expect(OnboardingLessonsManifest.lesson(for: .canvasBasics).steps == [
            .openTutorial,
            .tapFAB,
            .typeCoCaptainPrompt,
            .submitCoCaptainPrompt,
            .chatCoCaptain,
            .applyCoCaptainChange,
            .tapGoBackAction
        ])
        #expect(OnboardingLessonsManifest.lesson(for: .omniboxNavigation).steps == [
            .searchFlyToNode,
            .openPortal,
            .chatCoCaptainGameEdit,
            .reviewCoCaptainChange
        ])
        #expect(OnboardingLessonsManifest.lesson(for: .miniAppPreview).steps == [
            .openHelpCenter,
            .browseHelpGuides
        ])
        #expect(OnboardingLessonsManifest.lesson(for: .coCaptainChat).steps == [
            .returnToRoot,
            .longPressFAB,
            .dismissCoCaptain,
            .tapMiniAppNode,
            .interactMiniAppPreview,
            .openMiniAppCodeTool,
            .saveMiniAppCodeEdit,
            .returnFromMiniAppPreview
        ])
        #expect(OnboardingLessonsManifest.lesson(for: .moveAndOrganize).steps == [
            .typeGoBackInOmnibox,
            .panCanvas,
            .pinchZoom,
            .fitAllNodes,
            .dragCanvasNode,
            .runOrganizeNodes,
            .undoCanvasEdit,
            .redoCanvasEdit
        ])

        #expect(OnboardingLessonsManifest.nextStep(after: .openTutorial, in: OnboardingLessonsManifest.lesson(for: .canvasBasics)) == .tapFAB)
        #expect(OnboardingLessonsManifest.nextStep(after: .tapFAB, in: OnboardingLessonsManifest.lesson(for: .canvasBasics)) == .typeCoCaptainPrompt)
        #expect(OnboardingLessonsManifest.nextStep(after: .tapGoBackAction, in: OnboardingLessonsManifest.lesson(for: .canvasBasics)) == nil)
        #expect(OnboardingLessonsManifest.nextStep(after: .searchFlyToNode, in: OnboardingLessonsManifest.lesson(for: .omniboxNavigation)) == .openPortal)
        #expect(OnboardingLessonsManifest.nextStep(after: .reviewCoCaptainChange, in: OnboardingLessonsManifest.lesson(for: .omniboxNavigation)) == nil)
        #expect(OnboardingLessonsManifest.nextMainLesson(after: .canvasBasics) == .omniboxNavigation)
        #expect(OnboardingLessonsManifest.nextMainLesson(after: .miniAppPreview) == nil)

        #expect(
            OnboardingLessonsManifest.stepLabel(
                for: .openTutorial,
                in: .canvasBasics,
                language: "English"
            ) == "1 of 7"
        )
        #expect(
            OnboardingLessonsManifest.stepLabel(
                for: .tapGoBackAction,
                in: .canvasBasics,
                language: "English"
            ) == "7 of 7"
        )
        #expect(
            OnboardingLessonsManifest.stepLabel(
                for: .searchFlyToNode,
                in: .omniboxNavigation,
                language: "English"
            ) == "1 of 4"
        )
        #expect(
            OnboardingLessonsManifest.stepLabel(
                for: .dragCanvasNode,
                in: .moveAndOrganize,
                language: "English"
            ) == "5 of 8"
        )
    }

    @Test func catalogResolvesArabicCanvasOnboardingCopy() {
        let title = LocalizationManager.shared.localizedString(
            "onboarding.openTutorial.title",
            language: "Arabic"
        )
        #expect(title == "ادخل إلى البرنامج التعليمي")

        let message = LocalizationManager.shared.localizedString(
            "onboarding.tapFAB.message",
            language: "Arabic"
        )
        #expect(message.contains("لوحة الأوامر"))
    }

    @Test func manifestContentIsReadyForPopoverPresentation() {
        for step in OnboardingCoordinator.Step.allCases {
            let content = OnboardingManifest.content(for: step)

            #expect(!content.titleKey.isEmpty)
            #expect(!content.messageKey.isEmpty)
            #expect(!content.icon.isEmpty)
            #expect(content.step == step)
        }
    }

    @Test func everyOnboardingStepDeclaresASingleTooltipAnchor() {
        #expect(OnboardingCoordinator.Step.openTutorial.tooltipAnchor == .tutorialNode)
        #expect(OnboardingCoordinator.Step.openPortal.tooltipAnchor == .demoGameNode)
        #expect(OnboardingCoordinator.Step.tapFAB.tooltipAnchor == .floatingCommandButton)
        #expect(OnboardingCoordinator.Step.openHelpCenter.tooltipAnchor == .floatingCommandButton)
        #expect(OnboardingCoordinator.Step.browseHelpGuides.tooltipAnchor == .helpGuidesSection)
        #expect(OnboardingCoordinator.Step.typeCoCaptainPrompt.tooltipAnchor == .omniboxSearchField)
        #expect(OnboardingCoordinator.Step.submitCoCaptainPrompt.tooltipAnchor == .omniboxPromptRow)
        #expect(OnboardingCoordinator.Step.chatCoCaptain.tooltipAnchor == .coCaptainInput)
        #expect(OnboardingCoordinator.Step.chatCoCaptainGameEdit.tooltipAnchor == .coCaptainInput)
        #expect(OnboardingCoordinator.Step.reviewCoCaptainChange.tooltipAnchor == .coCaptainReviewApply)
        #expect(OnboardingCoordinator.Step.applyCoCaptainChange.tooltipAnchor == .coCaptainReviewApply)
        #expect(OnboardingCoordinator.Step.dismissCoCaptain.tooltipAnchor == .coCaptainDoneButton)
        #expect(OnboardingCoordinator.Step.longPressFAB.tooltipAnchor == .floatingCommandButton)
        #expect(OnboardingCoordinator.Step.panCanvas.tooltipAnchor == .canvasGestureArea)
        #expect(OnboardingCoordinator.Step.pinchZoom.tooltipAnchor == .canvasHUDZoom)
        #expect(OnboardingCoordinator.Step.fitAllNodes.tooltipAnchor == .canvasGestureArea)
        #expect(OnboardingCoordinator.Step.searchFlyToNode.tooltipAnchor == .floatingCommandButton)
        #expect(OnboardingCoordinator.Step.returnToRoot.tooltipAnchor == .floatingCommandButton)
        #expect(OnboardingCoordinator.Step.typeGoBackInOmnibox.tooltipAnchor == .floatingCommandButton)
        #expect(OnboardingCoordinator.Step.tapGoBackAction.tooltipAnchor == .commandPaletteGoBack)
        #expect(OnboardingCoordinator.Step.tapMiniAppNode.tooltipAnchor == .practiceCanvasNode)
        #expect(OnboardingCoordinator.Step.interactMiniAppPreview.tooltipAnchor == .miniAppPreviewArea)
        #expect(OnboardingCoordinator.Step.openMiniAppCodeTool.tooltipAnchor == .omniboxMiniAppCodeRow)
        #expect(OnboardingCoordinator.Step.saveMiniAppCodeEdit.tooltipAnchor == .miniAppCodeEditorSave)
        #expect(OnboardingCoordinator.Step.returnFromMiniAppPreview.tooltipAnchor == .omniboxBackToCanvasRow)
        #expect(OnboardingCoordinator.Step.dragCanvasNode.tooltipAnchor == .practiceCanvasNode)
        #expect(OnboardingCoordinator.Step.runOrganizeNodes.tooltipAnchor == .omniboxOrganizeRow)
        #expect(OnboardingCoordinator.Step.undoCanvasEdit.tooltipAnchor == .floatingCommandButton)
        #expect(OnboardingCoordinator.Step.redoCanvasEdit.tooltipAnchor == .floatingCommandButton)
        #expect(
            OnboardingCoordinator.Step.undoCanvasEdit.resolvedTooltipAnchor(isCommandPalettePresented: true)
                == .omniboxUndoRow
        )
        #expect(
            OnboardingCoordinator.Step.redoCanvasEdit.resolvedTooltipAnchor(isCommandPalettePresented: true)
                == .omniboxRedoRow
        )
        #expect(
            OnboardingCoordinator.Step.typeGoBackInOmnibox.resolvedTooltipAnchor(isCommandPalettePresented: true)
                == .omniboxSearchField
        )
        #expect(
            OnboardingCoordinator.Step.tapGoBackAction.resolvedTooltipAnchor(isCommandPalettePresented: true)
                == .commandPaletteGoBack
        )
        #expect(
            OnboardingCoordinator.Step.openHelpCenter.resolvedTooltipAnchor(isCommandPalettePresented: true)
                == .commandPaletteHelp
        )
        #expect(
            OnboardingCoordinator.Step.searchFlyToNode.resolvedTooltipAnchor(isCommandPalettePresented: true)
                == .omniboxSearchField
        )
        #expect(
            OnboardingCoordinator.Step.openMiniAppCodeTool.resolvedTooltipAnchor(isCommandPalettePresented: true)
                == .omniboxMiniAppCodeRow
        )
        #expect(
            OnboardingCoordinator.Step.runOrganizeNodes.resolvedTooltipAnchor(isCommandPalettePresented: true)
                == .omniboxOrganizeRow
        )
    }

    @MainActor
    @Test func hidingPopoverDoesNotAdvanceCurrentStep() {
        let onboarding = makeResetOnboardingCoordinator()
        onboarding.currentStep = .chatCoCaptain
        onboarding.activeLessonID = .coCaptainChat
        onboarding.showPopover = true

        onboarding.hidePopoverForCurrentStep()

        #expect(onboarding.currentStep == .chatCoCaptain)
        #expect(!onboarding.showPopover)
    }

    @MainActor
    @Test func guidedEditCompletionAdvancesToReviewStep() {
        let onboarding = makeResetOnboardingCoordinator()
        onboarding.currentStep = .chatCoCaptain
        onboarding.activeLessonID = .canvasBasics

        let completion = CoCaptainTurnCompletion(
            turnID: UUID(),
            purpose: .onboardingGuidedEdit,
            succeeded: true,
            presentedReviewBundle: true
        )

        #expect(completion.shouldAdvanceToOnboardingReview)

        if completion.shouldAdvanceToOnboardingReview {
            onboarding.completeCurrentStep()
        }

        #expect(onboarding.currentStep == .applyCoCaptainChange)
    }

    @MainActor
    @Test func reviewHandoffAdvancesToApplyWhenApplyIsOutsideLesson() {
        let onboarding = makeResetOnboardingCoordinator()
        onboarding.startLesson(.omniboxNavigation, advancesThroughLessons: false)
        onboarding.currentStep = .reviewCoCaptainChange
        onboarding.showPopover = true

        onboarding.completeCurrentStep()

        #expect(onboarding.currentStep == .applyCoCaptainChange)
    }

    @MainActor
    @Test func failedGuidedEditCompletionDoesNotAdvanceFromChatStep() {
        let onboarding = makeResetOnboardingCoordinator()
        onboarding.currentStep = .chatCoCaptainGameEdit
        onboarding.activeLessonID = .omniboxNavigation

        let completion = CoCaptainTurnCompletion(
            turnID: UUID(),
            purpose: .onboardingGuidedEdit,
            succeeded: false
        )

        #expect(!completion.shouldAdvanceToOnboardingReview)

        if completion.shouldAdvanceToOnboardingReview {
            onboarding.completeCurrentStep()
        }

        #expect(onboarding.currentStep == .chatCoCaptainGameEdit)
    }

    @MainActor
    @Test func standaloneLessonCompletionDoesNotAutoStartNextLesson() {
        let onboarding = makeResetOnboardingCoordinator()
        onboarding.startLesson(.canvasBasics, advancesThroughLessons: false)
        onboarding.currentStep = .tapGoBackAction

        onboarding.completeCurrentStep()

        #expect(onboarding.isLessonCompleted(.canvasBasics))
        #expect(onboarding.currentStep == nil)
        #expect(onboarding.activeLessonID == nil)
        #expect(!onboarding.isLessonCompleted(.omniboxNavigation))
    }

    @MainActor
    @Test func firstRunLessonCompletionAdvancesToNextLesson() {
        let onboarding = makeResetOnboardingCoordinator()
        onboarding.startLesson(.canvasBasics, advancesThroughLessons: true)
        onboarding.currentStep = .tapGoBackAction
        onboarding.showPopover = true

        onboarding.completeCurrentStep()

        #expect(onboarding.isLessonCompleted(.canvasBasics))
        #expect(onboarding.activeLessonID == .omniboxNavigation)
        #expect(onboarding.currentStep == .searchFlyToNode)
    }

    @MainActor
    @Test func lessonWillStartCallbackFiresBeforeFirstStep() {
        let onboarding = makeResetOnboardingCoordinator()
        var startedLesson: OnboardingLessonID?
        onboarding.onLessonWillStart = { startedLesson = $0 }

        onboarding.startLesson(.omniboxNavigation, advancesThroughLessons: false)

        #expect(startedLesson == .omniboxNavigation)
        #expect(onboarding.currentStep == .searchFlyToNode)
    }

    @MainActor
    @Test func skipMarksOnlyActiveMainLessonComplete() {
        let onboarding = makeResetOnboardingCoordinator()
        onboarding.startLesson(.canvasBasics, advancesThroughLessons: true)
        onboarding.skip()

        #expect(onboarding.isLessonCompleted(.canvasBasics))
        #expect(!onboarding.isLessonCompleted(.omniboxNavigation))
        #expect(onboarding.activeLessonID == .omniboxNavigation)
    }

    @MainActor
    @Test func completingMainLessonsMarksOnboardingCompleteWithoutOptionalLessons() {
        let onboarding = makeResetOnboardingCoordinator()
        onboarding.startLesson(.canvasBasics, advancesThroughLessons: true)
        onboarding.currentStep = .tapGoBackAction
        onboarding.completeCurrentStep()
        onboarding.currentStep = .applyCoCaptainChange
        onboarding.completeCurrentStep()
        onboarding.currentStep = .browseHelpGuides
        onboarding.completeCurrentStep()

        #expect(onboarding.isCompleted)
        #expect(!onboarding.isLessonCompleted(.coCaptainChat))
        #expect(!onboarding.isLessonCompleted(.moveAndOrganize))
    }

    @Test func newLessonStepsBlockCoCaptainPromptSubmission() {
        #expect(OnboardingCoordinator.Step.tapMiniAppNode.blocksCoCaptainPrompt)
        #expect(OnboardingCoordinator.Step.dragCanvasNode.blocksCoCaptainPrompt)
        #expect(OnboardingCoordinator.Step.runOrganizeNodes.blocksCoCaptainPrompt)
        #expect(!OnboardingCoordinator.Step.chatCoCaptain.blocksCoCaptainPrompt)
    }

    @MainActor
    @Test func onboardingReviewFixtureTargetsHelloWorldHeadline() {
        let nodeID = UUID()
        let baseText = "<h1>Hello World!</h1>"
        let draft = OnboardingCoCaptainReviewFixture.makeDraft(
            nodeID: nodeID,
            baseText: baseText
        )

        #expect(draft.nodeEdits.count == 1)
        #expect(
            draft.nodeEdits.first?.operations.first?.content
                .contains("Hello from CoCaptain!") == true
        )
    }

    @MainActor
    private func makeResetOnboardingCoordinator() -> OnboardingCoordinator {
        let onboarding = OnboardingCoordinator(analytics: NoOpAnalyticsService())
        onboarding.reset()
        return onboarding
    }
}
