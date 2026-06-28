import SwiftUI

/// Iron, gold, and diamond challenge badges for the Daily root node.
struct DailyBadgesRow: View {
    let store: GamificationStore
    var onSelectChallenge: ((DailyChallengeDefinition) -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            ForEach(store.challengesForToday) { challenge in
                Button {
                    onSelectChallenge?(challenge)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(challenge.tier.badgeImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 52)
                            .opacity(store.isChallengeCompletedToday(challenge.id) ? 1 : 0.3)

                        if store.isChallengeCompletedToday(challenge.id) {
                            Text("1")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(Color.green, in: Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(challenge.title)
                .accessibilityValue(
                    store.isChallengeCompletedToday(challenge.id) ? "Completed" : "Incomplete"
                )
            }
        }
    }
}
