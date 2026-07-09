import SwiftUI

/// A polymorphic wrapper that routes a generic timeline item to its specific
/// SwiftUI representation (chat bubble, execution summary, CTA, or review bundle).
struct TimelineItemView: View {
    let item: CoCaptainTimelineItem
    let viewModel: CoCaptainViewModel
    @Environment(OnboardingCoordinator.self) private var onboarding: OnboardingCoordinator?

    private var isOnboardingReviewAnchorActive: Bool {
        guard let onboarding else { return false }
        return onboarding.showPopover && onboarding.currentStep == .reviewCoCaptainChange
    }

    private var isOnboardingApplyAnchorActive: Bool {
        guard let onboarding else { return false }
        return onboarding.showPopover && onboarding.currentStep == .applyCoCaptainChange
    }

    var body: some View {
        Group {
            switch item.content {
            case .message(let bubble):
                ChatBubbleView(message: bubble)
            case .execution(let status):
                ExecutionSummaryView(status: status)
            case .productCTA(let cta):
                ProductCTAView(item: cta) {
                    viewModel.performProductCTA(cta)
                }
            case .reviewBundle(let bundle):
                ReviewBundleView(
                    bundle: bundle,
                    viewModel: viewModel,
                    bundleID: item.id,
                    isOnboardingReviewAnchorActive: isOnboardingReviewAnchorActive,
                    isOnboardingApplyAnchorActive: isOnboardingApplyAnchorActive
                )
            case .clarifyingQuestion(let questionItem):
                ClarifyingQuestionCardView(item: questionItem) { option in
                    viewModel.answerClarifyingQuestion(itemID: item.id, option: option)
                }
            case .mentorNote(let noteItem):
                MentorNoteCardView(item: noteItem)
            }
        }
    }
}

extension CoCaptainTimelineItem {
    /// True if this item is an assistant chat message that hasn't received any text yet.
    var isEmptyAssistantMessage: Bool {
        guard case .message(let bubble) = content,
              !bubble.isUser else {
            return false
        }

        return bubble.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// A small pill indicating the current project and node context implicitly passed to the LLM.
struct ContextPill: View {
    let projectName: String
    let fileName: String
    let nodeCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
            Text("Using current canvas")
            Text(verbatim: "·")
            Text(LocalizationManager.shared.localizedProjectName(projectName, fileName: fileName))
            Text(verbatim: "·")
            Text(
                LocalizationManager.shared.localizedString(
                    "context.nodeCount",
                    arguments: [Int64(nodeCount)]
                )
            )
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04))
        .clipShape(Capsule())
    }
}

/// A discreet success indicator shown when the agent executes an app action without requiring review.
struct ExecutionSummaryView: View {
    let status: ExecutionStatusItem

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(status.summary)
                .font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// A "What you just learned" card revealed after the user applies a node edit.
/// Turns the apply moment into a small lesson about the user's own app.
struct MentorNoteCardView: View {
    let item: CoCaptainMentorNoteItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.yellow)
                .frame(width: 28, height: 28)
                .background(Color.yellow.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizationManager.shared.localizedString("cocaptain.mentorNote.title"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(item.note.concept)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)

                Text(item.note.body)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .transition(.asymmetric(insertion: .push(from: .bottom).combined(with: .opacity), removal: .opacity))
    }
}

/// A stylized banner emitted by the assistant to prompt the user to upgrade or subscribe.
struct ProductCTAView: View {
    let item: CoCaptainProductCTAItem
    let onPrimaryAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CopilotAvatarView(size: 32)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.blue)
                        .frame(width: 28, height: 28)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)

                        Text(item.message)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack {
                    Button {
                        onPrimaryAction()
                    } label: {
                        Text(item.primaryButtonTitle)
                            .font(.system(size: 13, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    Spacer(minLength: 0)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.blue.opacity(0.22), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: 420, alignment: .leading)

            Spacer(minLength: 0)
        }
        .transition(.asymmetric(insertion: .push(from: .bottom).combined(with: .opacity), removal: .opacity))
    }
}
