import SwiftUI

/// Full-screen code editor presented as a sheet from a Mini-App node detail view.
/// It mimics a VS Code tab strip: a dark header bar shows the file name (derived
/// from the node title) and a long-press on the tab reveals a theme picker.
/// Changes are saved back to the store — and persisted — when the user taps the
/// close button.
struct CodeEditorView: View {
    /// The canvas node whose code is being edited.
    let node: SpatialNode
    /// The project store used to persist code and theme changes.
    let store: ProjectStore
    @Environment(\.dismiss) var dismiss
    /// Local draft of the code. Initialised from the node's current code text so
    /// the user can discard changes simply by swiping the sheet away (no save
    /// happens until the close button is tapped).
    @State private var text: String
    
    init(node: SpatialNode, store: ProjectStore) {
        self.node = node
        self.store = store
        // Seed the local draft; falls back to an empty string for brand-new nodes.
        self._text = State(initialValue: node.miniApp?.codeText ?? "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Top Bar (VS Code Tab Style)
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "curlybraces")
                        .foregroundColor(.blue)
                        .font(.system(size: 14, weight: .semibold))
                    Text(fileName(for: node.title))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(red: 0.12, green: 0.12, blue: 0.12)) // Dark active tab color
                
                Spacer()
                
                Button(action: {
                    store.updateMiniAppCode(id: node.id, text: text, persist: true)
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .padding(.trailing, 16)
            }
            .frame(height: 48)
            .background(Color(red: 0.15, green: 0.15, blue: 0.15)) // Header background
            
            // The Main Editor
            LineNumberedTextView(text: $text)
                .edgesIgnoringSafeArea(.bottom)
        }
        .background(Color(red: 0.12, green: 0.12, blue: 0.12).ignoresSafeArea())
        .environment(\.layoutDirection, .leftToRight)
    }
    
    /// Returns the appropriate file extension for the node's programming language.
    /// Currently all Mini-App nodes use HTML/JS, so this always returns `"html"`.
    /// The switch statement is kept to make future multi-language support easy to add.
    private func fileExtension(for title: String) -> String {
        switch title.lowercased() {
        case "code": return "html"
        default: return "html"
        }
    }

    /// Builds the display file name shown in the tab bar, e.g. `"myapp.html"`.
    private func fileName(for title: String) -> String {
        "\(title.lowercased()).\(fileExtension(for: title))"
    }
}
