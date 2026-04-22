import SwiftUI

struct CoCaptainView: View {
    var viewModel: CoCaptainViewModel
    @State private var text: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat History
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages) { _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Input Area
                VStack(spacing: 0) {
                    Divider().opacity(0.5)
                    HStack(spacing: 12) {
                        TextField("Ask anything...", text: $text)
                            .padding(14)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(16)
                        
                        Button(action: {
                            if !text.isEmpty {
                                viewModel.sendMessage(text)
                                text = ""
                            }
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.blue)
                                .shadow(color: .blue.opacity(0.3), radius: 4, y: 2)
                        }
                    }
                    .padding()
                    .background(Color.primary.opacity(0.02))
                }
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
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer() }
            else {
                // AI Avatar Icon
                Image("cocaptain")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    .shadow(color: .blue.opacity(0.5), radius: 4, x: 0, y: 0)
            }
            
            Text(message.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if message.isUser {
                            MessageBubbleShape(isUser: true)
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        } else {
                            MessageBubbleShape(isUser: false)
                                .fill(Color.primary.opacity(0.08))
                        }
                    }
                )
                .foregroundColor(message.isUser ? .white : .primary)
                .font(.system(size: 15, weight: .regular))
                .shadow(color: message.isUser ? .blue.opacity(0.2) : .clear, radius: 5, y: 2)
            
            if !message.isUser { Spacer() }
        }
    }
}

struct MessageBubbleShape: Shape {
    var isUser: Bool
    var radius: CGFloat = 18
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Define corners: pointy tail at bottom-right for User, bottom-left for AI
        let tl = radius
        let tr = radius
        let bl = isUser ? radius : 4
        let br = isUser ? 4 : radius
        
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        
        return path
    }
}

#Preview {
    CoCaptainView(viewModel: CoCaptainViewModel())
}
