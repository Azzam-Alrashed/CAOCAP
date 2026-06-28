import SwiftUI

/// Expanded daily challenges and XP progress presented from the root Daily node.
struct DailyChallengesView: View {
    let store: GamificationStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily HTML Challenges")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                        Text("Edit any Mini-App code on your canvas to complete today's challenges.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    xpCard

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Today's badges")
                            .font(.system(size: 17, weight: .bold, design: .rounded))

                        DailyBadgesRow(store: store)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Challenges")
                            .font(.system(size: 17, weight: .bold, design: .rounded))

                        ForEach(store.challengesForToday) { challenge in
                            challengeRow(challenge)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Daily")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var xpCard: some View {
        let progress = store.levelProgress
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Level \(progress.level)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                Spacer()
                Text(progress.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.indigo)
            }

            ProgressView(value: progress.progressFraction)
                .tint(.indigo)

            Text("\(progress.currentXP) XP · \(store.completedCountToday)/3 challenges today")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.indigo.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func challengeRow(_ challenge: DailyChallengeDefinition) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(challenge.tier.badgeImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .opacity(store.isChallengeCompletedToday(challenge.id) ? 1 : 0.35)

            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(challenge.description)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text("+\(challenge.tier.xpReward) XP")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.indigo)
            }

            Spacer()

            if store.isChallengeCompletedToday(challenge.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
