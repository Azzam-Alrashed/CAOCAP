import SwiftUI

struct SnapshotBrowserView: View {
    @Bindable var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var customLabel: String = ""
    @State private var snapshotToRestore: SnapshotMetadata? = nil
    @State private var snapshotToDelete: SnapshotMetadata? = nil
    @State private var previewTexts: [UUID: String] = [:]
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Background Glow
                Color(uiColor: .systemBackground).ignoresSafeArea()
                
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 350, height: 350)
                    .blur(radius: 50)
                    .offset(x: -120, y: -150)
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // MARK: - Create Checkpoint Card
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Create Checkpoint")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .kerning(1.2)
                                .padding(.leading, 8)
                            
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: "tag.fill")
                                        .foregroundStyle(.blue)
                                        .font(.system(size: 16, weight: .semibold))
                                    
                                    TextField("Label (e.g. Added Landing Page)", text: $customLabel)
                                        .font(.system(size: 16))
                                }
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                
                                Button(action: createManualCheckpoint) {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "plus.circle.fill")
                                        Text("Save Snapshot")
                                            .font(.system(size: 16, weight: .semibold))
                                        Spacer()
                                    }
                                    .padding(.vertical, 14)
                                    .background(customLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .shadow(color: customLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .clear : .blue.opacity(0.3), radius: 6, y: 3)
                                }
                                .disabled(customLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding(16)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // MARK: - Checkpoints Timeline List
                        VStack(alignment: .leading, spacing: 14) {
                            Text("History Timeline")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .kerning(1.2)
                                .padding(.leading, 8)
                            
                            if store.history.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.secondary.opacity(0.5))
                                    Text("No Checkpoints Found")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text("Checkpoints are automatically created before Co-Captain executes actions, or you can create one manually above.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.tertiary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 40)
                                .padding(.horizontal, 24)
                                .frame(maxWidth: .infinity)
                                .background(Color(uiColor: .tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                )
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(store.history.enumerated()), id: \.element.id) { index, checkpoint in
                                        checkpointRow(checkpoint: checkpoint)
                                        
                                        if index < store.history.count - 1 {
                                            Divider().padding(.leading, 56).opacity(0.3)
                                        }
                                    }
                                }
                                .background(Color(uiColor: .tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle(store.projectName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Checkpoints")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.primary.opacity(0.6))
                            .padding(8)
                            .background(.primary.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            .alert("Restore Snapshot?", isPresented: Binding(
                get: { snapshotToRestore != nil },
                set: { if !$0 { snapshotToRestore = nil } }
            )) {
                Button("Restore", role: .destructive) {
                    if let snapshot = snapshotToRestore {
                        restoreCheckpoint(snapshot)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let snapshot = snapshotToRestore {
                    Text("Are you sure you want to revert your project to '\(snapshot.label)'? This will discard your current unsaved changes.")
                }
            }
            .alert("Delete Checkpoint?", isPresented: Binding(
                get: { snapshotToDelete != nil },
                set: { if !$0 { snapshotToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let snapshot = snapshotToDelete {
                        deleteCheckpoint(snapshot)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let snapshot = snapshotToDelete {
                    Text("Are you sure you want to permanently delete '\(snapshot.label)'? This action cannot be undone.")
                }
            }
        }
    }
    
    @ViewBuilder
    private func checkpointRow(checkpoint: SnapshotMetadata) -> some View {
        HStack(spacing: 16) {
            // MARK: - Timeline Node Line/Bullet
            ZStack {
                Circle()
                    .fill(checkpointColor(for: checkpoint.label).opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Circle()
                    .fill(checkpointColor(for: checkpoint.label))
                    .frame(width: 10, height: 10)
            }
            
            // MARK: - Metadata
            VStack(alignment: .leading, spacing: 3) {
                Text(checkpoint.label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text(dateFormatter.string(from: checkpoint.date))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                if let previewText = previewTexts[checkpoint.id] {
                    Text(previewText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.blue.opacity(0.8))
                        .lineLimit(1)
                        .padding(.top, 2)
                } else {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                        Text("Loading preview...")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // MARK: - Action Buttons
            HStack(spacing: 12) {
                Button {
                    snapshotToRestore = checkpoint
                } label: {
                    Text("Restore")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                Button {
                    snapshotToDelete = checkpoint
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(9)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .task {
            guard previewTexts[checkpoint.id] == nil else { return }
            
            if let snapshot = await store.loadSnapshot(metadata: checkpoint) {
                let count = snapshot.nodes.count
                if count == 0 {
                    previewTexts[checkpoint.id] = "Empty Canvas"
                } else {
                    var typeCounts: [String: Int] = [:]
                    for node in snapshot.nodes {
                        let name = node.type.displayName
                        typeCounts[name, default: 0] += 1
                    }
                    let sortedKeys = typeCounts.keys.sorted()
                    let summary = sortedKeys.map { "\(typeCounts[$0]!) \($0)" }.joined(separator: ", ")
                    previewTexts[checkpoint.id] = "\(count) node\(count == 1 ? "" : "s") (\(summary))"
                }
            } else {
                previewTexts[checkpoint.id] = "Preview unavailable"
            }
        }
    }
    
    private func checkpointColor(for label: String) -> Color {
        if label.contains("Pre-AI") || label.contains("Apply") {
            return .purple
        } else if label.contains("Auto") {
            return .indigo
        } else {
            return .blue
        }
    }
    
    private func createManualCheckpoint() {
        let label = customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }
        
        store.createCheckpoint(label: label)
        customLabel = ""
        
        HapticsManager.shared.notification(.success)
    }
    
    private func restoreCheckpoint(_ checkpoint: SnapshotMetadata) {
        store.restore(from: checkpoint)
        HapticsManager.shared.notification(.success)
        dismiss()
    }
    
    private func deleteCheckpoint(_ checkpoint: SnapshotMetadata) {
        withAnimation(.easeInOut) {
            store.deleteCheckpoint(metadata: checkpoint)
        }
        HapticsManager.shared.notification(.success)
    }
}
