import SwiftUI
import Observation

@MainActor
@Observable
public class CoCaptainViewModel {
    public var isPresented: Bool = false
    public var messages: [ChatMessage] = [
        ChatMessage(text: "Hello! I'm your Co-Captain. How can I help you build today?", isUser: false)
    ]
    
    public var store: ProjectStore?
    
    public init() {}
    
    public func setPresented(_ presented: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = presented
        }
    }
    
    // MARK: - Constants
    private enum Constants {
        static let thinkingDelay: UInt64 = 1_000_000_000 // 1 second
        static let layoutSpacing: CGFloat = 200
        static let verticalOffset: CGFloat = 150
    }
    
    public func sendMessage(_ text: String) {
        let userMessage = ChatMessage(text: text, isUser: true)
        messages.append(userMessage)
        
        // Process Intent
        Task {
            try? await Task.sleep(nanoseconds: Constants.thinkingDelay)
            
            let normalizedText = text.lowercased()
            let isPrototypingIntent = normalizedText.contains("game") || normalizedText.contains("prototype")
            
            if isPrototypingIntent {
                generatePrototype(for: text)
                let aiMessage = ChatMessage(text: "I've laid out the foundation for your mini-game on the canvas! I've added nodes for Logic, Physics, and Assets.", isUser: false)
                messages.append(aiMessage)
            } else {
                let aiMessage = ChatMessage(text: "That sounds interesting! I can help you prototype that. Try asking me to 'build a mini-game' to see my spatial prototyping in action.", isUser: false)
                messages.append(aiMessage)
            }
        }
    }
    
    private func generatePrototype(for intent: String) {
        guard let store = store else { return }
        
        // Calculate the center of the current viewport to spawn nodes
        let center = CGPoint(
            x: -store.viewportOffset.width / store.viewportScale,
            y: -store.viewportOffset.height / store.viewportScale
        )
        
        let nodes = [
            SpatialNode(
                position: CGPoint(x: center.x, y: center.y - Constants.verticalOffset),
                title: "Game Engine",
                subtitle: "Core loop and state management.",
                icon: "cpu",
                theme: .purple
            ),
            SpatialNode(
                position: CGPoint(x: center.x - Constants.layoutSpacing, y: center.y + Constants.verticalOffset),
                title: "Physics",
                subtitle: "Collision and movement logic.",
                icon: "bolt.fill",
                theme: .orange
            ),
            SpatialNode(
                position: CGPoint(x: center.x + Constants.layoutSpacing, y: center.y + Constants.verticalOffset),
                title: "Assets",
                subtitle: "Sprites, sounds, and levels.",
                icon: "photo.on.rectangle.angled",
                theme: .green
            )
        ]
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            store.nodes.append(contentsOf: nodes)
            store.requestSave()
        }
    }
}

public struct ChatMessage: Identifiable, Hashable {
    public let id = UUID()
    public let text: String
    public let isUser: Bool
}
