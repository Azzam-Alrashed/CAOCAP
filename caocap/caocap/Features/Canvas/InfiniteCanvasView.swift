import SwiftUI

struct InfiniteCanvasView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var viewport = ViewportState()
    @State private var nodes: [SpatialNode] = OnboardingProvider.manifestoNodes
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // The Dotted Background
                DottedBackground(offset: viewport.offset, scale: viewport.scale)
                
                // The Content Layer
                ZStack {
                    ForEach(nodes) { node in
                        NodeView(node: node)
                            .position(
                                x: center.x + node.position.x,
                                y: center.y + node.position.y
                            )
                    }
                }
                .scaleEffect(viewport.scale)
                .offset(viewport.offset)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture()
                    .onChanged { viewport.handleDragChanged($0) }
                    .onEnded { _ in viewport.handleDragEnded() }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { viewport.handleMagnificationChanged($0) }
                    .onEnded { _ in viewport.handleMagnificationEnded() }
            )
        }
        .background(backgroundColor)
        .edgesIgnoringSafeArea(.all)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.05) : Color(white: 0.95)
    }
}

struct DottedBackground: View {
    @Environment(\.colorScheme) var colorScheme
    let offset: CGSize
    let scale: CGFloat
    
    let dotSpacing: CGFloat = 30
    let dotSize: CGFloat = 2
    
    var body: some View {
        Canvas { context, size in
            let scaledSpacing = dotSpacing * scale
            let dotColor = colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5)
            
            let centerX = size.width / 2
            let centerY = size.height / 2
            
            let startX = ((offset.width + centerX).truncatingRemainder(dividingBy: scaledSpacing)) - scaledSpacing
            let startY = ((offset.height + centerY).truncatingRemainder(dividingBy: scaledSpacing)) - scaledSpacing
            
            for x in stride(from: startX, through: size.width + scaledSpacing, by: scaledSpacing) {
                for y in stride(from: startY, through: size.height + scaledSpacing, by: scaledSpacing) {
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                }
            }
        }
    }
}

#Preview {
    InfiniteCanvasView()
}
