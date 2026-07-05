import Foundation
import Testing
@testable import caocap

struct OnboardingManifestTests {
    @Test func manifestDefinesEveryCoordinatorStepOnce() {
        let manifestSteps = OnboardingManifest.steps.map(\.step)

        #expect(manifestSteps == OnboardingCoordinator.Step.allCases)
        #expect(Set(manifestSteps).count == OnboardingCoordinator.Step.allCases.count)
    }

    @Test func manifestDrivesStepLabelsAndProgression() {
        #expect(OnboardingManifest.firstStep == .openTutorial)
        #expect(OnboardingManifest.nextStep(after: .openTutorial) == .tapFAB)
        #expect(OnboardingManifest.nextStep(after: .tapFAB) == .typeCoCaptainPrompt)
        #expect(OnboardingManifest.nextStep(after: .typeCoCaptainPrompt) == .submitCoCaptainPrompt)
        #expect(OnboardingManifest.nextStep(after: .submitCoCaptainPrompt) == .chatCoCaptain)
        #expect(OnboardingManifest.nextStep(after: .chatCoCaptain) == .dismissCoCaptain)
        #expect(OnboardingManifest.nextStep(after: .dismissCoCaptain) == .longPressFAB)
        #expect(OnboardingManifest.nextStep(after: .longPressFAB) == nil)

        #expect(OnboardingManifest.steps.count == 7)
        #expect(
            OnboardingManifest.stepLabel(for: .openTutorial, language: "English") == "1 of 7"
        )
        #expect(
            OnboardingManifest.stepLabel(for: .tapFAB, language: "English") == "2 of 7"
        )
        #expect(
            OnboardingManifest.stepLabel(for: .longPressFAB, language: "English") == "7 of 7"
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
        #expect(OnboardingCoordinator.Step.tapFAB.tooltipAnchor == .floatingCommandButton)
        #expect(OnboardingCoordinator.Step.typeCoCaptainPrompt.tooltipAnchor == .omniboxSearchField)
        #expect(OnboardingCoordinator.Step.submitCoCaptainPrompt.tooltipAnchor == .omniboxPromptRow)
        #expect(OnboardingCoordinator.Step.chatCoCaptain.tooltipAnchor == .coCaptainInput)
        #expect(OnboardingCoordinator.Step.dismissCoCaptain.tooltipAnchor == .coCaptainDoneButton)
        #expect(OnboardingCoordinator.Step.longPressFAB.tooltipAnchor == .floatingCommandButton)
    }

    @MainActor
    @Test func hidingPopoverDoesNotAdvanceCurrentStep() {
        let onboarding = OnboardingCoordinator()
        onboarding.currentStep = .chatCoCaptain
        onboarding.showPopover = true

        onboarding.hidePopoverForCurrentStep()

        #expect(onboarding.currentStep == .chatCoCaptain)
        #expect(!onboarding.showPopover)
    }

    @MainActor
    @Test func successfulHandoffCompletionAdvancesToDismissStep() {
        let onboarding = OnboardingCoordinator()
        onboarding.currentStep = .chatCoCaptain

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
}
