import SwiftUI

struct FloatingCommandButton: View {
    @State private var position: CGPoint = .zero
    @State private var startPosition: CGPoint = .zero // Track where the drag started
    @State private var isDragging: Bool = false
    @State private var isExpanded: Bool = false // Toggle for quick actions
    
    @Environment(\.colorScheme) var colorScheme
    
    var onTap: () -> Void
    var onUndo: () -> Void
    var onSummonCoCaptain: () -> Void
    var onRedo: () -> Void
    var canUndo: Bool = false
    var canRedo: Bool = false
    
    // Padding from screen edges
    private let padding: CGFloat = 35
    private let buttonSize: CGFloat = 64
    private let bubbleSize: CGFloat = 48
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let currentPos = position == .zero ? initialPosition(in: size) : position
            
            ZStack {
                // Layer -1: Dismissal Layer (Only active when expanded)
                if isExpanded {
                    Color.black.opacity(0.01) // Nearly invisible but catches taps
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isExpanded = false
                            }
                        }
                }
                
                // Layer 0: Quick Action Bubbles (Always in hierarchy for animation)
                quickActionBubbles(around: currentPos, in: size)
                
                // Layer 1: The Main Button
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(isDragging || isExpanded ? 0.3 : 0.2), 
                                radius: isDragging || isExpanded ? 15 : 10, 
                                x: 0, 
                                y: isDragging || isExpanded ? 8 : 5)
                    
                    Image(systemName: isExpanded ? "xmark" : "command")
                        .font(.system(size: 24, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .frame(width: buttonSize, height: buttonSize)
                .scaleEffect(isDragging ? 1.15 : (isExpanded ? 0.9 : 1.0))
                .position(currentPos)
                .onTapGesture {
                    if isExpanded {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded = false
                        }
                    } else {
                        triggerHapticFeedback(.medium)
                        onTap()
                    }
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    triggerHapticFeedback(.heavy)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        isExpanded.toggle()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .named("floatingLayer"))
                        .onChanged { value in
                            if isExpanded {
                                withAnimation(.spring()) { isExpanded = false }
                            }
                            
                            if !isDragging {
                                startPosition = currentPos
                                withAnimation(.interactiveSpring()) {
                                    isDragging = true
                                }
                                triggerHapticFeedback(.light)
                            }
                            
                            position = CGPoint(
                                x: startPosition.x + value.translation.width,
                                y: startPosition.y + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isDragging = false
                                snapToNearestPoint(in: size)
                            }
                        }
                )
            }
            .coordinateSpace(name: "floatingLayer")
            .onAppear {
                if position == .zero {
                    position = initialPosition(in: size)
                }
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                withAnimation(.spring()) {
                    snapToNearestPoint(in: newSize)
                }
            }
        }
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private func quickActionBubbles(around pos: CGPoint, in size: CGSize) -> some View {
        let direction = sproutDirection(for: pos, in: size)
        let distance: CGFloat = 75 
        let angle: CGFloat = 45 
        
        ZStack {
            // 1. Center: CoCaptain (Primary size)
            QuickActionBubble(icon: "sparkles", color: .blue, isExpanded: isExpanded, size: 48, delay: 0.05) {
                triggerHapticFeedback(.medium)
                withAnimation(.spring()) { isExpanded = false }
                onSummonCoCaptain()
            }
            .offset(x: isExpanded ? direction.x * distance : 0, 
                    y: isExpanded ? direction.y * distance : 0)
            
            // 2. Left: Undo (Smaller size)
            QuickActionBubble(icon: "arrow.uturn.backward", color: .secondary, isExpanded: isExpanded, isEnabled: canUndo, size: 40, delay: 0.0) {
                triggerHapticFeedback(.medium)
                withAnimation(.spring()) { isExpanded = false }
                onUndo()
            }
            .offset(x: isExpanded ? direction.rotated(by: -angle).x * distance : 0, 
                    y: isExpanded ? direction.rotated(by: -angle).y * distance : 0)
            
            // 3. Right: Redo (Smaller size)
            QuickActionBubble(icon: "arrow.uturn.forward", color: .secondary, isExpanded: isExpanded, isEnabled: canRedo, size: 40, delay: 0.1) {
                triggerHapticFeedback(.medium)
                withAnimation(.spring()) { isExpanded = false }
                onRedo()
            }
            .offset(x: isExpanded ? direction.rotated(by: angle).x * distance : 0, 
                    y: isExpanded ? direction.rotated(by: angle).y * distance : 0)
        }
        .position(pos)
    }
    
    private func sproutDirection(for pos: CGPoint, in size: CGSize) -> CGPoint {
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        // Point towards the center of the screen
        let dx = centerX - pos.x
        let dy = centerY - pos.y
        let len = sqrt(dx*dx + dy*dy)
        
        return len > 0 ? CGPoint(x: dx/len, y: dy/len) : CGPoint(x: 0, y: -1)
    }
    
    private func initialPosition(in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width - padding - buttonSize/2,
            y: size.height - padding - buttonSize/2
        )
    }
    
    private func snapToNearestPoint(in size: CGSize) {
        let minX = padding + buttonSize/2
        let maxX = size.width - padding - buttonSize/2
        let minY = 60 + buttonSize/2
        let maxY = size.height - padding - buttonSize/2
        
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        let points: [CGPoint] = [
            CGPoint(x: minX, y: minY), CGPoint(x: centerX, y: minY), CGPoint(x: maxX, y: minY),
            CGPoint(x: minX, y: centerY), CGPoint(x: maxX, y: centerY),
            CGPoint(x: minX, y: maxY), CGPoint(x: centerX, y: maxY), CGPoint(x: maxX, y: maxY)
        ]
        
        position = points.min(by: { distance(from: $0, to: position) < distance(from: $1, to: position) }) ?? points[7]
        triggerHapticFeedback(.rigid)
    }
    
    private func distance(from: CGPoint, to: CGPoint) -> CGFloat {
        sqrt(pow(from.x - to.x, 2) + pow(from.y - to.y, 2))
    }
    
    private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

struct QuickActionBubble: View {
    let icon: String
    let color: Color
    let isExpanded: Bool
    var isEnabled: Bool = true
    var size: CGFloat = 48
    let delay: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            if isEnabled {
                action()
            }
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(color.opacity(isEnabled ? 0.3 : 0.1), lineWidth: 1))
                    .shadow(color: color.opacity(isEnabled ? 0.2 : 0), radius: 8)
                
                Image(systemName: icon)
                    .font(.system(size: size * 0.375, weight: .bold)) // Scale icon proportionally
                    .foregroundColor(color)
                    .opacity(isEnabled ? 1.0 : 0.3)
            }
            .frame(width: size, height: size)
            .scaleEffect(isExpanded ? 1 : 0.01)
            .opacity(isExpanded ? (isEnabled ? 1 : 0.5) : 0)
        }
        .disabled(!isEnabled)
        .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(isExpanded ? delay : 0), value: isExpanded)
        .animation(.spring(), value: isEnabled)
    }
}

extension CGPoint {
    func rotated(by degrees: CGFloat) -> CGPoint {
        let radians = degrees * .pi / 180
        let sinTheta = sin(radians)
        let cosTheta = cos(radians)
        return CGPoint(
            x: x * cosTheta - y * sinTheta,
            y: x * sinTheta + y * cosTheta
        )
    }
}
