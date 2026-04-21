import Foundation
import Observation

public enum OnboardingStep: Int, CaseIterable, Codable {
    case panning = 0
    case dragging = 1
    case clicking = 2
    case transition = 3
    case completed = 4
    
    public var instruction: String {
        switch self {
        case .panning: return "Pan the canvas to explore the space."
        case .dragging: return "Drag a node to organize your workspace."
        case .clicking: return "Click a node to see its details."
        case .transition: return "Click the 'Launch' node to start your project."
        case .completed: return ""
        }
    }
    
    public var icon: String {
        switch self {
        case .panning: return "hand.draw"
        case .dragging: return "arrow.up.and.down.and.arrow.left.and.right"
        case .clicking: return "hand.point.up.fill"
        case .transition: return "rocket.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

@Observable
public class OnboardingManager {
    public var currentStep: OnboardingStep = .panning
    public var isBlankCanvasActive: Bool = false
    
    public init() {}
    
    public func advance(from step: OnboardingStep) {
        guard step == currentStep else { return }
        if let next = OnboardingStep(rawValue: step.rawValue + 1) {
            currentStep = next
        }
    }
    
    public func reset() {
        currentStep = .panning
        isBlankCanvasActive = false
    }
    
    public func launchProject() {
        isBlankCanvasActive = true
    }
}
