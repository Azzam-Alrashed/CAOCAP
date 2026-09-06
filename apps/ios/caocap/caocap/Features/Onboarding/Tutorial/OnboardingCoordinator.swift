import SwiftUI
import Observation

/// Drives the first-run onboarding flow. Each step is unlocked by the user
/// performing the actual gesture, so learning happens by doing.
@MainActor
@Observable
public class OnboardingCoordinator {
    // MARK: - Step Definition

    public enum Step: Int, CaseIterable {
        /// User must open the Tutorial portal on the root canvas.
        case openTutorial = 0
        /// User must tap the floating command button (FAB) to open the command palette.
        case tapFAB
        /// User must type any text in the omnibox search field.
        case typeCoCaptainPrompt
        /// User must send the typed text to CoCaptain via the prompt row or Return key.
        case submitCoCaptainPrompt
        /// User must ask CoCaptain for a small guided change to the Hello World app.
        case chatCoCaptain
        /// User must dismiss the CoCaptain panel by tapping Done or dragging it down.
        case dismissCoCaptain
        /// User must long-press the FAB to reveal the quick-action radial menu.
        case longPressFAB
        /// User must open the omnibox from a subcanvas to begin navigation practice.
        case returnToRoot
        /// User must type "go back" in the omnibox search field.
        case typeGoBackInOmnibox
        /// User must tap the Go Back action row or press return to navigate up.
        case tapGoBackAction
        /// User must search for and fly to Pac-Man or XO via the command palette.
        case searchFlyToNode
        /// User must tap a demo-game portal node to open its linked subcanvas.
        case openPortal
        /// User must ask CoCaptain for a small guided change on a demo game canvas.
        case chatCoCaptainGameEdit
        /// User must review the pending CoCaptain change card.
        case reviewCoCaptainChange
        /// User must tap Apply on the CoCaptain review card.
        case applyCoCaptainChange
        /// User must open Help from the command palette.
        case openHelpCenter
        /// User must browse Help guides to discover additional lessons.
        case browseHelpGuides
        /// User must tap the seeded Hello World Mini-App on the Tutorial canvas.
        case tapMiniAppNode
        /// User must interact with the live Mini-App preview.
        case interactMiniAppPreview
        /// User must open the Code tool from the preview omnibox.
        case openMiniAppCodeTool
        /// User must save a code edit from the code editor.
        case saveMiniAppCodeEdit
        /// User must return to the canvas from the Mini-App preview.
        case returnFromMiniAppPreview
        /// User must drag the canvas background to pan around the workspace.
        case panCanvas
        /// User must pinch the canvas to zoom in or out.
        case pinchZoom
        /// User must double-tap empty canvas space to fit all nodes in view.
        case fitAllNodes
        /// User must drag the practice node to a new position.
        case dragCanvasNode
        /// User must run Organize Nodes from the omnibox.
        case runOrganizeNodes
        /// User must undo the last canvas edit.
        case undoCanvasEdit
        /// User must redo the last undone edit.
        case redoCanvasEdit

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

        var blocksCoCaptainPrompt: Bool {
            switch self {
            case .returnToRoot, .typeGoBackInOmnibox, .tapGoBackAction, .panCanvas, .pinchZoom, .fitAllNodes,
                 .searchFlyToNode, .openPortal, .tapMiniAppNode, .interactMiniAppPreview, .openMiniAppCodeTool,
                 .saveMiniAppCodeEdit, .returnFromMiniAppPreview, .openHelpCenter, .browseHelpGuides,
                 .dragCanvasNode, .runOrganizeNodes,
                 .undoCanvasEdit, .redoCanvasEdit, .reviewCoCaptainChange, .applyCoCaptainChange:
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
    /// The walkthrough engine stays. There is no lesson list, so first-run does not start one.
    public func startIfNeeded() {
        // Intentionally empty. Do not startLesson and do not markComplete.
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

    func captureGestureBaseline(offset: CGSize, scale: CGFloat) {
        gestureStepBaselineOffset = offset
        gestureStepBaselineScale = scale
    }

    private func scheduleReviewStepHandoff() {
        popoverTask?.cancel()
        popoverTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(interStepDelay))
            guard !Task.isCancelled else { return }
            showPopover = true
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            guard currentStep == .reviewCoCaptainChange else { return }
            let lessonID = activeLessonID?.rawValue ?? OnboardingLessonID.omniboxNavigation.rawValue
            analytics.logEvent(
                OnboardingAnalytics.cocaptainReviewShown,
                parameters: [OnboardingAnalytics.lessonID: lessonID]
            )
            advancePastReviewStep()
        }
    }

    /// Moves from the review step to apply when apply is not the next step in the active lesson.
    private func advancePastReviewStep() {
        guard let lessonID = activeLessonID else { return }
        let lesson = OnboardingLessonsManifest.lesson(for: lessonID)
        showPopover = false
        logStepCompleted(.reviewCoCaptainChange, lessonID: lessonID)

        if let next = OnboardingLessonsManifest.nextStep(after: .reviewCoCaptainChange, in: lesson) {
            currentStep = next
        } else {
            currentStep = .applyCoCaptainChange
        }
        schedulePopover(after: interStepDelay)
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
            if next == .reviewCoCaptainChange {
                scheduleReviewStepHandoff()
            } else {
                schedulePopover(after: interStepDelay)
            }
            return
        }

        if step == .reviewCoCaptainChange {
            advancePastReviewStep()
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
                OnboardingAnalytics.stepID: String(step.rawValue)
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

        if defaults.bool(forKey: Self.legacyCanvasNavigationLessonKey),
           !defaults.bool(forKey: Self.lessonCompletionKey(for: .omniboxNavigation)) {
            defaults.set(true, forKey: Self.lessonCompletionKey(for: .omniboxNavigation))
            defaults.removeObject(forKey: Self.legacyCanvasNavigationLessonKey)
        }

        if defaults.bool(forKey: Self.legacyCanvasNavigationLessonIDKey),
           !defaults.bool(forKey: Self.lessonCompletionKey(for: .omniboxNavigation)) {
            defaults.set(true, forKey: Self.lessonCompletionKey(for: .omniboxNavigation))
            defaults.removeObject(forKey: Self.legacyCanvasNavigationLessonIDKey)
        }
    }
}
