import Foundation
import Testing
@testable import caocap

struct OnboardingManifestTests {
    @Test func manifestDefinesEveryCoordinatorStepOnce() {
        let manifestSteps = OnboardingManifest.steps.map(\.step)

        #expect(manifestSteps == OnboardingCoordinator.Step.allCases)
        #expect(Set(manifestSteps).count == OnboardingCoordinator.Step.allCases.count)
    }

    @Test func lessonsKeepUniqueScopedStepsWithNineOrFewerEach() {
        let lessonSteps = OnboardingLessonsManifest.lessons.flatMap(\.steps)

        #expect(Set(lessonSteps).count == lessonSteps.count)

        for lesson in OnboardingLessonsManifest.lessons {
            #expect(lesson.steps.count <= OnboardingLessonsManifest.maxStepsPerLesson)
        }
    }

    @Test func lessonsDriveScopedProgressionAndLabels() {
        #expect(OnboardingLessonsManifest.lessons.count == 1)
        #expect(OnboardingLessonsManifest.mainLessonIDs == [.canvasBasics])
        #expect(OnboardingLessonsManifest.lessons.map(\.id) == OnboardingLessonsManifest.mainLessonIDs)

        #expect(OnboardingLessonsManifest.lesson(for: .canvasBasics).steps == [
            .openPortal
        ])

        #expect(OnboardingLessonsManifest.nextStep(after: .openPortal, in: OnboardingLessonsManifest.lesson(for: .canvasBasics)) == nil)
        #expect(OnboardingLessonsManifest.nextMainLesson(after: .canvasBasics) == nil)

        #expect(
            OnboardingLessonsManifest.stepLabel(
                for: .openPortal,
                in: .canvasBasics,
                language: "English"
            ) == "1 of 1"
        )
    }

    @Test func catalogResolvesArabicCanvasOnboardingCopy() {
        let title = LocalizationManager.shared.localizedString(
            "onboarding.lesson.canvasBasics.title",
            language: "Arabic"
        )
        #expect(title == "افتح تطبيقك المصغّر")

        let message = LocalizationManager.shared.localizedString(
            "onboarding.openPortal.message",
            language: "Arabic"
        )
        #expect(message.contains("Hello World"))
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
        onboarding.currentStep = .openPortal
        onboarding.activeLessonID = .canvasBasics
        onboarding.showPopover = true

        onboarding.hidePopoverForCurrentStep()

        #expect(onboarding.currentStep == .openPortal)
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

        // openPortal is the only lesson step; completing chat finishes the lesson.
        #expect(onboarding.isLessonCompleted(.canvasBasics))
        #expect(onboarding.currentStep == nil)
    }

    @MainActor
    @Test func reviewHandoffAdvancesToApplyWhenApplyIsOutsideLesson() {
        let onboarding = makeResetOnboardingCoordinator()
        onboarding.startLesson(.canvasBasics, advancesThroughLessons: false)
        onboarding.currentStep = .reviewCoCaptainChange
        onboarding.showPopover = true

        onboarding.completeCurrentStep()

        #expect(onboarding.currentStep == .applyCoCaptainChange)
    }

    @MainActor
    @Test func failedGuidedEditCompletionDoesNotAdvanceFromChatStep() {
        let onboarding = makeResetOnboardingCoordinator()
        onboarding.currentStep = .chatCoCaptainGameEdit
        onboarding.activeLessonID = .canvasBasics

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
        onboarding.currentStep = .openPortal

        onboarding.completeCurrentStep()

        #expect(onboarding.isLessonCompleted(.canvasBasics))
        #expect(onboarding.currentStep == nil)
        #expect(onboarding.activeLessonID == nil)
        #expect(onboarding.isCompleted)
    }

    @MainActor
    @Test func firstRunLessonCompletionMarksOnboardingComplete() {
        let onboarding = makeResetOnboardingCoordinator()
        onboarding.startLesson(.canvasBasics, advancesThroughLessons: true)
        onboarding.currentStep = .openPortal
        onboarding.showPopover = true

        onboarding.completeCurrentStep()

        #expect(onboarding.isLessonCompleted(.canvasBasics))
        #expect(onboarding.isCompleted)
        #expect(onboarding.currentStep == nil)
    }

    @MainActor
    @Test func lessonWillStartCallbackFiresBeforeFirstStep() {
        let onboarding = makeResetOnboardingCoordinator()
        var startedLesson: OnboardingLessonID?
        onboarding.onLessonWillStart = { startedLesson = $0 }

        onboarding.startLesson(.canvasBasics, advancesThroughLessons: false)

        #expect(startedLesson == .canvasBasics)
        #expect(onboarding.currentStep == .openPortal)
    }

    @MainActor
    @Test func skipMarksActiveMainLessonComplete() {
        let onboarding = makeResetOnboardingCoordinator()
        onboarding.startLesson(.canvasBasics, advancesThroughLessons: true)
        onboarding.skip()

        #expect(onboarding.isLessonCompleted(.canvasBasics))
        #expect(onboarding.isCompleted)
        #expect(onboarding.activeLessonID == nil)
    }

    @MainActor
    @Test func completingMainLessonsMarksOnboardingComplete() {
        let onboarding = makeResetOnboardingCoordinator()
        onboarding.startLesson(.canvasBasics, advancesThroughLessons: true)
        onboarding.currentStep = .openPortal
        onboarding.completeCurrentStep()

        #expect(onboarding.isCompleted)
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
        #expect(OnboardingCoordinator.Step.openPortal.blocksCoCaptainPrompt)
        #expect(!OnboardingCoordinator.Step.chatCoCaptain.blocksCoCaptainPrompt)
    }

    @MainActor
    @Test func onboardingReviewFixtureTargetsHelloWorldHeadline() {
        let nodeID = TutorialCanvasProvider.miniAppNodeID
        let baseText = TutorialCanvasProvider.practiceMiniAppNode.miniApp?.codeText ?? ""
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
