import Foundation
import Observation

/// Local library membership. Acquisition and custom agent configuration are still TBD.
struct LibraryAgent: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let persona: CopilotPersona

    var workspaceFileName: String { "canvas_agent_\(id).json" }

    static let defaults: [LibraryAgent] = CopilotPersona.allCases.map {
        LibraryAgent(id: $0.rawValue, name: $0.displayName, persona: $0)
    }
}

@MainActor
@Observable
final class AgentLibrary {
    private(set) var agents: [LibraryAgent]
    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = "agent_library_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([LibraryAgent].self, from: data) {
            agents = saved
        } else {
            agents = LibraryAgent.defaults
        }
    }

    func remove(_ agent: LibraryAgent) {
        agents.removeAll { $0.id == agent.id }
        persist()
    }

    func restore(_ agent: LibraryAgent) {
        guard !agents.contains(where: { $0.id == agent.id }) else { return }
        agents.append(agent)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(agents) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

enum HubTab: Hashable {
    case explore, home, communities
}
