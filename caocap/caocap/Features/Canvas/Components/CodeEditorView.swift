import SwiftUI
import UIKit

struct CodeEditorView: View {
    let node: SpatialNode
    let store: ProjectStore
    @Environment(\.dismiss) var dismiss
    @State private var text: String
    
    init(node: SpatialNode, store: ProjectStore) {
        self.node = node
        self.store = store
        self._text = State(initialValue: node.textContent ?? "")
    }
    
    var body: some View {
        NavigationView {
            NativeTextView(text: $text)
                .navigationTitle(node.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            store.updateNodeTextContent(id: node.id, text: text, persist: true)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
    }
}

struct NativeTextView: UIViewRepresentable {
    @Binding var text: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.backgroundColor = .systemBackground
        textView.textColor = .label
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
            context.coordinator.highlight(textView: uiView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: NativeTextView
        
        init(_ parent: NativeTextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            self.parent.text = textView.text
            highlight(textView: textView)
        }
        
        func highlight(textView: UITextView) {
            let textStorage = textView.textStorage
            let text = textStorage.string
            let fullRange = NSRange(location: 0, length: text.utf16.count)
            
            textStorage.beginEditing()
            
            // Reset attributes
            textStorage.setAttributes([
                .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.label
            ], range: fullRange)
            
            // HTML Tags: <...>
            if let regex = try? NSRegularExpression(pattern: "<[^>]+>") {
                let matches = regex.matches(in: text, range: fullRange)
                for match in matches {
                    textStorage.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
                }
            }
            
            // Strings: "..." or '...'
            if let regex = try? NSRegularExpression(pattern: "(\"[^\"]*\")|('[^']*')") {
                let matches = regex.matches(in: text, range: fullRange)
                for match in matches {
                    textStorage.addAttribute(.foregroundColor, value: UIColor.systemRed, range: match.range)
                }
            }
            
            // JS Keywords
            let keywords = ["const", "let", "var", "function", "return", "if", "else", "for", "while", "class", "import", "export", "true", "false", "new", "document", "window"]
            let keywordPattern = "\\b(\(keywords.joined(separator: "|")))\\b"
            if let regex = try? NSRegularExpression(pattern: keywordPattern) {
                let matches = regex.matches(in: text, range: fullRange)
                for match in matches {
                    textStorage.addAttribute(.foregroundColor, value: UIColor.systemPurple, range: match.range)
                }
            }
            
            // CSS properties (e.g. color:, margin:)
            if let regex = try? NSRegularExpression(pattern: "\\b[a-zA-Z-]+:") {
                let matches = regex.matches(in: text, range: fullRange)
                for match in matches {
                    textStorage.addAttribute(.foregroundColor, value: UIColor.systemOrange, range: match.range)
                }
            }
            
            textStorage.endEditing()
        }
    }
}
