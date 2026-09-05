import Foundation
import OSLog

/// Shared OSSignpost intervals for the performance audit.
///
/// Filter Instruments / Console by subsystem `com.caocap.app` and category
/// `Performance`. Interval names match the audit scenario matrix (launch,
/// projectLoad, livePreviewCompile, canvasGesture, webView, save, agentStream,
/// screenCaptureEncode).
enum PerformanceSignposts {
    static let subsystem = "com.caocap.app"
    static let category = "Performance"

    static let logger = Logger(subsystem: subsystem, category: category)
    static let signposter = OSSignposter(logger: logger)

    enum Name {
        static let launch: StaticString = "launch"
        static let projectLoad: StaticString = "projectLoad"
        static let livePreviewCompile: StaticString = "livePreviewCompile"
        static let canvasGesture: StaticString = "canvasGesture"
        static let webViewMake: StaticString = "webViewMake"
        static let webViewLoad: StaticString = "webViewLoad"
        static let save: StaticString = "save"
        static let agentStream: StaticString = "agentStream"
        static let screenCaptureEncode: StaticString = "screenCaptureEncode"
    }

    /// Cold-launch interval spanning `didFinishLaunching` → splash dismiss.
    private static var launchInterval: OSSignpostIntervalState?

    static func beginLaunch() {
        guard launchInterval == nil else { return }
        launchInterval = begin(Name.launch)
    }

    static func endLaunch() {
        guard let state = launchInterval else { return }
        end(Name.launch, state)
        launchInterval = nil
    }

    /// Begins a named interval. Call `end` on the returned state when the work finishes.
    static func begin(_ name: StaticString) -> OSSignpostIntervalState {
        signposter.beginInterval(name)
    }

    static func end(_ name: StaticString, _ state: OSSignpostIntervalState) {
        signposter.endInterval(name, state)
    }

    /// Measures a synchronous block as a named interval.
    static func measure<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        let state = begin(name)
        defer { end(name, state) }
        return try work()
    }

    /// Emits a one-shot event (no duration) for sparse sampling.
    static func event(_ name: StaticString) {
        signposter.emitEvent(name)
    }
}
