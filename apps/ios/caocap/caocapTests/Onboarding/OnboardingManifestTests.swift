import Foundation
import Testing
@testable import caocap

struct OnboardingManifestTests {
    @Test func manifestDefinesEveryCoordinatorStepOnce() {
        let manifestSteps = OnboardingManifest.steps.map(\.step)

        #expect(manifestSteps == OnboardingCoordinator.Step.allCases)
        #expect(Set(manifestSteps).count == OnboardingCoordinator.Step.allCases.count)
    }

    @Test func lessonsCatalogueIsEmpty() {
        #expect(OnboardingLessonsManifest.lessons.isEmpty)
        #expect(OnboardingLessonsManifest.mainLessonIDs.isEmpty)
        #expect(OnboardingLessonsManifest.optionalLessonIDs.isEmpty)
        #expect(OnboardingLessonsManifest.firstIncompleteLesson(completedLessonIDs: []) == nil)
        #expect(!OnboardingLessonsManifest.areAllMainLessonsCompleted(completedLessonIDs: []))
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
        #expect(OnboardingCoordinator.Step.browseHelpGuides.tooltipAnchor == .helpGuidesSection)
        #expect(OnboardingCoordinator.Step.chatCoCaptain.tooltipAnchor == .coCaptainInput)
        #expect(OnboardingCoordinator.Step.chatCoCaptainGameEdit.tooltipAnchor == .coCaptainInput)
        #expect(OnboardingCoordinator.Step.reviewCoCaptainChange.tooltipAnchor == .coCaptainReviewApply)
        #expect(OnboardingCoordinator.Step.applyCoCaptainChange.tooltipAnchor == .coCaptainReviewApply)
        #expect(OnboardingCoordinator.Step.dismissCoCaptain.tooltipAnchor == .coCaptainDoneButton)
        #expect(OnboardingCoordinator.Step.longPressFAB.tooltipAnchor == .floatingCommandButton)
        #expect(OnboardingCoordinator.Step.panCanvas.tooltipAnchor == .canvasGestureArea)
        #expect(OnboardingCoordinator.Step.pinchZoom.tooltipAnchor == .canvasHUDZoom)
        #expect(OnboardingCoordinator.Step.fitAllNodes.tooltipAnchor == .canvasGestureArea)
        #expect(OnboardingCoordinator.Step.dragCanvasNode.tooltipAnchor == .practiceCanvasNode)
    }

    @MainActor
    @Test func startIfNeededDoesNotStartOrCompleteALesson() {
        let onboarding = makeResetOnboardingCoordinator()
        var didAnnounceCompletion = false
        onboarding.onTutorialCompleted = { didAnnounceCompletion = true }

        onboarding.startIfNeeded()

        #expect(!onboarding.isCompleted)
        #expect(onboarding.currentStep == nil)
        #expect(onboarding.activeLessonID == nil)
        #expect(onboarding.completedLessonIDs.isEmpty)
        #expect(!didAnnounceCompletion)
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

    @Test func canvasStepsBlockCoCaptainPromptSubmission() {
        #expect(OnboardingCoordinator.Step.dragCanvasNode.blocksCoCaptainPrompt)
        #expect(OnboardingCoordinator.Step.panCanvas.blocksCoCaptainPrompt)
        #expect(!OnboardingCoordinator.Step.chatCoCaptain.blocksCoCaptainPrompt)
        #expect(!OnboardingCoordinator.Step.tapFAB.blocksCoCaptainPrompt)
    }

    @MainActor
    private func makeResetOnboardingCoordinator() -> OnboardingCoordinator {
        let onboarding = OnboardingCoordinator(analytics: NoOpAnalyticsService())
        onboarding.reset()
        return onboarding
    }
}
