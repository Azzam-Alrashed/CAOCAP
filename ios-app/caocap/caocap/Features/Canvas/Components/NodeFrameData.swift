import SwiftUI

/// Captures the rendered on-screen frame of a single canvas node, measured inside
/// the `"canvas"` coordinate space. Passed up the SwiftUI preference tree so that
/// `ConnectionLayer` can draw arrows that terminate at the actual visual midpoint
/// of each node rather than relying on a mathematical approximation.
struct NodeFrameData: Equatable {
    /// The ID of the node this data belongs to.
    let nodeId: UUID
    /// The node's frame rect in the `"canvas"` named coordinate space.
    let frame: CGRect
    /// The rendered size of the node view.
    let size: CGSize

    /// The screen-space centre of the node's frame, used as the arrow endpoint.
    var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}

/// A SwiftUI `PreferenceKey` that collects `NodeFrameData` from every `NodeView`
/// in the hierarchy and merges them into a single dictionary keyed by node ID.
/// Newer values always win (last-writer-wins) so that rapidly re-rendered nodes
/// always report their latest frame.
struct NodeFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: NodeFrameData] = [:]

    static func reduce(value: inout [UUID: NodeFrameData], nextValue: () -> [UUID: NodeFrameData]) {
        // Newer measurement wins; safe because each node ID maps to exactly one view.
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
