import SwiftUI

/// Presents global sheets driven by `AppSessionCoordinator` presentation flags.
struct AppSheetsModifier: ViewModifier {
    @Bindable var session: AppSessionCoordinator

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(
                get: { session.coCaptain.isPresented },
                set: { session.coCaptain.setPresented($0) }
            )) {
                CoCaptainView(viewModel: session.coCaptain)
                    .presentationDetents(session.coCaptainAvailableDetents, selection: $session.coCaptainDetent)
                    .presentationDragIndicator(.visible)
                    .presentationBackground {
                        Color.white.opacity(0.4)
                            .background(.ultraThinMaterial)
                    }
                    .presentationBackgroundInteraction(.enabled)
                    .onAppear {
                        session.handleCoCaptainSheetAppeared()
                    }
            }
            .sheet(isPresented: $session.showingSignIn) {
                SignInView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground {
                        Color.black.opacity(0.95)
                            .background(.ultraThinMaterial)
                    }
            }
            .sheet(isPresented: $session.showingPurchaseSheet) {
                PurchaseView()
                    .presentationDragIndicator(.hidden)
                    .presentationBackground(Color(hex: "050505"))
            }
            .sheet(isPresented: $session.showingSettings) {
                SettingsView()
                    .environment(session.onboarding)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $session.showingSnapshotBrowser) {
                SnapshotBrowserView(store: session.router.activeStore)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $session.showExportSheet) {
                if let url = session.exportURL {
                    ActivityView(activityItems: [url])
                        .presentationDetents([.medium, .large])
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("Preparing Export...")
                    }
                    .presentationDetents([.height(200)])
                }
            }
            .sheet(isPresented: $session.showingProfile) {
                ProfileView(onSignIn: {
                    session.showingSignIn = true
                }, onPro: {
                    session.showingPurchaseSheet = true
                })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
    }
}
