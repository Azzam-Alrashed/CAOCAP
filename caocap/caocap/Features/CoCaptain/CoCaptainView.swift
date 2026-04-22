import SwiftUI

struct CoCaptainView: View {
    var viewModel: CoCaptainViewModel
    @State private var text: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat History
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message)
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                // Input Area
                HStack(spacing: 12) {
                    TextField("Ask anything...", text: $text)
                        .padding(12)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(12)
                    
                    Button(action: {
                        if !text.isEmpty {
                            viewModel.sendMessage(text)
                            text = ""
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color.primary.opacity(0.02))
            }
            .navigationTitle("Co-Captain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.setPresented(false)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            Text(message.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(message.isUser ? Color.blue : Color.primary.opacity(0.1))
                )
                .foregroundColor(message.isUser ? .white : .primary)
                .font(.system(size: 16))
            
            if !message.isUser { Spacer() }
        }
    }
}

#Preview {
    CoCaptainView(viewModel: CoCaptainViewModel())
}
