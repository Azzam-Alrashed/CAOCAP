import Foundation
import Charts
import SwiftUI

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

struct ChartNodeView: View {
    let node: SpatialNode
    let allNodes: [SpatialNode]
    var isScrollable: Bool = false
    var onUpdateX: ((Int?) -> Void)? = nil
    var onUpdateY: ((Int?) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let tableNode = connectedTableNode, !headers(for: tableNode).isEmpty {
                columnSelectorRow(for: tableNode)
            }

            if chartData.isEmpty {
                emptyState
            } else {
                let minWidth: CGFloat = 280
                let dynamicWidth = max(minWidth, CGFloat(chartData.count) * 60)

                if isScrollable {
                    ScrollView(.horizontal, showsIndicators: false) {
                        chartContent(width: dynamicWidth)
                    }
                } else {
                    chartContent(width: dynamicWidth)
                }
            }

            HStack {
                Label(node.chartStyle?.displayName.uppercased() ?? "CHART", systemImage: node.chartStyle?.icon ?? "chart.xyaxis.line")
                    .font(.system(size: 10, weight: .black))
                    .opacity(0.4)

                Spacer()

                Text("\(chartData.count) DATA POINTS")
                    .font(.system(size: 9, weight: .bold))
                    .opacity(0.3)
            }
        }
        .padding(.top, 12)
    }

    private func columnSelectorRow(for tableNode: SpatialNode) -> some View {
        let headers = headers(for: tableNode)

        return HStack(spacing: 8) {
            columnMenu(
                title: "X",
                selectedIndex: node.chartXColumnIndex,
                headers: headers,
                defaultTitle: "Auto",
                onUpdate: onUpdateX
            )

            columnMenu(
                title: "Y",
                selectedIndex: node.chartYColumnIndex,
                headers: headers,
                defaultTitle: "Auto",
                onUpdate: onUpdateY
            )

            Spacer()
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func columnMenu(
        title: String,
        selectedIndex: Int?,
        headers: [String],
        defaultTitle: String,
        onUpdate: ((Int?) -> Void)?
    ) -> some View {
        Menu {
            ForEach(headers.indices, id: \.self) { index in
                Button {
                    onUpdate?(index)
                } label: {
                    HStack {
                        Text(headers[index])
                        if selectedIndex == index {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Button(defaultTitle) {
                onUpdate?(nil)
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(title): \(columnLabel(for: selectedIndex, headers: headers, defaultTitle: defaultTitle))")
                Image(systemName: "chevron.down")
            }
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundColor(node.theme.color.opacity(0.3))

            Text("No numeric data found")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(Color.black.opacity(0.05))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func chartContent(width: CGFloat) -> some View {
        Chart {
            ForEach(chartData) { point in
                switch node.chartStyle ?? .bar {
                case .bar:
                    BarMark(
                        x: .value("Category", point.label),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(point.color.gradient)
                    .cornerRadius(4)

                case .line:
                    LineMark(
                        x: .value("Category", point.label),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(point.color.gradient)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    PointMark(
                        x: .value("Category", point.label),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(point.color)

                case .area:
                    AreaMark(
                        x: .value("Category", point.label),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(point.color.opacity(0.3).gradient)
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Category", point.label),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(point.color)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
        }
        .frame(width: width)
        .frame(height: 160)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
                    .font(.system(size: 10, design: .monospaced))
            }
        }
        .padding(.trailing, 20)
    }

    private var connectedTableNode: SpatialNode? {
        let allSourceIds = sourceIds()
        return allNodes.first { allSourceIds.contains($0.id) && $0.type == .table }
    }

    private var chartData: [ChartDataPoint] {
        sourceIds()
            .sorted { $0.uuidString < $1.uuidString }
            .compactMap { id in allNodes.first { $0.id == id } }
            .flatMap { dataPoints(from: $0) }
    }

    private func sourceIds() -> Set<UUID> {
        var ids = Set(node.inputNodeIds ?? [])
        let structuralIds = allNodes
            .filter { $0.nextNodeId == node.id || ($0.connectedNodeIds ?? []).contains(node.id) }
            .map(\.id)
        ids.formUnion(structuralIds)
        return ids
    }

    private func dataPoints(from sourceNode: SpatialNode) -> [ChartDataPoint] {
        if sourceNode.type == .table {
            return tableDataPoints(from: sourceNode)
        }

        return [
            ChartDataPoint(
                label: sourceNode.displayTitle,
                value: numericValue(from: sourceNode),
                color: sourceNode.theme.color
            )
        ]
    }

    private func tableDataPoints(from sourceNode: SpatialNode) -> [ChartDataPoint] {
        let allRows = rows(from: sourceNode)
        let dataRows = (node.chartHasHeaderRow ?? false) ? Array(allRows.dropFirst()) : allRows

        return dataRows.enumerated().compactMap { index, row in
            let columns = columns(from: row)
            guard !columns.isEmpty else { return nil }

            let label: String
            if let xIndex = node.chartXColumnIndex, columns.indices.contains(xIndex) {
                label = columns[xIndex]
            } else if columns.count >= 2 {
                label = columns[0]
            } else {
                label = "Row \(index + 1)"
            }

            let value: Double?
            if let yIndex = node.chartYColumnIndex, columns.indices.contains(yIndex) {
                value = numericValue(from: columns[yIndex])
            } else {
                if let preferredValue = columns.dropFirst().compactMap({ numericValue(from: $0) }).first {
                    value = preferredValue
                } else {
                    value = columns.compactMap { numericValue(from: $0) }.first
                }
            }

            guard let value else { return nil }
            return ChartDataPoint(label: label, value: value, color: sourceNode.theme.color)
        }
    }

    private func rows(from tableNode: SpatialNode) -> [String] {
        (tableNode.textContent ?? "")
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func headers(for tableNode: SpatialNode) -> [String] {
        guard let firstRow = rows(from: tableNode).first else { return [] }
        return columns(from: firstRow)
    }

    private func columns(from row: String) -> [String] {
        row.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func numericValue(from node: SpatialNode) -> Double {
        if let outputValue = node.outputValue {
            return outputValue
        }

        let text = node.textContent ?? node.aiResponse ?? node.subtitle ?? "0"
        return numericValue(from: text) ?? 0
    }

    private func numericValue(from text: String) -> Double? {
        let cleaned = text.filter { "0123456789.-".contains($0) }
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    private func columnLabel(for index: Int?, headers: [String], defaultTitle: String) -> String {
        guard let index, headers.indices.contains(index) else { return defaultTitle }
        return headers[index]
    }
}
