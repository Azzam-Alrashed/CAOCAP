import Foundation
import Testing
@testable import caocap

struct SubscriptionManagerTests {
    @MainActor
    @Test func refreshEntitlementsSetsResolvedAfterUpdateCompletes() async {
        let manager = SubscriptionManager {
            try? await Task.sleep(for: .milliseconds(5))
        }

        #expect(manager.entitlementsResolved == false)

        await manager.refreshEntitlements()

        #expect(manager.entitlementsResolved)
        #expect(manager.testing_updateInvocationCount == 1)
    }

    @MainActor
    @Test func concurrentRefreshEntitlementsCallsCoalesce() async {
        let manager = SubscriptionManager {
            try? await Task.sleep(for: .milliseconds(50))
        }

        async let first = manager.refreshEntitlements()
        async let second = manager.refreshEntitlements()
        async let third = manager.refreshEntitlements()
        _ = await (first, second, third)

        #expect(manager.entitlementsResolved)
        #expect(manager.testing_updateInvocationCount == 1)
    }
}
