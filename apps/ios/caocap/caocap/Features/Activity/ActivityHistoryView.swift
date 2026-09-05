import SwiftUI

/// Expanded device-wide activity history presented from the root Activity node.
struct ActivityHistoryView: View {
    let store: ActivityStore
    @Environment(\.dismiss) private var dismiss

    init(store: ActivityStore) {
        self.store = store
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your building activity")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                        Text("Every square reflects successful saves across your local canvases.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        ActivityStatCard(value: store.todayCount, label: "Today")
                        ActivityStatCard(value: store.activeDayCount, label: "Active days")
                        ActivityStatCard(value: store.totalSaveCount, label: "Saved changes")
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Last 17 weeks")
                            .font(.system(size: 17, weight: .bold, design: .rounded))

                        ScrollView(.horizontal, showsIndicators: false) {
                            ActivityHeatmapView(
                                days: store.days(),
                                cellSize: 12,
                                spacing: 4,
                                showsLegend: true
                            )
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.green.opacity(0.25), lineWidth: 1)
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ActivityStatCard: View {
    let value: Int
    let label: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value, format: .number)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.green)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .padding(12)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
