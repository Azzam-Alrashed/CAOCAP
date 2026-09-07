import Foundation
import Testing
@testable import caocap

@MainActor
struct AgentLibraryTests {
    @Test func defaultsRemovalAndUndoSurviveReload() {
        let suite = "AgentLibraryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let library = AgentLibrary(defaults: defaults)
        #expect(library.agents.map(\.name) == ["CoCaptain", "CoStar"])
        let captain = library.agents[0]
        let star = library.agents[1]
        #expect(captain.workspaceFileName != star.workspaceFileName)
        library.remove(captain)
        #expect(AgentLibrary(defaults: defaults).agents == [star])
        library.remove(star)
        #expect(AgentLibrary(defaults: defaults).agents.isEmpty)
        library.restore(captain)
        library.restore(captain)
        #expect(AgentLibrary(defaults: defaults).agents == [captain])
    }
}
