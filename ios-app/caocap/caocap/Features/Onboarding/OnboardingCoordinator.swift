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
        /// User must drag the canvas background to pan around the workspace.
        case panCanvas
        /// User must pinch the canvas to zoom in or out.
        case pinchZoom
        /// User must double-tap empty canvas space to fit all nodes in view.
        case fitAllNodes
        /// User must search for and fly to the Tutorial node via the command palette.
        case searchFlyToNode
        /// User must tap the Tutorial portal node to open its linked subcanvas.
        case openPortal
        /// User must return to the root canvas from a subcanvas via Go Back.
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

        var isCanvasNavigationGestureStep: Bool {
            switch self {
            case .panCanvas, .pinchZoom, .fitAllNodes:
                return true
            default:
                return false
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

    /// Baseline viewport offset captured when a pan/pinch navigation step begins.
    public var gestureStepBaselineOffset: CGSize = .zero

    /// Baseline viewport scale captured when a pinch navigation step begins.
    public var gestureStepBaselineScale: CGFloat = 1.0

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

    // MARK: - Persistence

    /// Versioned key so a future onboarding redesign can show the new flow to existing users.
    private static let completedKey = "onboarding_completed_v6"
    private static let legacyCompletedKey = "onboarding_completed_v5"
    private static let lessonCompletedKeyPrefix = "onboarding_lesson_completed_"
    private static let legacyCanvasNavigationLessonKey = "onboarding_lesson_completed_powerShortcuts"

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

    public init() {
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

        self.advancesThroughLessons = advancesThroughLessons
        activeLessonID = lessonID
        currentStep = firstStep
        schedulePopover(after: initialDelay)
    }

    func captureGestureBaseline(offset: CGSize, scale: CGFloat) {
        gestureStepBaselineOffset = offset
        gestureStepBaselineScale = scale
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
        UserDefaults.standard.removeObject(forKey: Self.legacyCompletedKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyCanvasNavigationLessonKey)
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

    private func migratePersistenceIfNeeded() {
        let defaults = UserDefaults.standard

        if defaults.bool(forKey: Self.legacyCompletedKey), !defaults.bool(forKey: Self.completedKey) {
            defaults.set(true, forKey: Self.completedKey)
        }

        if defaults.bool(forKey: Self.legacyCanvasNavigationLessonKey),
           !defaults.bool(forKey: Self.lessonCompletionKey(for: .canvasNavigation)) {
            defaults.set(true, forKey: Self.lessonCompletionKey(for: .canvasNavigation))
            defaults.removeObject(forKey: Self.legacyCanvasNavigationLessonKey)
        }
    }
}
