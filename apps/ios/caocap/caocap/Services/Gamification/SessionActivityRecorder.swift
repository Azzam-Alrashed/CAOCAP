import Foundation

/// Forwards successful save events to activity history and gamification XP.
@MainActor
public final class SessionActivityRecorder: ActivityRecording {
    private let activityStore: ActivityStore
    private let gamificationStore: GamificationStore

    public init(
        activityStore: ActivityStore = .shared,
        gamificationStore: GamificationStore = .shared
    ) {
        self.activityStore = activityStore
        self.gamificationStore = gamificationStore
    }

    public func recordSuccessfulSave(at date: Date) {
        activityStore.recordSuccessfulSave(at: date)
        gamificationStore.recordSuccessfulSave(at: date)
    }
}
