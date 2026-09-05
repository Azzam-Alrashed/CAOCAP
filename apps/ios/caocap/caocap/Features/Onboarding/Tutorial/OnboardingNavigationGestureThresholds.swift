import CoreGraphics
import Foundation

/// Threshold math for canvas navigation onboarding gestures.
enum OnboardingNavigationGestureThresholds {
    static let minimumPanDistance: CGFloat = 40
    static let minimumScaleDelta: CGFloat = 0.08

    static func panDistance(from baseline: CGSize, to current: CGSize) -> CGFloat {
        hypot(current.width - baseline.width, current.height - baseline.height)
    }

    static func scaleDelta(from baseline: CGFloat, to current: CGFloat) -> CGFloat {
        abs(current - baseline)
    }

    static func didMeetPanThreshold(from baseline: CGSize, to current: CGSize) -> Bool {
        panDistance(from: baseline, to: current) >= minimumPanDistance
    }

    static func didMeetPinchThreshold(from baseline: CGFloat, to current: CGFloat) -> Bool {
        scaleDelta(from: baseline, to: current) >= minimumScaleDelta
    }
}
