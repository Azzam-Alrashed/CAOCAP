import SwiftUI

struct NodeCreationMenuView: View {
    var onSelect: (NodeType) -> Void
    
    let options: [NodeType] = [.webView, .srs, .code, .firebase, .subCanvas]
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Select Node Type")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Choose a specialized node for your spatial canvas")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    ForEach(options, id: \.self) { type in
                        Button {
                            onSelect(type)
                        } label: {
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [typeColor(for: type).opacity(0.3), typeColor(for: type).opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 54, height: 54)
                                        .overlay(
                                            Circle()
                                                .stroke(typeColor(for: type).opacity(0.5), lineWidth: 1.5)
                                        )
                                    
                                    Image(systemName: typeIcon(for: type))
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(typeColor(for: type))
                                }
                                
                                VStack(spacing: 4) {
                                    Text(type.displayName)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Text(typeDescription(for: type))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.4))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 4)
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.white.opacity(0.05))
                                    .background(
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(.ultraThinMaterial)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(.white.opacity(0.15), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(NodeMenuButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .padding()
        .background(
            ZStack {
                Color(hex: "050505").ignoresSafeArea()
                
                // Subtle ambient glow
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 400, height: 400)
                    .blur(radius: 100)
                    .offset(x: -150, y: -200)
            }
        )
    }

    private func typeDescription(for type: NodeType) -> String {
        switch type {
        case .webView: return "Live preview surface"
        case .srs: return "Requirements document"
        case .code: return "Source code editor"
        case .firebase: return "Web app config for Live Preview"
        case .subCanvas: return "Nested canvas workspace"
        default: return "Standard node"
        }
    }
    
    private func typeIcon(for type: NodeType) -> String {
        switch type {
        case .webView: return "play.display"
        case .srs: return "doc.text.fill"
        case .code: return "chevron.left.slash.chevron.right"
        case .firebase: return "flame.fill"
        case .subCanvas: return "folder.fill"
        default: return "square.grid.2x2"
        }
    }
    
    private func typeColor(for type: NodeType) -> Color {
        switch type {
        case .webView: return .blue
        case .srs: return .purple
        case .code: return .blue
        case .firebase: return .orange
        case .subCanvas: return .cyan
        default: return .secondary
        }
    }
}

struct NodeMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
