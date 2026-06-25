import Foundation
import Observation
import SwiftUI

public enum WorkspaceState: Equatable {
    case root
    case project(String) // filename
}

/// Coordinates top-level workspace navigation and owns the active stores for
/// home and user-created projects.
@MainActor
@Observable
public class AppRouter {
    public var currentWorkspace: WorkspaceState
    public var projects: [String: ProjectStore] = [:]
    private var navigationStack: [WorkspaceState] = []
    
    public let rootStore: ProjectStore
    
    /// Returns the store for the current workspace, lazily creating project
    /// stores on cold boot when navigation restores a project filename.
    public var activeStore: ProjectStore {
        switch currentWorkspace {
        case .root: return rootStore
        case .project(let fileName):
            if let store = projects[fileName] {
                return store
            }
            
            // COLD BOOT FIX: Initialize and cache synchronously to prevent race conditions
            let newStore = ProjectStore(fileName: fileName)
            projects[fileName] = newStore
            return newStore
        }
    }
    
    public init() {
        CanvasWorkspaceMigration.runIfNeeded()
        self.currentWorkspace = .root
        self.rootStore = ProjectStore(
            fileName: CanvasFileNaming.rootFileName,
            projectName: "Root",
            initialNodes: ProjectTemplateProvider.defaultNodes,
            initialViewportScale: 0.5
        )
    }
    
    /// Moves between workspaces and records onboarding completion when the user
    /// reaches Home, which makes Home the default workspace on the next launch.
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
            
            if case .project(let fileName) = workspace {
                UserDefaults.standard.set(fileName, forKey: "lastCanvasFileName")
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
    
    public func goRoot() {
        navigate(to: .root, animated: true)
    }
    
    public func navigateToSubCanvas(fileName: String) {
        let resolved = CanvasFileNaming.resolveExistingFileName(fileName)
        navigate(to: .project(resolved), animated: true)
    }

    public func createFreshMiniAppCanvas() {
        let fileName = CanvasFileNaming.newCanvasFileName()
        let store = ProjectStore(
            fileName: fileName,
            projectName: "Mini-App Canvas",
            initialNodes: ProjectTemplateProvider.defaultNodes
        )
        projects[fileName] = store
        navigate(to: .project(fileName), animated: true)
    }
}
