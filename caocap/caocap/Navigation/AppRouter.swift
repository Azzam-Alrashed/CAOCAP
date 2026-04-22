import Foundation
import Observation
import SwiftUI

public enum WorkspaceState: Equatable {
    case onboarding
    case home
    case project(String) // filename
}

@MainActor
@Observable
public class AppRouter {
    public var currentWorkspace: WorkspaceState
    public var projects: [String: ProjectStore] = [:]
    
    public let onboardingStore = ProjectStore(fileName: "onboarding_v2.json", projectName: "Onboarding")
    public let homeStore = ProjectStore(fileName: "home_v2.json", projectName: "Home", initialNodes: HomeProvider.homeNodes)
    
    public var activeStore: ProjectStore {
        switch currentWorkspace {
        case .onboarding: return onboardingStore
        case .home: return homeStore
        case .project(let fileName):
            if let store = projects[fileName] {
                return store
            }
            // Fallback (should not happen if managed correctly)
            return homeStore
        }
    }
    
    public init() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.currentWorkspace = hasCompletedOnboarding ? .home : .onboarding
    }
    
    public func navigate(to workspace: WorkspaceState) {
        currentWorkspace = workspace
        
        // Update UserDefaults if we navigate to home from onboarding
        if workspace == .home {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
    }
    
    public func createNewProject() {
        let id = UUID().uuidString.prefix(8)
        let fileName = "project_\(id).json"
        let newStore = ProjectStore(fileName: fileName, projectName: "New Project \(id)", initialNodes: [])
        projects[fileName] = newStore
        
        withAnimation(.spring()) {
            navigate(to: .project(fileName))
        }
    }
}
