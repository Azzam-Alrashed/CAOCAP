import SwiftUI
import Observation

/// Drives the first-run onboarding flow. Each step is unlocked by the user
/// performing the actual gesture, so learning happens by doing.
@MainActor
@Observable
public class OnboardingCoordinator {

    // MARK: - Step Definition

    public enum Step: Int, CaseIterable, Comparable {
        /// User must open the Tutorial portal on the root canvas.
        case openTutorial = 0
        /// User must tap the floating command button (FAB) to open the command palette.
        case tapFAB
        /// User must type any text in the omnibox search field.
        case typeCoCaptainPrompt
        /// User must send the typed text to CoCaptain via the prompt row or Return key.
        case submitCoCaptainPrompt
        /// User must type a message inside the CoCaptain chat panel.
        case chatCoCaptain
        /// User must dismiss the CoCaptain panel by tapping Done or dragging it down.
        case dismissCoCaptain
        /// User must long-press the FAB to reveal the quick-action radial menu.
        case longPressFAB
        /// User must return to the root canvas from the Tutorial subcanvas.
        case returnToRoot

        public static func < (lhs: Step, rhs: Step) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var titleKey: String {
            OnboardingManifest.content(for: self).titleKey
        }

        var messageKey: String {
            OnboardingManifest.content(for: self).messageKey
        }

        var icon: String {
            OnboardingManifest.content(for: self).icon
        }

        func stepLabel(in lessonID: OnboardingLessonID?) -> String {
            guard let lessonID else { return "" }
            return OnboardingLessonsManifest.stepLabel(for: self, in: lessonID)
        }
    }

    // MARK: - State

    /// The currently active onboarding step. `nil` means onboarding is complete or skipped.
    public var currentStep: Step? = nil

    /// The lesson currently being taught.
    public var activeLessonID: OnboardingLessonID? = nil

    /// Whether to show the popover for the current step.
    public var showPopover: Bool = false

    /// Delay before showing the first popover (lets launch screen dismiss first).
    private let initialDelay: TimeInterval = 1.5

    /// Brief pause between steps so the UI settles before the next popover appears.
    private let interStepDelay: TimeInterval = 0.8

    @ObservationIgnored
    private var popoverTask: Task<Void, Never>?

    @ObservationIgnored
    private var advancesThroughLessons = false

    // MARK: - Persistence

    /// Versioned key so a future onboarding redesign can show the new flow to existing users.
    private static let completedKey = "onboarding_completed_v5"
    private static let lessonCompletedKeyPrefix = "onboarding_lesson_completed_"

    public var isCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: Self.completedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.completedKey) }
    }

    public var completedLessonIDs: Set<OnboardingLessonID> {
        Set(
            OnboardingLessonID.allCases.filter { lessonID in
                UserDefaults.standard.bool(forKey: Self.lessonCompletionKey(for: lessonID))
            }
        )
    }

    public func isLessonCompleted(_ lessonID: OnboardingLessonID) -> Bool {
        completedLessonIDs.contains(lessonID)
    }

    // MARK: - Lifecycle

    public init() {}

    /// Call once from `AppSessionCoordinator.bootstrap` after the launch screen fades.
    public func startIfNeeded() {
        guard !isCompleted else { return }

        guard let lessonID = OnboardingLessonsManifest.firstIncompleteLesson(
            completedLessonIDs: completedLessonIDs
        ) else {
            markComplete()
            return
        }

        startLesson(lessonID, advancesThroughLessons: true)
    }

    /// Starts a specific lesson. Used for first-run progression and Help relaunches.
    public func startLesson(_ lessonID: OnboardingLessonID, advancesThroughLessons: Bool) {
        let lesson = OnboardingLessonsManifest.lesson(for: lessonID)
        guard let firstStep = lesson.steps.first else {
            markComplete()
            return
        }

        self.advancesThroughLessons = advancesThroughLessons
        activeLessonID = lessonID
        currentStep = firstStep
        schedulePopover(after: initialDelay)
    }

    private func schedulePopover(after delay: TimeInterval) {
        popoverTask?.cancel()
        popoverTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            showPopover = true
        }
    }

    // MARK: - Step Completion

    /// Call when the user performs the action for the current step.
    public func completeCurrentStep() {
        guard let step = currentStep, let lessonID = activeLessonID else { return }
        let lesson = OnboardingLessonsManifest.lesson(for: lessonID)
        showPopover = false

        if let next = OnboardingLessonsManifest.nextStep(after: step, in: lesson) {
            currentStep = next
            schedulePopover(after: interStepDelay)
            return
        }

        markLessonComplete(lessonID)

        if advancesThroughLessons,
           let nextLessonID = OnboardingLessonsManifest.nextLesson(after: lessonID),
           !isLessonCompleted(nextLessonID) {
            startLesson(nextLessonID, advancesThroughLessons: true)
            return
        }

        if completedLessonIDs.count == OnboardingLessonID.allCases.count {
            markComplete()
        } else {
            activeLessonID = nil
            currentStep = nil
        }
    }

    /// Move directly to a specific step (e.g. when resetting back to Step 1).
    public func moveToStep(_ step: Step) {
        showPopover = false
        activeLessonID = OnboardingLessonsManifest.lesson(containing: step)?.id
        currentStep = step
        schedulePopover(after: interStepDelay)
    }

    /// Hide the active popover without advancing the onboarding step.
    public func hidePopoverForCurrentStep() {
        popoverTask?.cancel()
        showPopover = false
    }

    /// Skip the entire onboarding.
    public func skip() {
        popoverTask?.cancel()
        showPopover = false
        markComplete()
    }

    /// Reset onboarding (for Settings).
    public func reset() {
        UserDefaults.standard.removeObject(forKey: Self.completedKey)
        for lessonID in OnboardingLessonID.allCases {
            UserDefaults.standard.removeObject(forKey: Self.lessonCompletionKey(for: lessonID))
        }
        activeLessonID = nil
        currentStep = nil
        showPopover = false
        advancesThroughLessons = false
        popoverTask?.cancel()
    }

    private func markLessonComplete(_ lessonID: OnboardingLessonID) {
        UserDefaults.standard.set(true, forKey: Self.lessonCompletionKey(for: lessonID))
    }

    private func markComplete() {
        popoverTask?.cancel()
        for lessonID in OnboardingLessonID.allCases {
            markLessonComplete(lessonID)
        }
        activeLessonID = nil
        currentStep = nil
        isCompleted = true
        advancesThroughLessons = false
    }

    private static func lessonCompletionKey(for lessonID: OnboardingLessonID) -> String {
        lessonCompletedKeyPrefix + lessonID.rawValue
    }
}
