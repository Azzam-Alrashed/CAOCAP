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

    @Test func openPortalDeclaresHelloWorldTooltipAnchor() {
        #expect(OnboardingCoordinator.Step.openPortal.tooltipAnchor == .demoGameNode)
        #expect(
            OnboardingCoordinator.Step.openPortal.resolvedTooltipAnchor(isCommandPalettePresented: true)
                == .demoGameNode
        )
        #expect(OnboardingCoordinator.Step.openPortal.tooltipArrowPlacement == .bottom)
        #expect(OnboardingCoordinator.Step.openPortal.blocksCoCaptainPrompt)
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

    @MainActor
    private func makeResetOnboardingCoordinator() -> OnboardingCoordinator {
        let onboarding = OnboardingCoordinator(analytics: NoOpAnalyticsService())
        onboarding.reset()
        return onboarding
    }
}
