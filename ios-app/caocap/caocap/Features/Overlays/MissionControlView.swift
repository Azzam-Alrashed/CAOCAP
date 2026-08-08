import SwiftUI

/// Mid-sheet overlay opened by FAB tap. Canvas stays home underneath.
struct MissionControlView: View {
    var body: some View {
        NavigationStack {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Mission Control")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
