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
            
            // COLD BOOT FIX: Initialize and cache synchronously to prevent race conditions
            let newStore = ProjectStore(fileName: fileName)
            projects[fileName] = newStore
            return newStore
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
        
        let webViewId = UUID()
        let srsId = UUID()
        let htmlId = UUID()
        let cssId = UUID()
        let jsId = UUID()
        
        let initialNodes = [
            SpatialNode(
                id: webViewId,
                type: .webView,
                position: CGPoint(x: 375, y: 0),
                title: "Live Preview",
                subtitle: "Your mini-game will render here.",
                icon: "play.circle.fill",
                theme: .blue
            ),
            SpatialNode(
                id: srsId,
                type: .srs,
                position: CGPoint(x: -275, y: -200),
                title: "Software Requirements (SRS)",
                subtitle: "Define the core logic and rules here.",
                icon: "doc.text.fill",
                theme: .purple,
                textContent: "1. The user should be able to...\n2. The system must...\n"
            ),
            SpatialNode(
                id: htmlId,
                type: .code,
                position: CGPoint(x: -275, y: 0),
                title: "HTML",
                subtitle: "Document structure.",
                icon: "chevron.left.slash.chevron.right",
                theme: .orange,
                connectedNodeIds: [srsId, webViewId],
                textContent: "<!DOCTYPE html>\n<html>\n<head>\n    <title>My App</title>\n</head>\n<body>\n    <h1>Hello World!</h1>\n</body>\n</html>"
            ),
            SpatialNode(
                id: cssId,
                type: .code,
                position: CGPoint(x: -475, y: 200),
                title: "CSS",
                subtitle: "Styling and layout.",
                icon: "paintpalette.fill",
                theme: .blue,
                connectedNodeIds: [htmlId],
                textContent: "body {\n    background-color: #0d0d0d;\n    color: #ffffff;\n    display: flex;\n    justify-content: center;\n    align-items: center;\n    height: 100vh;\n    margin: 0;\n    font-family: -apple-system, BlinkMacSystemFont, sans-serif;\n    overflow: hidden;\n}\n\nh1 {\n    font-size: 3rem;\n    background: linear-gradient(90deg, #00C9FF 0%, #92FE9D 100%);\n    -webkit-background-clip: text;\n    -webkit-text-fill-color: transparent;\n    cursor: pointer;\n    transition: transform 0.1s ease-out, filter 0.3s ease;\n}\n\nh1:hover {\n    filter: drop-shadow(0 0 10px rgba(0, 201, 255, 0.5));\n}"
            ),
            SpatialNode(
                id: jsId,
                type: .code,
                position: CGPoint(x: -75, y: 200),
                title: "JavaScript",
                subtitle: "Interactivity and logic.",
                icon: "script",
                theme: .green,
                connectedNodeIds: [htmlId],
                textContent: "document.addEventListener('DOMContentLoaded', () => {\n    const text = document.querySelector('h1');\n    \n    // Parallax mouse effect\n    document.addEventListener('mousemove', (e) => {\n        const x = (window.innerWidth / 2 - e.pageX) / 25;\n        const y = (window.innerHeight / 2 - e.pageY) / 25;\n        text.style.transform = `translate(${x}px, ${y}px)`;\n    });\n    \n    // Click interaction\n    text.addEventListener('click', () => {\n        text.style.transform = 'scale(1.2)';\n        setTimeout(() => {\n            text.style.transform = 'scale(1)';\n        }, 150);\n    });\n});"
            )
        ]
        
        let newStore = ProjectStore(fileName: fileName, projectName: "New Project \(id)", initialNodes: initialNodes, initialViewportScale: 0.3)
        projects[fileName] = newStore
        
        navigate(to: .project(fileName), animated: true)
    }
}
