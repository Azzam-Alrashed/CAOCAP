import SwiftUI

struct ContentView: View {
    @StateObject var commandPalette = CommandPaletteViewModel()
    @StateObject var coCaptain = CoCaptainViewModel()
    @State private var projectStore = ProjectStore()
    @State private var isBlankCanvasActive = false
    @State private var blankProjectStore = ProjectStore() // Temporary empty store for now
    
    var body: some View {
        ZStack {
            if isBlankCanvasActive {
                // The "New Completely New Canvas" (Blank for now)
                InfiniteCanvasView(store: blankProjectStore)
                    .overlay(alignment: .topLeading) {
                        Button(action: {
                            withAnimation(.spring()) {
                                isBlankCanvasActive = false
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Back to Onboarding")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                        }
                        .padding(.top, 60)
                        .padding(.leading, 20)
                    }
            } else {
                InfiniteCanvasView(store: projectStore, onLaunchProject: {
                    withAnimation(.spring()) {
                        isBlankCanvasActive = true
                    }
                })
            }
            
            FloatingCommandButton(onTap: {
                commandPalette.setPresented(true)
            })
            
            CommandPaletteView(viewModel: commandPalette)
        }
        .sheet(isPresented: $coCaptain.isPresented) {
            CoCaptainView(viewModel: coCaptain)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground {
                    Color.white.opacity(0.4)
                        .background(.ultraThinMaterial)
                }
                .presentationBackgroundInteraction(.enabled)
        }
        .onAppear {
            setupCommandHandlers()
            // Ensure blank project is actually blank for this demo
            blankProjectStore.nodes = []
        }
    }
    
    private func setupCommandHandlers() {
        commandPalette.onExecute = { command in
            switch command {
            case .summonCoCaptain:
                coCaptain.setPresented(true)
            default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
}
