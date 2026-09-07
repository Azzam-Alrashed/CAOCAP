import SwiftUI

struct AgentHubView: View {
    @Bindable var session: AppSessionCoordinator
    @Environment(\.horizontalSizeClass) private var contentSizeClass

    var body: some View {
        TabView(selection: $session.selectedTab) {
            Tab(value: HubTab.explore) {
                NavigationStack {
                    ContentUnavailableView(
                        "Discover your next agent",
                        systemImage: "safari",
                        description: Text("Agent discovery and community joining are coming soon.")
                    )
                    .navigationTitle("Explore")
                    .background(Color(uiColor: .systemGroupedBackground))
                }
                .environment(\.horizontalSizeClass, contentSizeClass)
            } label: {
                Image(systemName: "safari")
            }
            .accessibilityLabel("Explore")
            Tab(value: HubTab.home) {
                NavigationStack {
                    AgentHomeView(session: session)
                        .background(Color(uiColor: .systemGroupedBackground))
                }
                .environment(\.horizontalSizeClass, contentSizeClass)
            } label: {
                Image(systemName: "square.grid.2x2")
            }
            .accessibilityLabel("Home")
            Tab(value: HubTab.communities) {
                NavigationStack {
                    ContentUnavailableView(
                        "Build together",
                        systemImage: "person.2",
                        description: Text("Your communities and shared agent building will live here. Coming soon.")
                    )
                    .navigationTitle("Communities")
                    .background(Color(uiColor: .systemGroupedBackground))
                }
                .environment(\.horizontalSizeClass, contentSizeClass)
            } label: {
                Image(systemName: "person.2")
            }
            .accessibilityLabel("Communities")
        }
        .tabViewStyle(.tabBarOnly)
        // Use the native bottom bar on iPad too; tab contents retain their actual size class.
        .environment(\.horizontalSizeClass, .compact)
        .sheet(isPresented: $session.showingAgentWizard) {
            AgentCreationWizardView()
        }
    }
}

private struct AgentHomeView: View {
    @Bindable var session: AppSessionCoordinator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var lastRemovedAgent: LibraryAgent?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if session.agentLibrary.agents.isEmpty {
                    ContentUnavailableView {
                        Label("Your agents start here", systemImage: "square.grid.2x2")
                    } description: {
                        Text("Create an agent of your own or explore agents built by others.")
                    } actions: {
                        createButton
                        Button("Explore agents") { session.selectedTab = .explore }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("home.explore")
                    }
                    .padding(.top, 32)
                } else {
                    HStack {
                        Text("Your agents")
                            .font(.title2.bold())
                        Spacer()
                    }
                    createButton
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 260 : 150), spacing: 16)], spacing: 16) {
                        ForEach(session.agentLibrary.agents) { agent in
                            agentCard(agent)
                        }
                    }
                }
                if let removed = lastRemovedAgent {
                    HStack {
                        Text("\(removed.name) removed from Home.")
                            .font(.subheadline)
                        Spacer()
                        Button("Undo") {
                            session.agentLibrary.restore(removed)
                            lastRemovedAgent = nil
                        }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(20)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { session.showingProfile = true } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                }
                .accessibilityLabel("Profile")
                .accessibilityIdentifier("home.profile")
            }
        }
    }

    private var createButton: some View {
        Button { session.showingAgentWizard = true } label: {
            Label("Create agent", systemImage: "plus")
                .font(.headline)
                .padding(.vertical, 5)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .accessibilityIdentifier("home.create")
    }

    private func agentCard(_ agent: LibraryAgent) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Menu {
                    Button("Remove from Home", systemImage: "minus.circle", role: .destructive) {
                        session.agentLibrary.remove(agent)
                        lastRemovedAgent = agent
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityLabel("Options for \(agent.name)")
                .accessibilityIdentifier("agent.options.\(agent.id)")
            }
            Button { session.openAgent(agent) } label: {
                VStack(spacing: 16) {
                    CopilotAvatarView(size: 88, persona: agent.persona)
                    Text(agent.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.bottom, 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(agent.name) Workspace")
            .accessibilityIdentifier("agent.open.\(agent.id)")
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.primary.opacity(0.06)))
    }
}

/// Navigation destination only; the wizard's questions and steps have not been designed.
private struct AgentCreationWizardView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Agent setup is coming soon",
                systemImage: "sparkles",
                description: Text("You'll create your agent here with a guided setup.")
            )
            .navigationTitle("Create agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("agent.wizard")
    }
}
