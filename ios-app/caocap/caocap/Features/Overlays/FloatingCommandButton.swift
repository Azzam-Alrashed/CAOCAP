import SwiftUI

struct FloatingCommandButton: View {
    @State private var position: CGPoint = .zero
    @State private var startPosition: CGPoint = .zero 
    @State private var isDragging: Bool = false
    @State private var isExpanded: Bool = false 
    @State private var activeAction: CommandAction? = nil
    
    enum CommandAction {
        case undo, summon, redo
    }
    
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
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.25)
                        .onEnded { _ in
                            if !isDragging {
                                triggerHapticFeedback(.heavy)
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                    isExpanded = true
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("floatingLayer"))
                        .onChanged { value in
                            if isExpanded {
                                // Selection Mode
                                updateActiveAction(at: value.location, center: currentPos, size: size)
                            } else {
                                // Movement Mode (with threshold)
                                let dragThreshold: CGFloat = 10
                                let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                                
                                if dragDistance > dragThreshold {
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
                            }
                        }
                        .onEnded { value in
                            if isExpanded {
                                if let action = activeAction {
                                    executeAction(action)
                                }
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isExpanded = false
                                    activeAction = nil
                                }
                            } else if isDragging {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    isDragging = false
                                    snapToNearestPoint(in: size)
                                }
                            } else {
                                // This is a tap!
                                // Long press takes 0.25s, so a fast tap should trigger here
                                triggerHapticFeedback(.medium)
                                onTap()
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
            // 1. Center: CoCaptain
            QuickActionBubble(
                icon: "sparkles", 
                color: .blue, 
                isExpanded: isExpanded, 
                isHighlighted: activeAction == .summon,
                size: 48, 
                delay: 0.05
            ) {
                triggerHapticFeedback(.medium)
                withAnimation(.spring()) { isExpanded = false }
                onSummonCoCaptain()
            }
            .offset(x: isExpanded ? direction.x * distance : 0, 
                    y: isExpanded ? direction.y * distance : 0)
            
            // 2. Left: Undo
            QuickActionBubble(
                icon: "arrow.uturn.backward", 
                color: .secondary, 
                isExpanded: isExpanded, 
                isEnabled: canUndo, 
                isHighlighted: activeAction == .undo,
                size: 40, 
                delay: 0.0
            ) {
                triggerHapticFeedback(.medium)
                withAnimation(.spring()) { isExpanded = false }
                onUndo()
            }
            .offset(x: isExpanded ? direction.rotated(by: -angle).x * distance : 0, 
                    y: isExpanded ? direction.rotated(by: -angle).y * distance : 0)
            
            // 3. Right: Redo
            QuickActionBubble(
                icon: "arrow.uturn.forward", 
                color: .secondary, 
                isExpanded: isExpanded, 
                isEnabled: canRedo, 
                isHighlighted: activeAction == .redo,
                size: 40, 
                delay: 0.1
            ) {
                triggerHapticFeedback(.medium)
                withAnimation(.spring()) { isExpanded = false }
                onRedo()
            }
            .offset(x: isExpanded ? direction.rotated(by: angle).x * distance : 0, 
                    y: isExpanded ? direction.rotated(by: angle).y * distance : 0)
        }
        .position(pos)
    }
    
    private func updateActiveAction(at location: CGPoint, center: CGPoint, size: CGSize) {
        let direction = sproutDirection(for: center, in: size)
        let distance: CGFloat = 75
        let angle: CGFloat = 45
        let threshold: CGFloat = 40 // Selection "hit zone" radius
        
        let undoPos = CGPoint(
            x: center.x + direction.rotated(by: -angle).x * distance,
            y: center.y + direction.rotated(by: -angle).y * distance
        )
        let summonPos = CGPoint(
            x: center.x + direction.x * distance,
            y: center.y + direction.y * distance
        )
        let redoPos = CGPoint(
            x: center.x + direction.rotated(by: angle).x * distance,
            y: center.y + direction.rotated(by: angle).y * distance
        )
        
        let dUndo = sqrt(pow(location.x - undoPos.x, 2) + pow(location.y - undoPos.y, 2))
        let dSummon = sqrt(pow(location.x - summonPos.x, 2) + pow(location.y - summonPos.y, 2))
        let dRedo = sqrt(pow(location.x - redoPos.x, 2) + pow(location.y - redoPos.y, 2))
        
        let previousAction = activeAction
        
        if dUndo < threshold && canUndo {
            activeAction = .undo
        } else if dSummon < threshold {
            activeAction = .summon
        } else if dRedo < threshold && canRedo {
            activeAction = .redo
        } else {
            activeAction = nil
        }
        
        if activeAction != previousAction && activeAction != nil {
            triggerHapticFeedback(.light)
        }
    }
    
    private func executeAction(_ action: CommandAction) {
        triggerHapticFeedback(.medium)
        switch action {
        case .undo: onUndo()
        case .summon: onSummonCoCaptain()
        case .redo: onRedo()
        }
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
    var isHighlighted: Bool = false
    var size: CGFloat = 48
    let delay: Double
    let action: () -> Void
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(isHighlighted ? color : color.opacity(isEnabled ? 0.3 : 0.1), lineWidth: isHighlighted ? 2 : 1))
                .shadow(color: color.opacity(isHighlighted ? 0.5 : (isEnabled ? 0.2 : 0)), radius: isHighlighted ? 12 : 8)
            
            Image(systemName: icon)
                .font(.system(size: size * 0.375, weight: .bold)) 
                .foregroundColor(color)
                .opacity(isEnabled ? 1.0 : 0.3)
        }
        .frame(width: size, height: size)
        .scaleEffect(isExpanded ? (isHighlighted ? 1.25 : 1.0) : 0.01)
        .opacity(isExpanded ? (isEnabled ? 1 : 0.5) : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHighlighted)
        .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(isExpanded ? delay : 0), value: isExpanded)
        .animation(.spring(), value: isEnabled)
        .onTapGesture {
            if isEnabled && isExpanded {
                action()
            }
        }
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
