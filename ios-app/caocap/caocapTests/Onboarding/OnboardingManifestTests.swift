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

        #expect(lessonSteps == OnboardingCoordinator.Step.allCases)
        #expect(Set(lessonSteps).count == OnboardingCoordinator.Step.allCases.count)

        for lesson in OnboardingLessonsManifest.lessons {
            #expect(lesson.steps.count <= OnboardingLessonsManifest.maxStepsPerLesson)
        }
    }

    @Test func manifestDrivesStepLabelsAndProgression() {
        #expect(OnboardingManifest.firstStep == .openTutorial)
        #expect(OnboardingManifest.nextStep(after: .openTutorial) == .panCanvas)
        #expect(OnboardingManifest.nextStep(after: .panCanvas) == .pinchZoom)
        #expect(OnboardingManifest.nextStep(after: .pinchZoom) == .fitAllNodes)
        #expect(OnboardingManifest.nextStep(after: .fitAllNodes) == .tapFAB)
        #expect(OnboardingManifest.nextStep(after: .tapFAB) == .returnToRoot)
        #expect(OnboardingManifest.nextStep(after: .returnToRoot) == .typeGoBackInOmnibox)
        #expect(OnboardingManifest.nextStep(after: .typeGoBackInOmnibox) == .tapGoBackAction)
        #expect(OnboardingManifest.nextStep(after: .tapGoBackAction) == .searchFlyToNode)
        #expect(OnboardingManifest.nextStep(after: .searchFlyToNode) == .openPortal)
        #expect(OnboardingManifest.nextStep(after: .openPortal) == .tapMiniAppNode)
        #expect(OnboardingManifest.nextStep(after: .tapMiniAppNode) == .interactMiniAppPreview)
        #expect(OnboardingManifest.nextStep(after: .interactMiniAppPreview) == .openMiniAppCodeTool)
        #expect(OnboardingManifest.nextStep(after: .openMiniAppCodeTool) == .saveMiniAppCodeEdit)
        #expect(OnboardingManifest.nextStep(after: .saveMiniAppCodeEdit) == .returnFromMiniAppPreview)
        #expect(OnboardingManifest.nextStep(after: .returnFromMiniAppPreview) == .typeCoCaptainPrompt)
        #expect(OnboardingManifest.nextStep(after: .typeCoCaptainPrompt) == .submitCoCaptainPrompt)
        #expect(OnboardingManifest.nextStep(after: .submitCoCaptainPrompt) == .chatCoCaptain)
        #expect(OnboardingManifest.nextStep(after: .chatCoCaptain) == .reviewCoCaptainChange)
        #expect(OnboardingManifest.nextStep(after: .reviewCoCaptainChange) == .applyCoCaptainChange)
        #expect(OnboardingManifest.nextStep(after: .applyCoCaptainChange) == .dismissCoCaptain)
        #expect(OnboardingManifest.nextStep(after: .dismissCoCaptain) == .longPressFAB)
        #expect(OnboardingManifest.nextStep(after: .longPressFAB) == .dragCanvasNode)
        #expect(OnboardingManifest.nextStep(after: .dragCanvasNode) == .runOrganizeNodes)
        #expect(OnboardingManifest.nextStep(after: .runOrganizeNodes) == .undoCanvasEdit)
        #expect(OnboardingManifest.nextStep(after: .undoCanvasEdit) == .redoCanvasEdit)
        #expect(OnboardingManifest.nextStep(after: .redoCanvasEdit) == nil)

        #expect(OnboardingLessonsManifest.lessons.count == 5)
        #expect(OnboardingLessonsManifest.lesson(for: .canvasBasics).steps == [
            .openTutorial,
            .panCanvas,
            .pinchZoom,
            .fitAllNodes,
            .tapFAB
        ])
        #expect(OnboardingLessonsManifest.lesson(for: .omniboxNavigation).steps == [
            .returnToRoot,
            .typeGoBackInOmnibox,
            .tapGoBackAction,
            .searchFlyToNode,
            .openPortal
        ])
        #expect(OnboardingLessonsManifest.lesson(for: .miniAppPreview).steps == [
            .tapMiniAppNode,
            .interactMiniAppPreview,
            .openMiniAppCodeTool,
            .saveMiniAppCodeEdit,
            .returnFromMiniAppPreview
        ])
        #expect(OnboardingLessonsManifest.lesson(for: .coCaptainChat).steps == [
            .typeCoCaptainPrompt,
            .submitCoCaptainPrompt,
            .chatCoCaptain,
            .reviewCoCaptainChange,
            .applyCoCaptainChange,
            .dismissCoCaptain,
            .longPressFAB
        ])
        #expect(OnboardingLessonsManifest.lesson(for: .moveAndOrganize).steps == [
            .dragCanvasNode,
            .runOrganizeNodes,
            .undoCanvasEdit,
            .redoCanvasEdit
        ])
        #expect(
            OnboardingManifest.stepLabel(
                for: .openTutorial,
                lessonID: .canvasBasics,
                language: "English"
            ) == "1 of 5"
        )
        #expect(
            OnboardingManifest.stepLabel(
                for: .tapFAB,
                lessonID: .canvasBasics,
                language: "English"
            ) == "5 of 5"
        )
        #expect(
            OnboardingManifest.stepLabel(
                for: .typeCoCaptainPrompt,
                lessonID: .coCaptainChat,
                language: "English"
            ) == "1 of 7"
        )
        #expect(
            OnboardingManifest.stepLabel(
                for: .dragCanvasNode,
                lessonID: .moveAndOrganize,
                language: "English"
            ) == "1 of 4"
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
        #expect(OnboardingCoordinator.Step.openPortal.tooltipAnchor == .tutorialNode)
        #expect(OnboardingCoordinator.Step.tapFAB.tooltipAnchor == .floatingCommandButton)
        #expect(OnboardingCoordinator.Step.typeCoCaptainPrompt.tooltipAnchor == .omniboxSearchField)
        #expect(OnboardingCoordinator.Step.submitCoCaptainPrompt.tooltipAnchor == .omniboxPromptRow)
        #expect(OnboardingCoordinator.Step.chatCoCaptain.tooltipAnchor == .coCaptainInput)
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
            OnboardingCoordinator.Step.typeGoBackInOmnibox.resolvedTooltipAnchor(isCommandPalettePresented: true)
                == .omniboxSearchField
        )
        #expect(
            OnboardingCoordinator.Step.tapGoBackAction.resolvedTooltipAnchor(isCommandPalettePresented: true)
                == .commandPaletteGoBack
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
        let onboarding = OnboardingCoordinator(analytics: NoOpAnalyticsService())
        onboarding.currentStep = .chatCoCaptain
        onboarding.activeLessonID = .coCaptainChat
        onboarding.showPopover = true

        onboarding.hidePopoverForCurrentStep()

        #expect(onboarding.currentStep == .chatCoCaptain)
        #expect(!onboarding.showPopover)
    }

    @MainActor
    @Test func guidedEditCompletionAdvancesToReviewStep() {
        let onboarding = OnboardingCoordinator(analytics: NoOpAnalyticsService())
        onboarding.currentStep = .chatCoCaptain
        onboarding.activeLessonID = .coCaptainChat

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

        #expect(onboarding.currentStep == .reviewCoCaptainChange)
    }

    @MainActor
    @Test func failedGuidedEditCompletionDoesNotAdvanceFromChatStep() {
        let onboarding = OnboardingCoordinator(analytics: NoOpAnalyticsService())
        onboarding.currentStep = .chatCoCaptain
        onboarding.activeLessonID = .coCaptainChat

        let completion = CoCaptainTurnCompletion(
            turnID: UUID(),
            purpose: .onboardingGuidedEdit,
            succeeded: false
        )

        #expect(!completion.shouldAdvanceToOnboardingReview)

        if completion.shouldAdvanceToOnboardingReview {
            onboarding.completeCurrentStep()
        }

        #expect(onboarding.currentStep == .chatCoCaptain)
    }

    @MainActor
    @Test func standaloneLessonCompletionDoesNotAutoStartNextLesson() {
        let onboarding = OnboardingCoordinator(analytics: NoOpAnalyticsService())
        onboarding.startLesson(.canvasBasics, advancesThroughLessons: false)
        onboarding.currentStep = .tapFAB

        onboarding.completeCurrentStep()

        #expect(onboarding.isLessonCompleted(.canvasBasics))
        #expect(onboarding.currentStep == nil)
        #expect(onboarding.activeLessonID == nil)
        #expect(!onboarding.isLessonCompleted(.omniboxNavigation))
    }

    @MainActor
    @Test func firstRunLessonCompletionAdvancesToNextLesson() {
        let onboarding = OnboardingCoordinator(analytics: NoOpAnalyticsService())
        onboarding.startLesson(.canvasBasics, advancesThroughLessons: true)
        onboarding.currentStep = .tapFAB
        onboarding.showPopover = true

        onboarding.completeCurrentStep()

        #expect(onboarding.isLessonCompleted(.canvasBasics))
        #expect(onboarding.activeLessonID == .omniboxNavigation)
        #expect(onboarding.currentStep == .returnToRoot)
    }

    @MainActor
    @Test func lessonWillStartCallbackFiresBeforeFirstStep() {
        let onboarding = OnboardingCoordinator(analytics: NoOpAnalyticsService())
        var startedLesson: OnboardingLessonID?
        onboarding.onLessonWillStart = { startedLesson = $0 }

        onboarding.startLesson(.omniboxNavigation, advancesThroughLessons: false)

        #expect(startedLesson == .omniboxNavigation)
        #expect(onboarding.currentStep == .returnToRoot)
    }

    @MainActor
    @Test func skipMarksOnlyActiveLessonComplete() {
        let onboarding = OnboardingCoordinator(analytics: NoOpAnalyticsService())
        onboarding.startLesson(.canvasBasics, advancesThroughLessons: true)
        onboarding.skip()

        #expect(onboarding.isLessonCompleted(.canvasBasics))
        #expect(!onboarding.isLessonCompleted(.omniboxNavigation))
        #expect(onboarding.activeLessonID == .omniboxNavigation)
    }

    @Test func tutorialCanvasProviderSeedsPracticeMiniApp() {
        #expect(TutorialCanvasProvider.snapshot.nodes.count == 1)
        #expect(TutorialCanvasProvider.snapshot.nodes.first?.id == TutorialCanvasProvider.miniAppNodeID)
        #expect(TutorialCanvasProvider.snapshot.nodes.first?.type == .miniApp)
    }

    @Test func newLessonStepsBlockCoCaptainPromptSubmission() {
        #expect(OnboardingCoordinator.Step.tapMiniAppNode.blocksCoCaptainPrompt)
        #expect(OnboardingCoordinator.Step.dragCanvasNode.blocksCoCaptainPrompt)
        #expect(OnboardingCoordinator.Step.runOrganizeNodes.blocksCoCaptainPrompt)
        #expect(!OnboardingCoordinator.Step.chatCoCaptain.blocksCoCaptainPrompt)
    }

    @Test func onboardingReviewFixtureTargetsHelloWorldHeadline() {
        let nodeID = TutorialCanvasProvider.miniAppNodeID
        let baseText = TutorialCanvasProvider.practiceMiniAppNode.miniApp?.codeText ?? ""
        let bundle = OnboardingCoCaptainReviewFixture.makeBundle(nodeID: nodeID, baseText: baseText)

        #expect(bundle.items.count == 1)
        #expect(bundle.items.first?.preview.contains("Hello from CoCaptain!") == true)
    }
}
