import SwiftUI

/// Compact XP level summary for Profile.
struct GamificationLevelCard: View {
    let store: GamificationStore

    var body: some View {
        let progress = store.levelProgress
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Studio Level", systemImage: "rosette")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(progress.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }

            ProgressView(value: progress.progressFraction)
                .tint(.indigo)

            Text("Level \(progress.level) · \(progress.currentXP) XP")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.indigo.opacity(0.2), lineWidth: 1)
        }
    }
}
