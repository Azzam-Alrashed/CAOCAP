import SwiftUI

struct OnboardingOverlay: View {
    let step: OnboardingStep
    
    var body: some View {
        VStack {
            Spacer()
            
            if step != .completed {
                HStack(spacing: 16) {
                    Image(systemName: step.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Onboarding")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        Text(step.instruction)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                }
                .padding(20)
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100) // Keep it above the bottom bar
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: step)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingOverlay(step: .panning)
    }
}
