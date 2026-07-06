import Foundation
import Testing
@testable import caocap

struct OnboardingManifestTests {
    @Test func manifestDefinesEveryCoordinatorStepOnce() {
        let manifestSteps = OnboardingManifest.steps.map(\.step)

        #expect(manifestSteps == OnboardingCoordinator.Step.allCases)
        #expect(Set(manifestSteps).count == OnboardingCoordinator.Step.allCases.count)
    }

    @Test func lessonsCoverEveryStepOnceWithSixOrFewerStepsEach() {
        let lessonSteps = OnboardingLessonsManifest.lessons.flatMap(\.steps)

        #expect(lessonSteps == OnboardingCoordinator.Step.allCases)
        #expect(Set(lessonSteps).count == OnboardingCoordinator.Step.allCases.count)

        for lesson in OnboardingLessonsManifest.lessons {
            #expect(lesson.steps.count <= OnboardingLessonsManifest.maxStepsPerLesson)
        }
    }

    @Test func manifestDrivesStepLabelsAndProgression() {
        #expect(OnboardingManifest.firstStep == .openTutorial)
        #expect(OnboardingManifest.nextStep(after: .openTutorial) == .tapFAB)
        #expect(OnboardingManifest.nextStep(after: .tapFAB) == .typeCoCaptainPrompt)
        #expect(OnboardingManifest.nextStep(after: .typeCoCaptainPrompt) == .submitCoCaptainPrompt)
        #expect(OnboardingManifest.nextStep(after: .submitCoCaptainPrompt) == .chatCoCaptain)
        #expect(OnboardingManifest.nextStep(after: .chatCoCaptain) == .dismissCoCaptain)
        #expect(OnboardingManifest.nextStep(after: .dismissCoCaptain) == .longPressFAB)
        #expect(OnboardingManifest.nextStep(after: .longPressFAB) == .returnToRoot)
        #expect(OnboardingManifest.nextStep(after: .returnToRoot) == .panCanvas)
        #expect(OnboardingManifest.nextStep(after: .panCanvas) == .pinchZoom)
        #expect(OnboardingManifest.nextStep(after: .pinchZoom) == .fitAllNodes)
        #expect(OnboardingManifest.nextStep(after: .fitAllNodes) == .searchFlyToNode)
        #expect(OnboardingManifest.nextStep(after: .searchFlyToNode) == .openPortal)
        #expect(OnboardingManifest.nextStep(after: .openPortal) == nil)

        #expect(OnboardingLessonsManifest.lessons.count == 3)
        #expect(OnboardingLessonsManifest.lesson(for: .coCaptainChat).steps == [
            .chatCoCaptain,
            .dismissCoCaptain,
            .longPressFAB
        ])
        #expect(OnboardingLessonsManifest.lesson(for: .canvasNavigation).steps == [
            .returnToRoot,
            .panCanvas,
            .pinchZoom,
            .fitAllNodes,
            .searchFlyToNode,
            .openPortal
        ])
        #expect(
            OnboardingManifest.stepLabel(
                for: .openTutorial,
                lessonID: .canvasBasics,
                language: "English"
            ) == "1 of 4"
        )
        #expect(
            OnboardingManifest.stepLabel(
                for: .tapFAB,
                lessonID: .canvasBasics,
                language: "English"
            ) == "2 of 4"
        )
        #expect(
            OnboardingManifest.stepLabel(
                for: .longPressFAB,
                lessonID: .coCaptainChat,
                language: "English"
            ) == "3 of 3"
        )
        #expect(
            OnboardingManifest.stepLabel(
                for: .returnToRoot,
                lessonID: .canvasNavigation,
                language: "English"
            ) == "1 of 6"
        )
        #expect(
            OnboardingManifest.stepLabel(
                for: .panCanvas,
                lessonID: .canvasNavigation,
                language: "English"
            ) == "2 of 6"
        )
        #expect(
            OnboardingManifest.stepLabel(
                for: .openPortal,
                lessonID: .canvasNavigation,
                language: "English"
            ) == "6 of 6"
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
        #expect(OnboardingCoordinator.Step.dismissCoCaptain.tooltipAnchor == .coCaptainDoneButton)
        #expect(OnboardingCoordinator.Step.longPressFAB.tooltipAnchor == .floatingCommandButton)
        #expect(OnboardingCoordinator.Step.panCanvas.tooltipAnchor == .canvasGestureArea)
        #expect(OnboardingCoordinator.Step.pinchZoom.tooltipAnchor == .canvasHUDZoom)
        #expect(OnboardingCoordinator.Step.fitAllNodes.tooltipAnchor == .canvasGestureArea)
        #expect(OnboardingCoordinator.Step.searchFlyToNode.tooltipAnchor == .floatingCommandButton)
        #expect(OnboardingCoordinator.Step.returnToRoot.tooltipAnchor == .floatingCommandButton)
        #expect(
            OnboardingCoordinator.Step.returnToRoot.resolvedTooltipAnchor(isCommandPalettePresented: true)
                == .commandPaletteGoBack
        )
        #expect(
            OnboardingCoordinator.Step.searchFlyToNode.resolvedTooltipAnchor(isCommandPalettePresented: true)
                == .omniboxSearchField
        )
    }

    @MainActor
    @Test func hidingPopoverDoesNotAdvanceCurrentStep() {
        let onboarding = OnboardingCoordinator()
        onboarding.currentStep = .chatCoCaptain
        onboarding.activeLessonID = .coCaptainChat
        onboarding.showPopover = true

        onboarding.hidePopoverForCurrentStep()

        #expect(onboarding.currentStep == .chatCoCaptain)
        #expect(!onboarding.showPopover)
    }

    @MainActor
    @Test func successfulHandoffCompletionAdvancesToDismissStep() {
        let onboarding = OnboardingCoordinator()
        onboarding.currentStep = .chatCoCaptain
        onboarding.activeLessonID = .coCaptainChat

        let completion = CoCaptainTurnCompletion(
            turnID: UUID(),
            purpose: .onboardingBuildHandoff,
            succeeded: true
        )

        #expect(completion.shouldAdvanceToCanvasDismissal)

        if completion.shouldAdvanceToCanvasDismissal {
            onboarding.completeCurrentStep()
        }

        #expect(onboarding.currentStep == .dismissCoCaptain)
    }

    @MainActor
    @Test func failedHandoffCompletionDoesNotAdvanceFromChatStep() {
        let onboarding = OnboardingCoordinator()
        onboarding.currentStep = .chatCoCaptain
        onboarding.activeLessonID = .coCaptainChat

        let completion = CoCaptainTurnCompletion(
            turnID: UUID(),
            purpose: .onboardingBuildHandoff,
            succeeded: false
        )

        #expect(!completion.shouldAdvanceToCanvasDismissal)

        if completion.shouldAdvanceToCanvasDismissal {
            onboarding.completeCurrentStep()
        }

        #expect(onboarding.currentStep == .chatCoCaptain)
    }

    @MainActor
    @Test func standaloneLessonCompletionDoesNotAutoStartNextLesson() {
        let onboarding = OnboardingCoordinator()
        onboarding.startLesson(.canvasBasics, advancesThroughLessons: false)
        onboarding.currentStep = .submitCoCaptainPrompt

        onboarding.completeCurrentStep()

        #expect(onboarding.isLessonCompleted(.canvasBasics))
        #expect(onboarding.currentStep == nil)
        #expect(onboarding.activeLessonID == nil)
        #expect(!onboarding.isLessonCompleted(.coCaptainChat))
    }

    @MainActor
    @Test func firstRunLessonCompletionAdvancesToNextLesson() {
        let onboarding = OnboardingCoordinator()
        onboarding.startLesson(.canvasBasics, advancesThroughLessons: true)
        onboarding.currentStep = .submitCoCaptainPrompt
        onboarding.showPopover = true

        onboarding.completeCurrentStep()

        #expect(onboarding.isLessonCompleted(.canvasBasics))
        #expect(onboarding.activeLessonID == .coCaptainChat)
        #expect(onboarding.currentStep == .chatCoCaptain)
    }

    @MainActor
    @Test func lessonWillStartCallbackFiresBeforeFirstStep() {
        let onboarding = OnboardingCoordinator()
        var startedLesson: OnboardingLessonID?
        onboarding.onLessonWillStart = { startedLesson = $0 }

        onboarding.startLesson(.canvasNavigation, advancesThroughLessons: false)

        #expect(startedLesson == .canvasNavigation)
        #expect(onboarding.currentStep == .returnToRoot)
    }
}
