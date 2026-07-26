import SwiftUI

/// Searchable, local-first project conversation browser.
struct CoCaptainConversationListView: View {
    @Bindable var viewModel: CoCaptainViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var conversationToDelete: CoCaptainConversation?
    @State private var conversationToRename: CoCaptainConversation?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isConversationArchiveLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(
                            LocalizationManager.shared.localizedString(
                                "Loading conversations"
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredConversations.isEmpty {
                    ContentUnavailableView.search(text: viewModel.conversationSearchQuery)
                } else {
                    List {
                        ForEach(conversationSections) { section in
                            Section {
                                ForEach(section.conversations) { conversation in
                                    conversationRow(conversation)
                                }
                            } header: {
                                Text(
                                    LocalizationManager.shared.localizedString(
                                        section.title
                                    )
                                )
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(LocalizationManager.shared.localizedString("Conversations"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.conversationSearchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: LocalizationManager.shared.localizedString("Search conversations")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationManager.shared.localizedString("Done")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.createConversation()
                        dismiss()
                    } label: {
                        Label(
                            LocalizationManager.shared.localizedString("New conversation"),
                            systemImage: "square.and.pencil"
                        )
                    }
                    .disabled(
                        viewModel.isThinking || viewModel.isConversationArchiveLoading
                    )
                }
            }
        }
        .alert(
            LocalizationManager.shared.localizedString("Rename conversation"),
            isPresented: Binding(
                get: { conversationToRename != nil },
                set: { if !$0 { conversationToRename = nil } }
            )
        ) {
            TextField(
                LocalizationManager.shared.localizedString("Conversation title"),
                text: $renameText
            )
            Button(LocalizationManager.shared.localizedString("Cancel"), role: .cancel) {
                conversationToRename = nil
            }
            Button(LocalizationManager.shared.localizedString("Rename")) {
                guard let conversationToRename else { return }
                viewModel.renameConversation(id: conversationToRename.id, title: renameText)
                self.conversationToRename = nil
            }
        }
        .confirmationDialog(
            LocalizationManager.shared.localizedString("Delete this conversation?"),
            isPresented: Binding(
                get: { conversationToDelete != nil },
                set: { if !$0 { conversationToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(LocalizationManager.shared.localizedString("Delete"), role: .destructive) {
                guard let conversationToDelete else { return }
                viewModel.deleteConversation(id: conversationToDelete.id)
                self.conversationToDelete = nil
            }
            Button(LocalizationManager.shared.localizedString("Cancel"), role: .cancel) {
                conversationToDelete = nil
            }
        } message: {
            Text(
                LocalizationManager.shared.localizedString(
                    "This removes only the chat. Your canvas and snapshots stay safe."
                )
            )
        }
    }

    private func conversationRow(_ conversation: CoCaptainConversation) -> some View {
        Button {
            viewModel.switchConversation(to: conversation.id)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(
                        conversation.id == viewModel.activeConversationID
                            ? Color.accentColor
                            : Color.secondary
                    )
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(conversation.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(conversation.previewText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(conversation.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if conversation.id == viewModel.activeConversationID {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityLabel(
                                LocalizationManager.shared.localizedString("Current conversation")
                            )
                    }
                }
            }
            .contentShape(Rectangle())
            .frame(minHeight: 56)
        }
        .buttonStyle(.plain)
        .listRowBackground(
            conversation.id == viewModel.activeConversationID
                ? Color.accentColor.opacity(0.07)
                : Color.clear
        )
        .disabled(
            viewModel.isConversationArchiveLoading
                || (viewModel.isThinking && conversation.id != viewModel.activeConversationID)
        )
        .contextMenu {
            Button {
                renameText = conversation.title
                conversationToRename = conversation
            } label: {
                Label(
                    LocalizationManager.shared.localizedString("Rename"),
                    systemImage: "pencil"
                )
            }
            .disabled(viewModel.isThinking)

            Button(role: .destructive) {
                conversationToDelete = conversation
            } label: {
                Label(
                    LocalizationManager.shared.localizedString("Delete"),
                    systemImage: "trash"
                )
            }
            .disabled(viewModel.isThinking)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                conversationToDelete = conversation
            } label: {
                Label(
                    LocalizationManager.shared.localizedString("Delete"),
                    systemImage: "trash"
                )
            }
            .disabled(viewModel.isThinking)

            Button {
                renameText = conversation.title
                conversationToRename = conversation
            } label: {
                Label(
                    LocalizationManager.shared.localizedString("Rename"),
                    systemImage: "pencil"
                )
            }
            .tint(.blue)
            .disabled(viewModel.isThinking)
        }
    }

    private var conversationSections: [ConversationSection] {
        let calendar = Calendar.current
        let recentCutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let conversations = viewModel.filteredConversations

        return [
            ConversationSection(
                id: "today",
                title: "Today",
                conversations: conversations.filter {
                    calendar.isDateInToday($0.updatedAt)
                }
            ),
            ConversationSection(
                id: "recent",
                title: "Previous 7 Days",
                conversations: conversations.filter {
                    !calendar.isDateInToday($0.updatedAt) && $0.updatedAt >= recentCutoff
                }
            ),
            ConversationSection(
                id: "older",
                title: "Older",
                conversations: conversations.filter {
                    $0.updatedAt < recentCutoff
                }
            )
        ]
        .filter { !$0.conversations.isEmpty }
    }

    private struct ConversationSection: Identifiable {
        let id: String
        let title: String
        let conversations: [CoCaptainConversation]
    }
}

private extension CoCaptainConversation {
    var previewText: String {
        for item in items {
            guard case .message(let message) = item.content,
                  message.isUser else {
                continue
            }

            let preview = message.text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
            if !preview.isEmpty {
                return preview
            }
            if !message.attachments.isEmpty {
                return LocalizationManager.shared.localizedString("Attachment")
            }
        }

        return LocalizationManager.shared.localizedString("No messages yet")
    }
}
