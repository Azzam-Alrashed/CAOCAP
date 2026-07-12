import SwiftUI

/// Collects the intrinsic, unscaled size of each node card. Unlike a screen
/// frame, this value remains stable while the viewport pans and zooms.
struct NodeSizePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGSize] = [:]

    static func reduce(value: inout [UUID: CGSize], nextValue: () -> [UUID: CGSize]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
