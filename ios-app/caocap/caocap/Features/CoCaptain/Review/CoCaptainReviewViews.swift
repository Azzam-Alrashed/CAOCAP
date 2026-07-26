import SwiftUI

/// A container view that groups multiple related code edits (review items)
/// into a single visual bundle, allowing batch approval or rejection.
struct ReviewBundleView: View {
    let bundle: ReviewBundleItem
    let viewModel: CoCaptainViewModel
    let bundleID: UUID
    var isOnboardingReviewAnchorActive: Bool = false
    var isOnboardingApplyAnchorActive: Bool = false
    @State private var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        bundle: ReviewBundleItem,
        viewModel: CoCaptainViewModel,
        bundleID: UUID,
        isOnboardingReviewAnchorActive: Bool = false,
        isOnboardingApplyAnchorActive: Bool = false
    ) {
        self.bundle = bundle
        self.viewModel = viewModel
        self.bundleID = bundleID
        self.isOnboardingReviewAnchorActive = isOnboardingReviewAnchorActive
        self.isOnboardingApplyAnchorActive = isOnboardingApplyAnchorActive
        _isExpanded = State(
            initialValue: bundle.items.contains { $0.status.isUnresolved }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CoCaptainChatStyle.standardSpacing) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: CoCaptainChatStyle.smallSpacing) {
                    Image(systemName: "tray.full")
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(bundleTint, in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bundle.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(bundleSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(bundleSummary)

            if isExpanded {
                ForEach(bundle.items) { item in
                    ReviewCardView(
                        item: item,
                        onApply: {
                            viewModel.applyReviewItem(bundleID: bundleID, itemID: item.id)
                        },
                        onReject: {
                            viewModel.rejectReviewItem(bundleID: bundleID, itemID: item.id)
                        },
                        onFlyTo: {
                            if let nodeID = item.targetNodeID {
                                viewModel.flyToReviewTarget(nodeID)
                            }
                        },
                        onPickCandidate: { candidateID in
                            viewModel.resolveClarification(
                                bundleID: bundleID,
                                itemID: item.id,
                                candidateID: candidateID
                            )
                        },
                        isOnboardingReviewAnchorActive: isOnboardingReviewAnchorActive
                    )
                }

                if unresolvedItemCount > 1 {
                    HStack(spacing: CoCaptainChatStyle.standardSpacing) {
                        Spacer()
                        Button(LocalizationManager.shared.localizedString("Reject All")) {
                            viewModel.rejectAll(in: bundleID)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!hasUnresolvedItems)
                        .frame(minHeight: CoCaptainChatStyle.minimumHitSize)

                        Button(LocalizationManager.shared.localizedString("Apply All")) {
                            viewModel.applyAll(in: bundleID)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .frame(minHeight: CoCaptainChatStyle.minimumHitSize)
                        .disabled(!hasApprovableItems)
                        .background {
                            if isOnboardingApplyAnchorActive, hasApprovableItems {
                                Color.clear.onboardingTooltipAnchor(.coCaptainReviewApply)
                            }
                        }
                    }
                    .padding(.top, 2)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .move(edge: .top))
                    )
                }
            }
        }
        .padding(CoCaptainChatStyle.sectionSpacing)
        .coCaptainCardSurface(tint: bundleTint, cornerRadius: 18)
        .onChange(of: hasUnresolvedItems) { _, unresolved in
            if !unresolved {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = false
                }
            }
        }
    }

    private var hasApprovableItems: Bool {
        bundle.items.contains { $0.status == .pending }
    }

    private var hasUnresolvedItems: Bool {
        bundle.items.contains { $0.status.isUnresolved }
    }

    private var unresolvedItemCount: Int {
        bundle.items.filter { $0.status.isUnresolved }.count
    }

    private var bundleTint: Color {
        hasUnresolvedItems ? CoCaptainChatStyle.pending : CoCaptainChatStyle.success
    }

    private var bundleSummary: String {
        let unresolvedCount = unresolvedItemCount
        if unresolvedCount > 0 {
            return LocalizationManager.shared.localizedString(
                "%lld changes need your review",
                arguments: [Int64(unresolvedCount)]
            )
        }
        let appliedCount = bundle.items.filter { $0.status == .applied }.count
        if appliedCount > 0 {
            return LocalizationManager.shared.localizedString(
                "%lld changes applied",
                arguments: [Int64(appliedCount)]
            )
        }
        return LocalizationManager.shared.localizedString("Review completed")
    }
}

