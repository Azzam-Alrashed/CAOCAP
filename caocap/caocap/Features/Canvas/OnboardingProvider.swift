import Foundation
import CoreGraphics

public struct OnboardingProvider {
    public static var manifestoNodes: [SpatialNode] {
        [
            SpatialNode(
                position: .zero,
                title: "Hello, world!",
                subtitle: "You've entered a spatial IDE where code lives in 2D space.",
                icon: "hand.wave.fill",
                theme: .purple
            ),
            SpatialNode(
                position: CGPoint(x: 450, y: 150),
                title: "The Spatial Medium",
                subtitle: "Pan and zoom to explore the architecture of your software.",
                icon: "map.fill",
                theme: .blue
            ),
            SpatialNode(
                position: CGPoint(x: -400, y: 350),
                title: "Agentic Flow",
                subtitle: "AI agents don't just write code; they inhabit this workspace with you.",
                icon: "sparkles",
                theme: .pink
            ),
            SpatialNode(
                position: CGPoint(x: 100, y: -450),
                title: "Direct Manipulation",
                subtitle: "Grab an idea, move it, scale it, and see how it connects.",
                icon: "hand.point.up.left.fill",
                theme: .orange
            ),
            SpatialNode(
                position: CGPoint(x: -600, y: -100),
                title: "Start Building",
                subtitle: "Press Cmd+K to summon the Omnibox and create your first node.",
                icon: "command",
                theme: .green
            )
        ]
    }
}
