import SwiftUI

struct GemmaModelSettingsSection: View {
    @Binding var modelName: String
    @Bindable var localModelManager: LocalGemmaModelManager

    let eligibility: LocalModelDeviceEligibility

    private var modelOptions: [String] {
        eligibility.isSupported
            ? ["Gemini 3 Flash (Cloud)", "Gemma 4 (On Device)"]
            : ["Gemini 3 Flash (Cloud)"]
    }

    private var modelSelection: Binding<String> {
        Binding(
            get: {
                if modelName == CoCaptainModelSelectionPolicy.localModelName,
                   eligibility.isSupported {
                    return "Gemma 4 (On Device)"
                }
                return "Gemini 3 Flash (Cloud)"
            },
            set: { selection in
                if selection == "Gemma 4 (On Device)", eligibility.isSupported {
                    modelName = CoCaptainModelSelectionPolicy.localModelName
                    if localModelManager.isLocalModelCached {
                        localModelManager.preloadLocalModelIfNeeded()
                    }
                } else {
                    modelName = CoCaptainModelSelectionPolicy.cloudModelName
                }
            }
        )
    }

    var body: some View {
        SettingsSection("CoCaptain AI") {
            SettingsPickerRow(
                icon: "cpu",
                title: "Active Model",
                selection: modelSelection,
                options: modelOptions,
                color: .orange
            )

            if !eligibility.isSupported {
                Divider().padding(.leading, 56).opacity(0.3)
                unsupportedDeviceMessage
            }

            if modelName == CoCaptainModelSelectionPolicy.localModelName {
                localModelControls
            }
        }
    }

    private var unsupportedDeviceMessage: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                "On-Device Gemma Requires a Supported Device",
                systemImage: "ipad.and.iphone.slash"
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)

            Text("Gemma 4 requires an iPhone 15 Pro or newer iPhone, or an iPad with an M-series chip.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var localModelControls: some View {
        Divider().padding(.leading, 56).opacity(0.3)

        VStack(alignment: .leading, spacing: 6) {
            Text("Gemma 4 runs privately on this device after a one-time download.")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            Text("The model uses approximately 2.6 GB of storage.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)

        Divider().padding(.leading, 56).opacity(0.3)

        HStack {
            Label("Local Cache Size", systemImage: "internaldrive")
                .font(.system(size: 16, weight: .medium))
            Spacer()
            Text(localModelManager.localModelCacheSizeFormatted)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)

        if localModelManager.isDownloadingLocalModel {
            downloadProgress
        } else {
            idleControls
        }
    }

    private var downloadProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.leading, 40).opacity(0.3)
            HStack {
                Text("Downloading Gemma 4...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(localModelManager.localModelDownloadProgress * 100))%")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: localModelManager.localModelDownloadProgress)
                .tint(.orange)
            Button("Cancel Download", role: .cancel) {
                localModelManager.cancelDownload()
            }
            .font(.system(size: 14, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var idleControls: some View {
        if let error = localModelManager.localModelError {
            Divider().padding(.leading, 56).opacity(0.3)
            VStack(alignment: .leading, spacing: 6) {
                Label("Download Error", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }

        Divider().padding(.leading, 56).opacity(0.3)

        if localModelManager.isLocalModelCached {
            Label("Local Model Ready", systemImage: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            Divider().padding(.leading, 56).opacity(0.3)

            Button(role: .destructive) {
                localModelManager.clearLocalModelCache()
            } label: {
                Label("Delete Gemma 4", systemImage: "trash.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        } else {
            Button {
                localModelManager.downloadLocalModel()
            } label: {
                Label(
                    localModelManager.localModelError == nil
                        ? "Download Gemma 4"
                        : "Retry Download",
                    systemImage: localModelManager.localModelError == nil
                        ? "arrow.down.circle"
                        : "arrow.clockwise"
                )
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.orange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}
