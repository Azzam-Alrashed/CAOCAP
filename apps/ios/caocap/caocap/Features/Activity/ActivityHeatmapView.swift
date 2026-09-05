import SwiftUI

/// Reusable Sunday-to-Saturday activity grid shared by the root node and sheet.
struct ActivityHeatmapView: View {
    let days: [ActivityDay]
    var cellSize: CGFloat = 10
    var spacing: CGFloat = 3
    var showsLegend = false
    var accentColor: Color = .green

    private var weekCount: Int {
        days.count / 7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<weekCount, id: \.self) { weekIndex in
                    VStack(spacing: spacing) {
                        ForEach(daysForWeek(weekIndex)) { day in
                            ActivityHeatmapCell(
                                day: day,
                                size: cellSize,
                                accentColor: accentColor
                            )
                        }
                    }
                }
            }

            if showsLegend {
                HStack(spacing: 5) {
                    Spacer()
                    Text("Less")
                    ForEach(0..<5, id: \.self) { intensity in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(color(for: intensity))
                            .frame(width: cellSize, height: cellSize)
                    }
                    Text("More")
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            }
        }
    }

    private func daysForWeek(_ weekIndex: Int) -> [ActivityDay] {
        let start = weekIndex * 7
        guard start < days.count else { return [] }
        return Array(days[start..<min(start + 7, days.count)])
    }

    private func color(for intensity: Int) -> Color {
        switch intensity {
        case 1: return accentColor.opacity(0.28)
        case 2: return accentColor.opacity(0.48)
        case 3: return accentColor.opacity(0.72)
        case 4: return accentColor
        default: return Color.secondary.opacity(0.12)
        }
    }
}

private struct ActivityHeatmapCell: View {
    let day: ActivityDay
    let size: CGFloat
    let accentColor: Color

    var body: some View {
        RoundedRectangle(cornerRadius: max(2, size * 0.22), style: .continuous)
            .fill(fillColor)
            .overlay {
                if day.isFuture {
                    RoundedRectangle(cornerRadius: max(2, size * 0.22), style: .continuous)
                        .stroke(Color.secondary.opacity(0.10), lineWidth: 0.5)
                }
            }
            .frame(width: size, height: size)
            .accessibilityElement()
            .accessibilityLabel(accessibilityText)
    }

    private var fillColor: Color {
        if day.isFuture {
            return Color.secondary.opacity(0.025)
        }
        switch day.intensity {
        case 1: return accentColor.opacity(0.28)
        case 2: return accentColor.opacity(0.48)
        case 3: return accentColor.opacity(0.72)
        case 4: return accentColor
        default: return Color.secondary.opacity(0.12)
        }
    }

    private var accessibilityText: String {
        let formattedDate = day.date.formatted(date: .long, time: .omitted)
        if day.isFuture {
            return LocalizationManager.shared.localizedString(
                "activity.futureDate",
                arguments: [formattedDate]
            )
        }
        return LocalizationManager.shared.localizedString(
            "activity.savedChangesOnDate",
            arguments: [String(day.count), formattedDate]
        )
    }
}