/// A detailed card displaying a single proposed code edit, showing the target node,
/// summary, a diff/preview, and interactive Apply/Reject controls.
struct ReviewCardView: View {
    let item: PendingReviewItem
    let onApply: () -> Void
    let onReject: () -> Void
    var onFlyTo: (() -> Void)? = nil
    var onPickCandidate: ((UUID) -> Void)? = nil
    var isOnboardingReviewAnchorActive: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: CoCaptainChatStyle.standardSpacing) {
            HStack {
                Text(item.summary)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text(item.status.localizedTitle)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.14))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
            }

            Label(item.targetLabel, systemImage: "square.dashed")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

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

            if item.status == .needsClarification {
                clarificationPicker
            } else {
                if let beforeText = focusedBeforeText {
                    reviewTextBlock(
                        title: LocalizationManager.shared.localizedString("Before"),
                        text: beforeText,
                        accent: .red,
                        linePrefix: "−"
                    )
                }

                reviewTextBlock(
                    title: focusedBeforeText == nil
                        ? nil
                        : LocalizationManager.shared.localizedString("After"),
                    text: item.preview.isEmpty
                        ? LocalizationManager.shared.localizedString("No preview available.")
                        : item.preview,
                    accent: focusedBeforeText == nil ? nil : .green,
                    linePrefix: focusedBeforeText == nil ? nil : "+"
                )
            }

            reviewActions
        }
        .padding(CoCaptainChatStyle.standardSpacing)
        .background(CoCaptainChatStyle.subtleFill)
        .clipShape(
            RoundedRectangle(
                cornerRadius: CoCaptainChatStyle.cardCornerRadius,
                style: .continuous
            )
        )
    }

    private var reviewActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: CoCaptainChatStyle.smallSpacing) {
                reviewActionButtons
            }

            VStack(alignment: .leading, spacing: CoCaptainChatStyle.smallSpacing) {
                reviewActionButtons
            }
        }
    }

    @ViewBuilder
    private var reviewActionButtons: some View {
        if item.targetNodeID != nil, let onFlyTo {
            Button(LocalizationManager.shared.localizedString("View on Canvas")) {
                onFlyTo()
            }
            .buttonStyle(.bordered)
            .disabled(!item.status.isUnresolved)
            .frame(minHeight: CoCaptainChatStyle.minimumHitSize)
        }

        if item.status == .needsClarification {
            Button(LocalizationManager.shared.localizedString("Never mind")) {
                onReject()
            }
            .buttonStyle(.bordered)
            .frame(minHeight: CoCaptainChatStyle.minimumHitSize)
        } else {
            Button(LocalizationManager.shared.localizedString("Reject")) {
                onReject()
            }
            .buttonStyle(.bordered)
            .disabled(item.status != .pending)
            .frame(minHeight: CoCaptainChatStyle.minimumHitSize)

            Button(LocalizationManager.shared.localizedString("Apply")) {
                onApply()
            }
            .buttonStyle(.borderedProminent)
            .disabled(item.status != .pending)
            .frame(minHeight: CoCaptainChatStyle.minimumHitSize)
            .background {
                if isOnboardingReviewAnchorActive, item.status == .pending {
                    Color.clear.onboardingTooltipAnchor(.coCaptainReviewApply)
                }
            }
        }
    }

    /// Tappable candidate choices shown when the edit target matched several
    /// places. Picking one re-stages the edit locally as a normal pending item.
    @ViewBuilder
    private var clarificationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizationManager.shared.localizedString("Which one did you mean?"))
                .font(.system(size: 13, weight: .semibold))

            ForEach(item.clarificationCandidates ?? []) { candidate in
                Button {
                    onPickCandidate?(candidate.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.blue)
                        Text(candidate.label)
                            .font(.system(size: 13, weight: .medium))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.blue.opacity(0.22), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Prefer the focused before-window; fall back to a truncated baseText for legacy items.
    private var focusedBeforeText: String? {
        if let beforePreview = item.beforePreview?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !beforePreview.isEmpty {
            return beforePreview
        }
        guard case .nodeEdit(_, _, _, let baseText) = item.source else { return nil }
        let trimmed = baseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return CoCaptainReviewDiffSnippetter.makeSnippets(
            before: baseText,
            after: item.preview
        ).before
    }

    @ViewBuilder
    private func reviewTextBlock(
        title: String?,
        text: String,
        accent: Color? = nil,
        linePrefix: String? = nil
    ) -> some View {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent ?? .secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(lines.indices, id: \.self) { index in
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            if let accent, let linePrefix {
                                Text(linePrefix)
                                    .foregroundStyle(accent)
                                    .fontWeight(.bold)
                                    .accessibilityHidden(true)
                            }
                            Text(lines[index].isEmpty ? " " : lines[index])
                                .textSelection(.enabled)
                        }
                        .font(.caption.monospaced())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((accent ?? Color.primary).opacity(accent == nil ? 0.04 : 0.07))
                    }
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((accent ?? Color.primary).opacity(accent == nil ? 0.04 : 0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke((accent ?? .clear).opacity(0.25), lineWidth: accent == nil ? 0 : 1)
            )
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
        case .needsClarification: return .blue
        }
    }
}
