import Testing
@testable import caocap

@Suite("Copilot interaction modes")
@MainActor
struct CopilotInteractionModeTests {
    @Test func modeIconsAreStable() {
        #expect(CopilotInteractionMode.chat.systemImageName == "bubble.left.and.bubble.right.fill")
        #expect(CopilotInteractionMode.voice.systemImageName == "mic.fill")
        #expect(CopilotInteractionMode.video.systemImageName == "rectangle.dashed.badge.record")
    }

    @Test func dispatcherIncludesUndoRedoAndCallActions() {
        let dispatcher = AppActionDispatcher()
        let ids = Set(dispatcher.availableActions.map(\.id))
        #expect(ids.contains(.undo))
        #expect(ids.contains(.redo))
        #expect(ids.contains(.summonCopilotVoice))
        #expect(ids.contains(.summonCopilotVideo))
        #expect(ids.contains(.summonCoCaptain))
    }

    @Test func intentResolverMatchesUndoRedo() {
        let dispatcher = AppActionDispatcher()
        let resolver = CommandIntentResolver()
        #expect(resolver.resolve("undo", availableActions: dispatcher.availableActions) == .undo)
        #expect(resolver.resolve("redo", availableActions: dispatcher.availableActions) == .redo)
        #expect(resolver.resolve("voice call", availableActions: dispatcher.availableActions) == .summonCopilotVoice)
        #expect(resolver.resolve("screen share", availableActions: dispatcher.availableActions) == .summonCopilotVideo)
    }
}
