import SwiftUI
import Observation

/// Drives the first-run onboarding flow. Each step is unlocked by the user
/// performing the actual gesture, so learning happens by doing.
@MainActor
@Observable
public class OnboardingCoordinator {
    // MARK: - Step Definition

    public enum Step: String, CaseIterable {
        /// User must tap the Hello World mini-app on the root canvas to open fullscreen.
        case openPortal

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

        /// Blocks Omnibox → CoCaptain prompt submission while the canvas lesson is active.
        var blocksCoCaptainPrompt: Bool {
            switch self {
            case .openPortal:
                return true
            }
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

    /// Called before a lesson starts so the session can prepare workspace context.
    @ObservationIgnored
    public var onLessonWillStart: ((OnboardingLessonID) -> Void)?

    /// Called when the user finishes the full interactive tutorial sequence.
    @ObservationIgnored
    public var onTutorialCompleted: (() -> Void)?

    @ObservationIgnored
    private let analytics: any AnalyticsTracking

    // MARK: - Persistence

    /// Versioned key so a future onboarding redesign can show the new flow to existing users.
    private static let completedKey = "onboarding_completed_v9"
    private static let legacyCompletedKey = "onboarding_completed_v8"
    private static let legacyV5CompletedKey = "onboarding_completed_v5"
    private static let lessonCompletedKeyPrefix = "onboarding_lesson_completed_"
    private static let legacyCanvasNavigationLessonKey = "onboarding_lesson_completed_powerShortcuts"
    private static let legacyCanvasNavigationLessonIDKey = "onboarding_lesson_completed_canvasNavigation"

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

    public convenience init() {
        self.init(analytics: AnalyticsService.shared)
    }

    init(analytics: any AnalyticsTracking) {
        self.analytics = analytics
        migratePersistenceIfNeeded()
    }

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

        onLessonWillStart?(lessonID)
        logLessonStarted(lessonID)

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
        logStepCompleted(step, lessonID: lessonID)

        if let next = OnboardingLessonsManifest.nextStep(after: step, in: lesson) {
            currentStep = next
            schedulePopover(after: interStepDelay)
            return
        }

        markLessonComplete(lessonID)
        logLessonCompleted(lessonID)

        if advancesThroughLessons,
           let nextLessonID = OnboardingLessonsManifest.nextMainLesson(after: lessonID),
           !isLessonCompleted(nextLessonID) {
            startLesson(nextLessonID, advancesThroughLessons: true)
            return
        }

        if OnboardingLessonsManifest.areAllMainLessonsCompleted(completedLessonIDs: completedLessonIDs) {
            markComplete()
        } else {
            activeLessonID = nil
            currentStep = nil
        }
    }

    /// Hide the active popover without advancing the onboarding step.
    public func hidePopoverForCurrentStep() {
        popoverTask?.cancel()
        showPopover = false
    }

    /// Skip the active lesson and continue to the next incomplete lesson when appropriate.
    public func skip() {
        popoverTask?.cancel()
        showPopover = false

        guard let lessonID = activeLessonID else {
            markComplete()
            return
        }

        logLessonSkipped(lessonID)
        markLessonComplete(lessonID)

        if advancesThroughLessons,
           let nextLessonID = OnboardingLessonsManifest.nextMainLesson(after: lessonID),
           !isLessonCompleted(nextLessonID) {
            startLesson(nextLessonID, advancesThroughLessons: true)
            return
        }

        if OnboardingLessonsManifest.areAllMainLessonsCompleted(completedLessonIDs: completedLessonIDs) {
            markComplete()
        } else {
            activeLessonID = nil
            currentStep = nil
            advancesThroughLessons = false
        }
    }

    /// Reset onboarding (for Settings).
    public func reset() {
        UserDefaults.standard.removeObject(forKey: Self.completedKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyCompletedKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyV5CompletedKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyCanvasNavigationLessonKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyCanvasNavigationLessonIDKey)
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
        for lessonID in OnboardingLessonsManifest.mainLessonIDs {
            markLessonComplete(lessonID)
        }
        activeLessonID = nil
        currentStep = nil
        isCompleted = true
        advancesThroughLessons = false
        onTutorialCompleted?()
    }

    private func logLessonStarted(_ lessonID: OnboardingLessonID) {
        analytics.logEvent(
            OnboardingAnalytics.lessonStarted,
            parameters: [OnboardingAnalytics.lessonID: lessonID.rawValue]
        )
    }

    private func logLessonCompleted(_ lessonID: OnboardingLessonID) {
        analytics.logEvent(
            OnboardingAnalytics.lessonCompleted,
            parameters: [OnboardingAnalytics.lessonID: lessonID.rawValue]
        )
    }

    private func logLessonSkipped(_ lessonID: OnboardingLessonID) {
        analytics.logEvent(
            OnboardingAnalytics.lessonSkipped,
            parameters: [OnboardingAnalytics.lessonID: lessonID.rawValue]
        )
    }

    private func logStepCompleted(_ step: Step, lessonID: OnboardingLessonID) {
        analytics.logEvent(
            OnboardingAnalytics.stepCompleted,
            parameters: [
                OnboardingAnalytics.lessonID: lessonID.rawValue,
                OnboardingAnalytics.stepID: step.rawValue
            ]
        )
    }

    private static func lessonCompletionKey(for lessonID: OnboardingLessonID) -> String {
        lessonCompletedKeyPrefix + lessonID.rawValue
    }

    private func migratePersistenceIfNeeded() {
        let defaults = UserDefaults.standard

        if defaults.bool(forKey: Self.legacyV5CompletedKey), !defaults.bool(forKey: Self.legacyCompletedKey) {
            defaults.set(true, forKey: Self.legacyCompletedKey)
        }

        if defaults.bool(forKey: Self.legacyCompletedKey), !defaults.bool(forKey: Self.completedKey) {
            for lessonID in OnboardingLessonID.allCases {
                defaults.removeObject(forKey: Self.lessonCompletionKey(for: lessonID))
            }
            defaults.set(true, forKey: Self.completedKey)
        }

        if defaults.bool(forKey: Self.legacyCanvasNavigationLessonKey) {
            defaults.removeObject(forKey: Self.legacyCanvasNavigationLessonKey)
        }

        if defaults.bool(forKey: Self.legacyCanvasNavigationLessonIDKey) {
            defaults.removeObject(forKey: Self.legacyCanvasNavigationLessonIDKey)
        }
    }
}
