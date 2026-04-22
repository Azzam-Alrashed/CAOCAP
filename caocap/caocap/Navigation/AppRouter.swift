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
    private var navigationStack: [WorkspaceState] = []
    
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
    
    public func navigate(to workspace: WorkspaceState, addToStack: Bool = true, animated: Bool = true) {
        let updateState = {
            if addToStack && self.currentWorkspace != workspace {
                self.navigationStack.append(self.currentWorkspace)
                // Prevent infinite stack growth
                if self.navigationStack.count > 50 {
                    self.navigationStack.removeFirst()
                }
            }
            self.currentWorkspace = workspace
            
            // Update UserDefaults if we navigate to home from onboarding
            if workspace == .home {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            }
        }
        
        if animated {
            withAnimation(.spring()) {
                updateState()
            }
        } else {
            updateState()
        }
    }
    
    public func goBack() {
        guard let previous = navigationStack.popLast() else { return }
        navigate(to: previous, addToStack: false, animated: true)
    }
    
    public func goHome() {
        navigate(to: .home, animated: true)
    }
    
    public func createNewProject() {
        let id = UUID().uuidString.prefix(8)
        let fileName = "project_\(id).json"
        let newStore = ProjectStore(fileName: fileName, projectName: "New Project \(id)", initialNodes: [])
        projects[fileName] = newStore
        
        navigate(to: .project(fileName), animated: true)
    }
}
