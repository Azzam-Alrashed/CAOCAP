import CoreGraphics
import Foundation
import Testing
@testable import caocap

struct OnboardingNavigationGestureThresholdsTests {
    @Test func panThresholdRequiresMeaningfulMovement() {
        let baseline = CGSize(width: 10, height: 20)

        #expect(
            !OnboardingNavigationGestureThresholds.didMeetPanThreshold(
                from: baseline,
                to: CGSize(width: 20, height: 25)
            )
        )
        #expect(
            OnboardingNavigationGestureThresholds.didMeetPanThreshold(
                from: baseline,
                to: CGSize(width: 60, height: 20)
            )
        )
    }

    @Test func pinchThresholdRequiresMeaningfulScaleChange() {
        #expect(
            !OnboardingNavigationGestureThresholds.didMeetPinchThreshold(
                from: 1.0,
                to: 1.05
            )
        )
        #expect(
            OnboardingNavigationGestureThresholds.didMeetPinchThreshold(
                from: 1.0,
                to: 1.12
            )
        )
    }
}
