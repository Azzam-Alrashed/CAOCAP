import SwiftUI

/// Full-screen editor for a Mini-App node's Software Requirements Specification.
/// Provides a rich-text-style `TextEditor`, a readiness panel that scores section
/// completion in real time, and a structure button that injects scaffold headings.
struct SRSEditorView: View {
    /// The canvas node whose SRS is being edited.
    let node: SpatialNode
    /// The project store used to persist the SRS text when the user taps Done.
    let store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    /// Local draft of the SRS text, seeded from the node's stored SRS and persisted
    /// only when the user explicitly taps Done.
    @State private var text: String

    init(node: SpatialNode, store: ProjectStore) {
        self.node = node
        self.store = store
        // Fall back to empty string for nodes that have never had SRS text.
        self._text = State(initialValue: node.miniApp?.srsText ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Divider()

            readinessPanel

            Divider()

            editor
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            footerBar
        }
    }

    /// Computes a fresh `SRSAnalysis` from the current draft text on every render.
    /// Passing the node's stored readiness state allows the evaluator to account
    /// for hysteresis — preventing oscillation between states while the user types.
    private var analysis: SRSAnalysis {
        SRSAnalysis(text: text, currentState: node.miniApp?.srsReadinessState)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(node.theme.color.opacity(0.14))
                        .frame(width: 32, height: 32)

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(node.theme.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("SRS")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .contextMenu {
                            Section("Aesthetics") {
                                ForEach(NodeTheme.allCases, id: \.self) { theme in
                                    Button {
                                        store.updateNodeTheme(id: node.id, theme: theme)
                                    } label: {
                                        Label(theme.rawValue.capitalized, systemImage: "circle.fill")
                                            .foregroundColor(theme.color)
                                    }
                                }
                            }
                        }

                    Text(analysis.readinessState.displayTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 20)

            Spacer(minLength: 8)

            Button(action: applyStructure) {
                Image(systemName: "checklist")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(node.theme.color)
                    .frame(width: 34, height: 34)
                    .background(node.theme.color.opacity(0.12))
                    .clipShape(Capsule())
            }
            .accessibilityLabel("Structure requirements")
            .help("Structure requirements")

            Button(action: saveAndDismiss) {
                Text("Done")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(node.theme.color)
                    .clipShape(Capsule())
            }
            .padding(.trailing, 20)
        }
        .frame(height: 64)
        .background(Color(uiColor: .systemBackground))
    }

    private var readinessPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Label(analysis.readinessState.displayTitle, systemImage: analysis.readinessState.icon)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(analysis.readinessState == .stale ? .orange : .primary)

                Spacer()

                Text("\(analysis.completedSections)/\(analysis.totalSections)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(node.theme.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(node.theme.color.opacity(0.12))
                    .clipShape(Capsule())
            }

            ProgressView(value: analysis.completionRatio)
                .tint(node.theme.color)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SRSScaffoldSection.allCases, id: \.self) { section in
                        SRSSectionChip(
                            title: section.title,
                            icon: section.icon,
                            isComplete: analysis.completedSectionsSet.contains(section),
                            tint: node.theme.color
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.65))
        .dismissKeyboardOnTap()
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .lineSpacing(8)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .systemBackground))

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Name the intent. Define who it serves. State how success will be judged.")
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundColor(.secondary.opacity(0.72))
                    .lineSpacing(8)
                    .padding(.horizontal, 28)
                    .padding(.top, 28)
                    .allowsHitTesting(false)
            }
        }
    }

    private var footerBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 10) {
                SRSMetricPill(
                    icon: "text.word.spacing",
                    value: "\(analysis.wordCount)",
                    label: "Words",
                    tint: node.theme.color
                )

                SRSMetricPill(
                    icon: "checkmark.seal.fill",
                    value: "\(analysis.completedSections)",
                    label: "Sections",
                    tint: node.theme.color
                )

                Spacer(minLength: 8)

                Text(analysis.readinessState.nextAction)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemBackground))
        }
    }

    /// Populates the editor with a structured scaffold derived from the current text.
    /// Existing content is preserved where it already matches a section heading;
    /// missing sections are appended with placeholder prompts.
    private func applyStructure() {
        text = SRSScaffold.structuredText(from: text)
    }

    /// Persists the current draft text to the store and dismisses the sheet.
    private func saveAndDismiss() {
        store.updateMiniAppSRS(id: node.id, text: text, persist: true)
        dismiss()
    }
}

/// Computes readiness metrics from a raw SRS text string. Intended to be
/// recalculated on every render from the current draft text so the readiness
/// panel always reflects what is on screen without requiring a separate observable.
private struct SRSAnalysis {
    /// Total number of whitespace-separated tokens in the text.
    let wordCount: Int
    /// The set of scaffold sections whose headings were detected in the text.
    let completedSectionsSet: Set<SRSScaffoldSection>
    /// Sections that are present in the scaffold definition but absent from the text.
    let missingSections: [SRSScaffoldSection]
    /// The current readiness level, incorporating hysteresis from the previous state.
    let readinessState: SRSReadinessState

    init(text: String, currentState: SRSReadinessState? = nil) {
        self.wordCount = text.split(whereSeparator: \.isWhitespace).count
        self.missingSections = SRSScaffold.missingSections(in: text)
        self.completedSectionsSet = Set(SRSScaffoldSection.allCases).subtracting(missingSections)
        self.readinessState = SRSReadinessEvaluator().evaluate(text: text, currentState: currentState)
    }

    /// The count of scaffold sections whose headings are present in the draft.
    var completedSections: Int {
        completedSectionsSet.count
    }

    /// The total number of sections in the canonical SRS scaffold.
    var totalSections: Int {
        SRSScaffoldSection.allCases.count
    }

    /// A value in `[0, 1]` representing what fraction of sections are complete.
    var completionRatio: Double {
        guard totalSections > 0 else { return 0 }
        return Double(completedSections) / Double(totalSections)
    }
}

/// A pill-shaped chip displaying a single SRS scaffold section's completion status.
/// Filled with the node's theme tint when the section is complete, muted otherwise.
private struct SRSSectionChip: View {
    let title: String
    let icon: String
    let isComplete: Bool
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isComplete ? tint : .secondary)

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(isComplete ? .primary : .secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background((isComplete ? tint.opacity(0.12) : Color.secondary.opacity(0.08)))
        .clipShape(Capsule())
    }
}

/// A small pill-shaped metric badge used in the footer bar to show a numeric
/// value (word count or completed section count) with a label and SF Symbol icon.
private struct SRSMetricPill: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .monospacedDigit()

            Text(label)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }
}
