import SwiftUI

struct SRSEditorView: View {
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
            TextEditor(text: $text)
                .font(.body)
                .padding()
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
