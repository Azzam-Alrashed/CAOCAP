import SwiftUI

struct ContentView: View {
    @State var commandPalette = CommandPaletteViewModel()
    @State var coCaptain = CoCaptainViewModel()
    @State private var router = AppRouter()
    @State private var showingPurchaseSheet = false
    @State private var currentScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            switch router.currentWorkspace {
            case .home:
                // The Home Canvas (Main Navigation Hub)
                InfiniteCanvasView(store: router.homeStore, currentScale: $currentScale, onNodeAction: { action in
                    handleNodeAction(action)
                })
                .id("home_canvas")
            case .onboarding:
                InfiniteCanvasView(store: router.onboardingStore, currentScale: $currentScale, onNodeAction: { action in
                    handleNodeAction(action)
                })
                .id("onboarding_canvas")
            case .project(let fileName):
                InfiniteCanvasView(store: router.activeStore, currentScale: $currentScale, onNodeAction: { action in
                    handleNodeAction(action)
                })
                .id("project_canvas_\(fileName)")
            }
            
            // HUD Overlay
            CanvasHUDView(store: router.activeStore, viewportScale: currentScale)
            
            FloatingCommandButton(onTap: {
                commandPalette.setPresented(true)
            })
            
            CommandPaletteView(viewModel: commandPalette)
        }
        .background(Color.black.ignoresSafeArea())
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
        .sheet(isPresented: $showingPurchaseSheet) {
            PurchaseView()
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color(hex: "050505"))
        }
        .onAppear {
            setupCommandHandlers()
            
            // Sync initial scale
            currentScale = router.activeStore.viewportScale
        }
    }
    
    private func handleNodeAction(_ action: NodeAction) {
        switch action {
        case .navigateHome:
            router.navigate(to: .home, animated: true)
            currentScale = 1.0
        case .retryOnboarding:
            router.navigate(to: .onboarding, animated: true)
            currentScale = 1.0
        case .createNewProject:
            router.createNewProject()
        }
    }
    
    private func setupCommandHandlers() {
        commandPalette.onExecute = { command in
            switch command {
            case .summonCoCaptain:
                coCaptain.store = router.activeStore
                coCaptain.setPresented(true)
            case .newProject:
                router.createNewProject()
            case .goHome:
                router.goHome()
            case .goBack:
                router.goBack()
            case .proSubscription:
                showingPurchaseSheet = true
            default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
}
