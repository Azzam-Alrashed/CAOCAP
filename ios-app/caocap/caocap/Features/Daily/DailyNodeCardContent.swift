import SwiftUI

/// Inline daily challenge preview for the protected Daily root node.
struct DailyNodeCardContent: View {
    let store: GamificationStore
    @State private var selectedChallenge: DailyChallengeDefinition?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DailyBadgesRow(store: store) { challenge in
                selectedChallenge = challenge
            }

            Text("\(store.completedCountToday)/3 complete today")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 14)
        .popover(item: $selectedChallenge) { challenge in
            VStack(alignment: .leading, spacing: 8) {
                Text(challenge.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(challenge.description)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .presentationCompactAdaptation(.popover)
        }
    }
}
