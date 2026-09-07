import AppKit
import SwiftUI

struct AgentChatView: View {
    @Bindable var controller: CompanionController

    var body: some View {
        AgentConversationView(
            session: controller.chatSession,
            persona: controller.persona,
            isPresented: controller.isChatPresented,
            close: controller.closeChat,
            openHub: controller.openMainWindow
        )
        .id(controller.persona)
    }
}

private struct AgentConversationView: View {
    @Bindable var session: AgentChatSession
    let persona: CompanionPersona
    let isPresented: Bool
    let close: () -> Void
    let openHub: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var composerFocused: Bool

    private var accent: Color {
        persona == .cocaptain
            ? Color(red: 0.12, green: 0.53, blue: 0.76)
            : Color(red: 0.57, green: 0.39, blue: 0.81)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            conversation
            composer
        }
        .background {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                Color(nsColor: .windowBackgroundColor).opacity(0.88)
                    .background(.regularMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .tint(accent)
        .onChange(of: isPresented, initial: true) { _, presented in
            composerFocused = presented
        }
        .onExitCommand(perform: close)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(persona.idleImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .padding(3)
                .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(persona.displayName)
                    .font(.system(size: 14, weight: .semibold))
                Text("Your desktop agent")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            headerButton("square.grid.2x2", label: "Open CAOCAP", action: openHub)
            headerButton("xmark", label: "Close chat", action: close)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func headerButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if session.prompts.isEmpty {
                    welcome
                } else {
                    LazyVStack(alignment: .trailing, spacing: 20) {
                        ForEach(session.prompts) { prompt in
                            VStack(alignment: .trailing, spacing: 5) {
                                Text(prompt.text)
                                    .font(.system(size: 13))
                                    .lineSpacing(4)
                                    .textSelection(.enabled)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 11)
                                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 17))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text("Not sent")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .padding(.trailing, 4)
                            }
                            .padding(.leading, 32)
                            .id(prompt.id)
                        }
                        Text("Your prompts stay here for this session. Agent replies and computer use aren't connected yet.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("conversation-bottom")
                    }
                    .padding(20)
                }
            }
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .onChange(of: session.prompts.count) { _, _ in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    proxy.scrollTo("conversation-bottom", anchor: .bottom)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            Image(persona.idleImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .padding(12)
                .background {
                    Circle().fill(accent.opacity(0.07))
                }
                .accessibilityHidden(true)
                .padding(.bottom, 16)
            Text("What are we\nworking on?")
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Text("Start with a task or an idea.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            HStack(spacing: 8) {
                suggestion("Organize files", symbol: "folder", prompt: "Help me organize the files in a folder.")
                suggestion("Research a topic", symbol: "sparkle.magnifyingglass", prompt: "Help me research a topic and summarize what you find.")
            }
            .padding(.top, 22)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 25)
    }

    private func suggestion(_ title: String, symbol: String, prompt: String) -> some View {
        Button {
            session.draft = prompt
            composerFocused = true
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.primary.opacity(0.045), in: Capsule())
                .overlay(Capsule().strokeBorder(.primary.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var composer: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Message \(persona.displayName)…", text: $session.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineLimit(1...5)
                    .focused($composerFocused)
                    .onSubmit(submit)
                    .accessibilityLabel("Message \(persona.displayName)")

                HStack {
                    Text("⌥ Return for a new line")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: submit) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(session.canSubmit ? .white : .secondary)
                            .frame(width: 30, height: 30)
                            .background(session.canSubmit ? accent : Color.primary.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!session.canSubmit)
                    .keyboardShortcut(.return, modifiers: .command)
                    .accessibilityLabel("Add prompt to chat")
                    .help("Add prompt to chat (⌘ Return)")
                }
            }
            .padding(13)
            .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(composerFocused ? accent.opacity(0.45) : .primary.opacity(0.12), lineWidth: 1)
            }

            Label("Chat preview · Agent not connected", systemImage: "info.circle")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 15)
        .padding(.top, 8)
    }

    private func submit() {
        session.submitDraft()
        composerFocused = true
    }
}

#Preview {
    AgentChatView(controller: CompanionController())
        .frame(width: 372, height: 510)
}
