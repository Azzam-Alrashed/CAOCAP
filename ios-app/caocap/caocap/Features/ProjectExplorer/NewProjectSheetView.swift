import SwiftUI

struct NewProjectSheetView: View {
    var onCreate: (String, ProjectTemplate) -> Void
    var onCancel: () -> Void
    
    @State private var projectName = ""
    @State private var selectedTemplate: ProjectTemplate = .helloWorld
    @FocusState private var isNameFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Create New Project")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Choose a starter template to seed your workspace")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 24)
            
            // Name Field
            VStack(alignment: .leading, spacing: 8) {
                Text("PROJECT NAME")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                
                TextField("Untitled Project", text: $projectName)
                    .focused($isNameFocused)
                    .font(.system(size: 16, weight: .medium))
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            
            // Templates Grid
            VStack(alignment: .leading, spacing: 12) {
                Text("SELECT STARTER TEMPLATE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 20)
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(ProjectTemplate.allCases), id: \.id) { template in
                            Button {
                                isNameFocused = false
                                selectedTemplate = template
                                HapticsManager.shared.trigger(.light)
                            } label: {
                                TemplateRowView(template: template, isSelected: selectedTemplate == template)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .interactiveKeyboardDismiss()
            }
            
            // Buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                
                Button("Create") {
                    let name = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
                    onCreate(name.isEmpty ? "Untitled Project" : name, selectedTemplate)
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedTemplate.theme.color)
                .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(
            ZStack {
                Color(hex: "050505").ignoresSafeArea()
                
                // Dynamic ambient glow behind the selected template color
                Circle()
                    .fill(selectedTemplate.theme.color.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: 100, y: -150)
            }
        )
    }
}

private struct TemplateRowView: View {
    let template: ProjectTemplate
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(template.theme.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: template.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(template.theme.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(template.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(template.description)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(template.theme.color)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? template.theme.color.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1.5)
                )
        )
    }
}
