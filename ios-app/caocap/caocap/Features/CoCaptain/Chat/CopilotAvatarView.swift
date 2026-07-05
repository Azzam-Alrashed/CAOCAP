import SwiftUI

/// Circular chat avatar for the user's selected co-pilot persona.
struct CopilotAvatarView: View {
    let size: CGFloat
    var persona: CopilotPersona = UserProfileStore().loadSelectedCopilot()

    var body: some View {
        Image(persona.avatarImageName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(hex: persona.accentHex).opacity(0.35), lineWidth: 1))
            .shadow(color: Color(hex: persona.accentHex).opacity(0.35), radius: size * 0.18)
    }
}
