import Testing
@testable import caocap

struct PerformanceSignpostsTests {
    @Test func beginAndEndLaunchIsIdempotent() {
        PerformanceSignposts.beginLaunch()
        PerformanceSignposts.beginLaunch()
        PerformanceSignposts.endLaunch()
        PerformanceSignposts.endLaunch()
    }

    @Test func measureRunsWorkAndReturnsValue() {
        let value = PerformanceSignposts.measure(PerformanceSignposts.Name.save) {
            42
        }
        #expect(value == 42)
    }
}
