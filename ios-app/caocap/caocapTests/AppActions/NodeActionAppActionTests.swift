import Foundation
import Testing
@testable import caocap

struct NodeActionAppActionTests {
    @Test func everyNodeActionResolvesToAppActionID() {
        let mappings: [(NodeAction, AppActionID)] = [
            (.navigateRoot, .goRoot),
            (.openSettings, .openSettings),
            (.openProfile, .openProfile),
            (.summonCoCaptain, .summonCoCaptain),
            (.proSubscription, .proSubscription),
            (.openActivity, .openActivity),
            (.openDaily, .openDaily),
            (.openWhatsApp, .openWhatsApp),
            (.openHelp, .help)
        ]

        for (nodeAction, expectedID) in mappings {
            #expect(nodeAction.appActionID == expectedID)
        }
    }

    @Test func pinableAppActionsRoundTripToNodeAction() {
        let pinableIDs: [AppActionID] = [
            .goRoot,
            .openSettings,
            .openProfile,
            .summonCoCaptain,
            .proSubscription,
            .openActivity,
            .openDaily,
            .openWhatsApp,
            .help
        ]

        for actionID in pinableIDs {
            let nodeAction = try #require(actionID.pinableNodeAction)
            #expect(nodeAction.appActionID == actionID)
        }
    }

    @MainActor
    @Test func dispatcherExposesNewRootShortcutActions() {
        let dispatcher = AppActionDispatcher()
        let newIDs: [AppActionID] = [.openActivity, .openDaily, .openWhatsApp, .help]

        for id in newIDs {
            let definition = try #require(dispatcher.definition(for: id))
            #expect(!definition.isMutating)
            #expect(!definition.allowsAutonomousExecution)
            #expect(definition.canPinToCanvas)
            #expect(id.pinableNodeAction != nil)
        }
    }
}
