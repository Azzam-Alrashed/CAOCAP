import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(OnboardingCoordinator.self) private var onboarding
    
    @AppStorage("app_language") private var selectedLanguage = "English"
    @AppStorage("app_theme") private var selectedTheme = "System"
    @AppStorage("haptics_enabled") private var hapticsEnabled = true
    @AppStorage("haptics_intensity") private var hapticsIntensity = "Medium"
    @AppStorage("grid_opacity") private var gridOpacity: Double = 0.1
    @AppStorage("connection_style") private var connectionStyle = "Dashed"
    @AppStorage("spatial_glow_enabled") private var spatialGlowEnabled = true
    @AppStorage("cocaptain.modelName") private var modelName = "gemini-3-flash-preview"
    @AppStorage("cocaptain.hfToken") private var hfToken = ""

    @State private var llmService = LLMService.shared

    let languages = LocalizationManager.supportedLanguages
    let themes = ["System", "Light", "Dark"]
    let intensities = ["Subtle", "Medium", "Sharp"]
    let styles = ["Solid", "Dashed", "Neon"]
    let modelOptions = ["Gemini 3 Flash (Cloud)", "Gemma 4 (Local)"]

    private var modelSelectionBinding: Binding<String> {
        Binding(
            get: {
                if modelName == "gemma-4-local" {
                    return "Gemma 4 (Local)"
                } else {
                    return "Gemini 3 Flash (Cloud)"
                }
            },
            set: { newValue in
                if newValue == "Gemma 4 (Local)" {
                    modelName = "gemma-4-local"
                    let hasToken = !hfToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    if llmService.isLocalModelCached || hasToken {
                        llmService.preloadLocalModelIfNeeded()
                    }
                } else {
                    modelName = "gemini-3-flash-preview"
                }
            }
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Background
                Color(uiColor: .systemBackground).ignoresSafeArea()
                
                // Subtle Glow
                if spatialGlowEnabled {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 400, height: 400)
                        .blur(radius: 60)
                        .offset(x: 150, y: -200)
                }
                
                ScrollView {
                    VStack(spacing: 32) {
                        
                        VStack(spacing: 24) {
                            // MARK: - Interface
                            SettingsSection("Interface") {
                                SettingsPickerRow(icon: "paintbrush.fill", title: "Theme", selection: $selectedTheme, options: themes, color: .purple)
                                
                                Divider().padding(.leading, 56).opacity(0.3)
                                
                                SettingsPickerRow(icon: "globe", title: "Language", selection: $selectedLanguage, options: languages, color: .blue)
                            }

                            // MARK: - CoCaptain AI
                            SettingsSection("CoCaptain AI") {
                                SettingsPickerRow(icon: "cpu", title: "Active Model", selection: modelSelectionBinding, options: modelOptions, color: .orange)
                                
                                if modelName == "gemma-4-local" {
                                    Divider().padding(.leading, 56).opacity(0.3)
                                    
                                    HStack {
                                        Label("Hugging Face Token", systemImage: "key.fill")
                                            .font(.system(size: 16, weight: .medium))
                                        Spacer()
                                        SecureField("hf_...", text: $hfToken)
                                            .textFieldStyle(.plain)
                                            .multilineTextAlignment(.trailing)
                                            .font(.system(size: 14, design: .monospaced))
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: 180)
                                            .autocorrectionDisabled()
                                            .textInputAutocapitalization(.never)
                                            .onChange(of: hfToken) { _, newValue in
                                                llmService.updateHFToken(newValue)
                                            }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    
                                    Divider().padding(.leading, 56).opacity(0.3)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Gemma 4 is a gated model. To download it, you must:")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.secondary)
                                        Text("• Accept the license at huggingface.co/google/gemma-4-E2B-it")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                        Text("• Create a Read token at huggingface.co/settings/tokens")
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
                                        Text(llmService.localModelCacheSizeFormatted)
                                            .font(.system(size: 14, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    
                                    if llmService.isDownloadingLocalModel {
                                        Divider().padding(.leading, 56).opacity(0.3)
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text("Downloading local model...")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(.secondary)
                                                Spacer()
                                                Text("\(Int(llmService.localModelDownloadProgress * 100))%")
                                                    .font(.system(size: 14, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                            }
                                            ProgressView(value: llmService.localModelDownloadProgress)
                                                .tint(.orange)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                    } else {
                                        if let error = llmService.localModelError {
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
                                        
                                        if llmService.isLocalModelCached {
                                            HStack {
                                                Label("Local Model Ready", systemImage: "checkmark.circle.fill")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(.green)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 14)
                                            
                                            Divider().padding(.leading, 56).opacity(0.3)
                                            
                                            Button(role: .destructive) {
                                                llmService.clearLocalModelCache()
                                            } label: {
                                                Label("Delete Local Model", systemImage: "trash.fill")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundStyle(.red)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 14)
                                        } else {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Button {
                                                    llmService.downloadLocalModel()
                                                } label: {
                                                    Label(llmService.localModelError != nil ? "Retry Download" : "Download Local Model", 
                                                          systemImage: llmService.localModelError != nil ? "arrow.clockwise" : "arrow.down.circle")
                                                        .font(.system(size: 16, weight: .semibold))
                                                        .foregroundStyle(hfToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.orange)
                                                }
                                                .disabled(hfToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                                
                                                if hfToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                    Label("Access Token is required to download.", systemImage: "info.circle")
                                                        .font(.system(size: 11))
                                                        .foregroundStyle(.orange)
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 14)
                                        }
                                    }
                                }
                            }
                            
                            // MARK: - Canvas & Graphics
                            SettingsSection("Canvas & Graphics") {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Label("Grid Visibility", systemImage: "grid")
                                            .font(.system(size: 16, weight: .medium))
                                        Spacer()
                                        Text("\(Int(gridOpacity * 100))%")
                                            .font(.system(size: 14, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(value: $gridOpacity, in: 0.05...0.4, step: 0.05)
                                        .tint(.orange)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                
                                Divider().padding(.leading, 56).opacity(0.3)
                                
                                SettingsPickerRow(icon: "waveform.path", title: "Connection Style", selection: $connectionStyle, options: styles, color: .orange)
                                
                                Divider().padding(.leading, 56).opacity(0.3)
                                
                                Toggle(isOn: $spatialGlowEnabled) {
                                    Label("Spatial Glow", systemImage: "sun.max.fill")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .tint(.orange)
                            }
                            
                            // MARK: - Haptics
                            SettingsSection("Haptics") {
                                Toggle(isOn: $hapticsEnabled) {
                                    Label("Tactile Feedback", systemImage: "sensor.touch.fill")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .tint(.green)
                                
                                if hapticsEnabled {
                                    Divider().padding(.leading, 56).opacity(0.3)
                                    
                                    SettingsPickerRow(icon: "shredder.fill", title: "Intensity", selection: $hapticsIntensity, options: intensities, color: .green)
                                }
                            }
                            
                            // MARK: - Tutorial
                            SettingsSection("Tutorial") {
                                SettingsRow(
                                    icon: "arrow.clockwise.circle",
                                    title: "Restart Interactive Tutorial",
                                    subtitle: "Reset and start first-run walkthrough",
                                    color: .blue,
                                    action: {
                                        onboarding.reset()
                                        onboarding.startIfNeeded()
                                        dismiss()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // MARK: - Footer
                        VStack(spacing: 8) {
                            Text("ENGINE CONFIGURATION")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text("Real-time synchronization active.")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            
                            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                                Text("Version \(version) (\(build))")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 40)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Settings")
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
            .preferredColorScheme(currentColorScheme)
        }
    }
    
    private var currentColorScheme: ColorScheme? {
        switch selectedTheme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }
}

// MARK: - Helper View
private struct SettingsPickerRow: View {
    let icon: String
    let title: LocalizedStringKey
    @Binding var selection: String
    let options: [String]
    let color: Color
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .medium))
            Spacer()
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(LocalizedStringKey(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    SettingsView()
}
