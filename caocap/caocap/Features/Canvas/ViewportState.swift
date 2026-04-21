import SwiftUI
import Observation

@Observable
public class ViewportState {
    public var offset: CGSize = .zero
    public var lastOffset: CGSize = .zero
    public var scale: CGFloat = 1.0
    public var lastScale: CGFloat = 1.0
    
    public let minScale: CGFloat = 0.1
    public let maxScale: CGFloat = 2.0
    
    public init() {}
    
    public func handleDragChanged(_ value: DragGesture.Value) {
        offset = CGSize(
            width: lastOffset.width + value.translation.width,
            height: lastOffset.height + value.translation.height
        )
    }
    
    public func handleDragEnded() {
        lastOffset = offset
    }
    
    public func handleMagnificationChanged(_ value: CGFloat) {
        let newScale = lastScale * value
        scale = min(max(newScale, minScale), maxScale)
    }
    
    public func handleMagnificationEnded() {
        lastScale = scale
    }
}
