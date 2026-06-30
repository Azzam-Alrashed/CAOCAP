import SwiftUI

/// A container view that groups multiple related code edits (review items)
/// into a single visual bundle, allowing batch approval or rejection.
struct ReviewBundleView: View {
    let bundle: ReviewBundleItem
    let viewModel: CoCaptainViewModel
    let bundleID: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(bundle.title)
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }

            ForEach(bundle.items) { item in
                ReviewCardView(item: item) {
                    viewModel.applyReviewItem(bundleID: bundleID, itemID: item.id)
                } onReject: {
                    viewModel.rejectReviewItem(bundleID: bundleID, itemID: item.id)
                }
            }

            HStack(spacing: 16) {
                Spacer()
                Button(LocalizationManager.shared.localizedString("Apply All")) {
                    viewModel.applyAll(in: bundleID)
                }
                .font(.system(size: 12, weight: .semibold))
                .disabled(!hasPendingItems)

                Button(LocalizationManager.shared.localizedString("Reject All")) {
                    viewModel.rejectAll(in: bundleID)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.red)
                .disabled(!hasPendingItems)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// Returns `true` if at least one item in the bundle has not yet been resolved.
    private var hasPendingItems: Bool {
        bundle.items.contains { $0.status == .pending }
    }
}

/// A detailed card displaying a single proposed code edit, showing the target node,
/// summary, a diff/preview, and interactive Apply/Reject controls.
struct ReviewCardView: View {
    let item: PendingReviewItem
    let onApply: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.targetLabel)
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text(item.status.localizedTitle)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.14))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
            }

            Text(item.summary)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            if item.status == .conflicted, let reason = item.conflictDescription {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text(reason)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if let baseText = nodeEditBaseText {
                reviewTextBlock(
                    title: LocalizationManager.shared.localizedString("Before"),
                    text: baseText
                )
            }

            reviewTextBlock(
                title: nodeEditBaseText == nil
                    ? nil
                    : LocalizationManager.shared.localizedString("After"),
                text: item.preview.isEmpty
                    ? LocalizationManager.shared.localizedString("No preview available.")
                    : item.preview
            )

            HStack {
                Button(LocalizationManager.shared.localizedString("Apply")) {
                    onApply()
                }
                .buttonStyle(.borderedProminent)
                .disabled(item.status != .pending)

                Button(LocalizationManager.shared.localizedString("Reject")) {
                    onReject()
                }
                .buttonStyle(.bordered)
                .disabled(item.status != .pending)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var nodeEditBaseText: String? {
        guard case .nodeEdit(_, _, _, let baseText) = item.source else { return nil }
        let trimmed = baseText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : baseText
    }

    @ViewBuilder
    private func reviewTextBlock(title: String?, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            Text(text)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    /// Maps the current review status to a semantic UI color.
    private var statusColor: Color {
        switch item.status {
        case .pending: return .orange
        case .applied: return .green
        case .conflicted: return .red
        case .rejected: return .secondary
        }
    }
}
