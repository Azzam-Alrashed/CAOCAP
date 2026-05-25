import SwiftUI

struct TimelineItemView: View {
    let item: CoCaptainTimelineItem
    let viewModel: CoCaptainViewModel

    var body: some View {
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
            ReviewBundleView(bundle: bundle, viewModel: viewModel, bundleID: item.id)
        }
    }
}

extension CoCaptainTimelineItem {
    var isEmptyAssistantMessage: Bool {
        guard case .message(let bubble) = content,
              !bubble.isUser else {
            return false
        }

        return bubble.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

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

struct ProductCTAView: View {
    let item: CoCaptainProductCTAItem
    let onPrimaryAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image("cocaptain")
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.blue.opacity(0.3), lineWidth: 1))
                .shadow(color: .blue.opacity(0.35), radius: 6)

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
