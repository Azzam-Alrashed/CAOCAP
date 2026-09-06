import Foundation

/// Forwards successful save events to activity history.
@MainActor
public final class SessionActivityRecorder: ActivityRecording {
    private let activityStore: ActivityStore

    public init(activityStore: ActivityStore = .shared) {
        self.activityStore = activityStore
    }

    public func recordSuccessfulSave(at date: Date) {
        activityStore.recordSuccessfulSave(at: date)
    }
}
