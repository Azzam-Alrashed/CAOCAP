import SwiftUI
import Popovers

/// Spotlight-style command surface. Rendering stays here while filtering,
/// selection, and execution callbacks live in `CommandPaletteViewModel`.
struct CommandPaletteView: View {
    @Bindable var viewModel: CommandPaletteViewModel
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    @Environment(OnboardingCoordinator.self) private var onboarding: OnboardingCoordinator?
    @State private var isBreathing: Bool = false
    @State private var showRowPopoverDelay: Bool = false
    @State private var isCoCaptainRowVisible: Bool = false
    
    private var isShowPopoverActive: Bool {
        guard let onboarding else { return false }
        return onboarding.currentStep == .searchBarCoCaptain && onboarding.showPopover
    }
    
    private var isSearchBarOnboardingActive: Bool {
        isShowPopoverActive && !isCoCaptainRowVisible
    }
    
    private var isCoCaptainRowOnboardingActive: Bool {
        isShowPopoverActive && isCoCaptainRowVisible
    }
    
    struct ActionCategorySection {
        let category: AppActionCategory
        let title: String
        let items: [(index: Int, action: AppActionDefinition)]
    }

    var sections: [ActionCategorySection] {
        let actions = viewModel.filteredActions
        let categories: [(AppActionCategory, String)] = [
            (.navigation, "NAVIGATION"),
            (.project, "PROJECT"),
            (.assistant, "ASSISTANT")
        ]
        return categories.compactMap { cat, name in
            let filtered = actions.enumerated().filter { $0.element.category == cat }
            guard !filtered.isEmpty else { return nil }
            return ActionCategorySection(
                category: cat,
                title: name,
                items: filtered.map { ($0.offset, $0.element) }
            )
        }
    }

    var body: some View {
        ZStack {
            if viewModel.isPresented {
                // Backdrop
                Color.black.opacity(viewModel.mode == .actionsList ? 0.4 : 0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.setPresented(false)
                    }
                    .transition(.opacity)
                
                if viewModel.mode == .actionsList {
                    // --- MODE 2: Original Spotlight Modal (Actions List) ---
                    VStack(spacing: 0) {
                        // Search Bar
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 20))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            TextField("Ask CoCaptain or type a command...", text: $viewModel.query)
                                .textFieldStyle(.plain)
                                .focused($isFocused)
                                .font(.system(size: 18, weight: .medium))
                                .submitLabel(.done)
                                .onSubmit {
                                    viewModel.confirmSelection()
                                }
                                .onKeyPress { press in
                                    if press.key == .upArrow {
                                        viewModel.moveSelection(direction: .up)
                                        return .handled
                                    } else if press.key == .downArrow {
                                        viewModel.moveSelection(direction: .down)
                                        return .handled
                                    }
                                    return .ignored
                                }
                        }
                        .padding(16)
                        .scaleEffect(isSearchBarOnboardingActive ? (isBreathing ? 1.04 : 1.0) : 1.0)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                                .shadow(
                                    color: isSearchBarOnboardingActive ? Color(hex: "0066FF").opacity(isBreathing ? 0.8 : 0.4) : Color.clear,
                                    radius: isSearchBarOnboardingActive ? (isBreathing ? 24 : 10) : 0,
                                    x: 0,
                                    y: isSearchBarOnboardingActive ? (isBreathing ? 4 : 5) : 0
                                )
                        )
                        .popover(
                            present: Binding(
                                get: { isSearchBarOnboardingActive },
                                set: { newValue in
                                    if !newValue {
                                        if !isCoCaptainRowVisible && onboarding?.currentStep == .searchBarCoCaptain {
                                            onboarding?.showPopover = false
                                        }
                                    } else {
                                        onboarding?.showPopover = true
                                    }
                                }
                            ),
                            attributes: { attributes in
                                attributes.position = .absolute(
                                    originAnchor: .bottom,
                                    popoverAnchor: .top
                                )
                                attributes.dismissal.mode = .none
                                attributes.rubberBandingMode = .none
                                attributes.blocksBackgroundTouches = false
                                attributes.presentation.animation = .spring(response: 0.4, dampingFraction: 0.8)
                                attributes.presentation.transition = .asymmetric(
                                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                                    removal: .scale(scale: 0.9).combined(with: .opacity)
                                )
                                attributes.dismissal.animation = .spring(response: 0.3, dampingFraction: 0.8)
                                attributes.dismissal.transition = .asymmetric(
                                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                                    removal: .scale(scale: 0.9).combined(with: .opacity)
                                )
                                attributes.sourceFrameInset = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
                            }
                        ) {
                            if let step = onboarding?.currentStep {
                                OnboardingPopoverCard(step: step, arrowPlacement: .top) {
                                    onboarding?.skip()
                                }
                            } else {
                                EmptyView()
                            }
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 4) {
                                    if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        ForEach(sections, id: \.category) { section in
                                            Section(header:
                                                HStack {
                                                    Text(section.title)
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(.blue.opacity(0.8))
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.top, 12)
                                                .padding(.bottom, 4)
                                            ) {
                                                ForEach(section.items, id: \.action.id) { index, action in
                                                    AppActionRow(
                                                        item: action,
                                                        isSelected: index == viewModel.selectedIndex
                                                    ) {
                                                        viewModel.executeAction(action)
                                                    }
                                                    .id(action.id.rawValue)
                                                }
                                            }
                                        }
                                    } else {
                                        ForEach(Array(viewModel.filteredActions.enumerated()), id: \.element.id) { index, action in
                                            AppActionRow(
                                                item: action,
                                                isSelected: index == viewModel.selectedIndex
                                            ) {
                                                viewModel.executeAction(action)
                                            }
                                            .id(action.id.rawValue)
                                        }
                                    }

                                    if !viewModel.nodeResults.isEmpty {
                                        HStack {
                                            Text("CANVAS NODES")
                                                .font(.system(size: 10, weight: .bold))
                                                .opacity(0.4)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.top, 12)
                                        .padding(.bottom, 4)

                                        let actionCount = viewModel.filteredActions.count
                                        ForEach(Array(viewModel.nodeResults.enumerated()), id: \.element.id) { index, nodeResult in
                                            NodeSearchResultRow(
                                                result: nodeResult,
                                                isSelected: (index + actionCount) == viewModel.selectedIndex
                                            ) {
                                                viewModel.flyToNode(nodeResult)
                                            }
                                            .id(nodeResult.id.uuidString)
                                        }
                                    }

                                    if viewModel.canSubmitPrompt {
                                        let offset = viewModel.filteredActions.count + viewModel.nodeResults.count
                                        CoCaptainPromptRow(
                                            prompt: viewModel.query,
                                            isSelected: offset == viewModel.selectedIndex,
                                            isGlowActive: isCoCaptainRowOnboardingActive,
                                            isBreathing: isBreathing,
                                            isVisible: $isCoCaptainRowVisible
                                        ) {
                                            viewModel.submitPromptIfNeeded()
                                        }
                                        .id("cocaptain-prompt")
                                        .popover(
                                            present: Binding(
                                                get: { showRowPopoverDelay },
                                                set: { newValue in
                                                    if !newValue {
                                                        if isCoCaptainRowVisible && onboarding?.currentStep == .searchBarCoCaptain {
                                                            onboarding?.showPopover = false
                                                        }
                                                    } else {
                                                        onboarding?.showPopover = true
                                                    }
                                                }
                                            ),
                                            attributes: { attributes in
                                                attributes.position = .absolute(
                                                    originAnchor: .bottom,
                                                    popoverAnchor: .top
                                                )
                                                attributes.dismissal.mode = .none
                                                attributes.rubberBandingMode = .none
                                                attributes.blocksBackgroundTouches = false
                                                attributes.presentation.animation = .spring(response: 0.4, dampingFraction: 0.8)
                                                attributes.presentation.transition = .asymmetric(
                                                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                                                    removal: .scale(scale: 0.9).combined(with: .opacity)
                                                )
                                                attributes.dismissal.animation = .spring(response: 0.3, dampingFraction: 0.8)
                                                attributes.dismissal.transition = .asymmetric(
                                                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                                                    removal: .scale(scale: 0.9).combined(with: .opacity)
                                                )
                                                attributes.sourceFrameInset = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
                                            }
                                        ) {
                                            if let step = onboarding?.currentStep {
                                                OnboardingPopoverCard(step: step, isSubStep2_1: true, arrowPlacement: .top) {
                                                    onboarding?.skip()
                                                }
                                            } else {
                                                EmptyView()
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .frame(maxHeight: 400)
                            .onChange(of: viewModel.selectedIndex) { oldIndex, newIndex in
                                let actions = viewModel.filteredActions
                                let nodeResults = viewModel.nodeResults
                                
                                if newIndex >= 0 && newIndex < actions.count {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        proxy.scrollTo(actions[newIndex].id.rawValue, anchor: .center)
                                    }
                                } else if newIndex >= actions.count && newIndex < (actions.count + nodeResults.count) {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        proxy.scrollTo(nodeResults[newIndex - actions.count].id.uuidString, anchor: .center)
                                    }
                                } else if viewModel.canSubmitPrompt && newIndex == (actions.count + nodeResults.count) {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        proxy.scrollTo("cocaptain-prompt", anchor: .center)
                                    }
                                }
                            }
                        }
                        
                        // Footer hint
                        HStack {
                            Text("Use arrows to navigate, Enter to select")
                                .font(.system(size: 10, weight: .light))
                                .opacity(0.5)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.05))
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.blue.opacity(colorScheme == .dark ? 0.15 : 0.05), radius: 20)
                    )
                    .frame(width: min(500, UIScreen.main.bounds.width - 40))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.25 : 0.4),
                                        Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1),
                                        Color.blue.opacity(colorScheme == .dark ? 0.2 : 0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                    .onAppear {
                        isFocused = true
                    }
                } else {
                    // --- MODE 1: iOS Search Bar Capsule (at Bottom) ---
                    VStack(spacing: 8) {
                        Spacer()
                        
                        // Floating Results Card (Only shown if query is not empty and results exist)
                        let hasResults = !viewModel.filteredActions.isEmpty || !viewModel.nodeResults.isEmpty || viewModel.canSubmitPrompt
                        let showCard = hasResults && !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        
                        if showCard {
                            VStack(spacing: 0) {
                                ScrollViewReader { proxy in
                                    ScrollView {
                                        LazyVStack(spacing: 4) {
                                            ForEach(Array(viewModel.filteredActions.enumerated()), id: \.element.id) { index, action in
                                                AppActionRow(
                                                    item: action,
                                                    isSelected: index == viewModel.selectedIndex
                                                ) {
                                                    viewModel.executeAction(action)
                                                }
                                                .id(action.id.rawValue)
                                            }

                                            if !viewModel.nodeResults.isEmpty {
                                                HStack {
                                                    Text("CANVAS NODES")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .opacity(0.4)
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.top, 12)
                                                .padding(.bottom, 4)

                                                let actionCount = viewModel.filteredActions.count
                                                ForEach(Array(viewModel.nodeResults.enumerated()), id: \.element.id) { index, nodeResult in
                                                    NodeSearchResultRow(
                                                        result: nodeResult,
                                                        isSelected: (index + actionCount) == viewModel.selectedIndex
                                                    ) {
                                                        viewModel.flyToNode(nodeResult)
                                                    }
                                                    .id(nodeResult.id.uuidString)
                                                }
                                            }

                                            if viewModel.canSubmitPrompt {
                                                let offset = viewModel.filteredActions.count + viewModel.nodeResults.count
                                                CoCaptainPromptRow(
                                                    prompt: viewModel.query,
                                                    isSelected: offset == viewModel.selectedIndex,
                                                    isGlowActive: isCoCaptainRowOnboardingActive,
                                                    isBreathing: isBreathing,
                                                    isVisible: $isCoCaptainRowVisible
                                                ) {
                                                    viewModel.submitPromptIfNeeded()
                                                }
                                                .id("cocaptain-prompt")
                                                .popover(
                                                    present: Binding(
                                                        get: { showRowPopoverDelay },
                                                        set: { newValue in
                                                            if !newValue {
                                                                if isCoCaptainRowVisible && onboarding?.currentStep == .searchBarCoCaptain {
                                                                    onboarding?.showPopover = false
                                                                }
                                                            } else {
                                                                onboarding?.showPopover = true
                                                            }
                                                        }
                                                    ),
                                                    attributes: { attributes in
                                                        attributes.position = .absolute(
                                                            originAnchor: .top,
                                                            popoverAnchor: .bottom
                                                        )
                                                        attributes.dismissal.mode = .none
                                                        attributes.rubberBandingMode = .none
                                                        attributes.blocksBackgroundTouches = false
                                                        attributes.presentation.animation = .spring(response: 0.4, dampingFraction: 0.8)
                                                        attributes.presentation.transition = .asymmetric(
                                                            insertion: .scale(scale: 0.85).combined(with: .opacity),
                                                            removal: .scale(scale: 0.9).combined(with: .opacity)
                                                        )
                                                        attributes.dismissal.animation = .spring(response: 0.3, dampingFraction: 0.8)
                                                        attributes.dismissal.transition = .asymmetric(
                                                            insertion: .scale(scale: 0.85).combined(with: .opacity),
                                                            removal: .scale(scale: 0.9).combined(with: .opacity)
                                                        )
                                                        attributes.sourceFrameInset = UIEdgeInsets(top: -8, left: 0, bottom: 0, right: 0)
                                                    }
                                                ) {
                                                    if let step = onboarding?.currentStep {
                                                        OnboardingPopoverCard(step: step, isSubStep2_1: true, arrowPlacement: .bottom) {
                                                            onboarding?.skip()
                                                        }
                                                    } else {
                                                        EmptyView()
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                    .frame(maxHeight: 250)
                                    .onChange(of: viewModel.selectedIndex) { oldIndex, newIndex in
                                        let actions = viewModel.filteredActions
                                        let nodeResults = viewModel.nodeResults
                                        
                                        if newIndex >= 0 && newIndex < actions.count {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                proxy.scrollTo(actions[newIndex].id.rawValue, anchor: .center)
                                            }
                                        } else if newIndex >= actions.count && newIndex < (actions.count + nodeResults.count) {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                proxy.scrollTo(nodeResults[newIndex - actions.count].id.uuidString, anchor: .center)
                                            }
                                        } else if viewModel.canSubmitPrompt && newIndex == (actions.count + nodeResults.count) {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                proxy.scrollTo("cocaptain-prompt", anchor: .center)
                                            }
                                        }
                                    }
                                }
                            }
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(colorScheme == .dark ? 0.2 : 0.35),
                                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 15, y: 5)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            ))
                        }
                        
                        // Search Bar Capsule (styled like iOS native search bar)
                        HStack(spacing: 12) {
                            Image(systemName: "command")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            TextField("Ask CoCaptain or type a command...", text: $viewModel.query)
                                .textFieldStyle(.plain)
                                .focused($isFocused)
                                .font(.system(size: 17))
                                .submitLabel(.done)
                                .onSubmit {
                                    viewModel.confirmSelection()
                                }
                                .onKeyPress { press in
                                    if press.key == .upArrow {
                                        viewModel.moveSelection(direction: .up)
                                        return .handled
                                    } else if press.key == .downArrow {
                                        viewModel.moveSelection(direction: .down)
                                        return .handled
                                    }
                                    return .ignored
                                }
                            
                            if !viewModel.query.isEmpty {
                                Button {
                                    viewModel.query = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(colorScheme == .dark ? 0.2 : 0.35),
                                            Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .scaleEffect(isSearchBarOnboardingActive ? (isBreathing ? 1.04 : 1.0) : 1.0)
                        .shadow(
                            color: isSearchBarOnboardingActive ? Color(hex: "0066FF").opacity(isBreathing ? 0.8 : 0.4) : Color.black.opacity(0.3),
                            radius: isSearchBarOnboardingActive ? (isBreathing ? 24 : 10) : 15,
                            x: 0,
                            y: isSearchBarOnboardingActive ? (isBreathing ? 4 : 5) : 5
                        )
                        .popover(
                            present: Binding(
                                get: { isSearchBarOnboardingActive },
                                set: { newValue in
                                    if !newValue {
                                        if !isCoCaptainRowVisible && onboarding?.currentStep == .searchBarCoCaptain {
                                            onboarding?.showPopover = false
                                        }
                                    } else {
                                        onboarding?.showPopover = true
                                    }
                                }
                            ),
                            attributes: { attributes in
                                attributes.position = .absolute(
                                    originAnchor: .top,
                                    popoverAnchor: .bottom
                                )
                                attributes.dismissal.mode = .none
                                attributes.rubberBandingMode = .none
                                attributes.blocksBackgroundTouches = false
                                attributes.presentation.animation = .spring(response: 0.4, dampingFraction: 0.8)
                                attributes.presentation.transition = .asymmetric(
                                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                                    removal: .scale(scale: 0.9).combined(with: .opacity)
                                )
                                attributes.dismissal.animation = .spring(response: 0.3, dampingFraction: 0.8)
                                attributes.dismissal.transition = .asymmetric(
                                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                                    removal: .scale(scale: 0.9).combined(with: .opacity)
                                )
                                attributes.sourceFrameInset = UIEdgeInsets(top: -8, left: 0, bottom: 0, right: 0)
                            }
                        ) {
                            if let step = onboarding?.currentStep {
                                OnboardingPopoverCard(step: step, arrowPlacement: .bottom) {
                                    onboarding?.skip()
                                }
                            } else {
                                EmptyView()
                            }
                        }
                    }
                    .frame(width: min(500, UIScreen.main.bounds.width - 32))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .onAppear {
                        isFocused = true
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isPresented)
        .onChange(of: viewModel.isPresented) { oldPresented, newPresented in
            if newPresented {
                Task {
                    try? await Task.sleep(for: .seconds(0.1))
                    isFocused = true
                }
            }
        }
        .onAppear {
            if isShowPopoverActive {
                withAnimation(
                    .easeInOut(duration: 1.8)
                        .repeatForever(autoreverses: true)
                ) {
                    isBreathing = true
                }
            }
            if isCoCaptainRowOnboardingActive {
                Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    if isCoCaptainRowOnboardingActive {
                        showRowPopoverDelay = true
                    }
                }
            }
        }
        .onChange(of: isShowPopoverActive) { _, newValue in
            if newValue {
                withAnimation(
                    .easeInOut(duration: 1.8)
                        .repeatForever(autoreverses: true)
                ) {
                    isBreathing = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isBreathing = false
                }
            }
        }
        .onChange(of: isCoCaptainRowOnboardingActive) { _, newValue in
            if newValue {
                Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    if isCoCaptainRowOnboardingActive {
                        showRowPopoverDelay = true
                    }
                }
            } else {
                showRowPopoverDelay = false
            }
        }
    }
}

// MARK: - Row Styling Modifier

struct OmniboxRowModifier: ViewModifier {
    let isSelected: Bool
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    if isSelected {
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.15),
                                Color.blue.opacity(0.08)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else if isHovered {
                        Color.white.opacity(colorScheme == .dark ? 0.05 : 0.03)
                    }
                }
            )
            .scaleEffect(isSelected ? 1.015 : (isHovered ? 1.005 : 1.0))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.blue.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
                    .shadow(color: Color.blue.opacity(0.3), radius: isSelected ? 4 : 0)
            )
            .cornerRadius(8)
            .padding(.horizontal, 8)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isSelected)
    }
}

extension View {
    func omniboxRowStyle(isSelected: Bool) -> some View {
        self.modifier(OmniboxRowModifier(isSelected: isSelected))
    }
}

// MARK: - Row Component Views

struct AppActionRow: View {
    let item: AppActionDefinition
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 16))
                    .frame(width: 24)
                
                Text(item.localizedTitle)
                    .font(.system(size: 16))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "return")
                        .font(.system(size: 12))
                        .opacity(0.8)
                        .foregroundColor(.blue)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .omniboxRowStyle(isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct CoCaptainPromptRow: View {
    let prompt: String
    let isSelected: Bool
    var isGlowActive: Bool = false
    var isBreathing: Bool = false
    var isVisible: Binding<Bool>? = nil
    let onSelect: () -> Void

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .frame(width: 24)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask CoCaptain")
                        .font(.system(size: 16, weight: .medium))

                    Text(trimmedPrompt)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .opacity(0.65)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "return")
                        .font(.system(size: 12))
                        .opacity(0.8)
                        .foregroundColor(.blue)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .omniboxRowStyle(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .scaleEffect(isGlowActive ? (isBreathing ? 1.04 : 1.0) : 1.0)
        .shadow(
            color: isGlowActive ? Color(hex: "0066FF").opacity(isBreathing ? 0.8 : 0.4) : Color.clear,
            radius: isGlowActive ? (isBreathing ? 24 : 10) : 0,
            x: 0,
            y: isGlowActive ? (isBreathing ? 4 : 5) : 0
        )
        .onAppear {
            isVisible?.wrappedValue = true
        }
        .onDisappear {
            isVisible?.wrappedValue = false
        }
    }
}

struct NodeSearchResultRow: View {
    let result: NodeSearchResult
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: result.role.icon)
                    .font(.system(size: 16))
                    .frame(width: 24)
                    .foregroundColor(result.role.themeColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.system(size: 16, weight: .medium))
                    
                    if !result.snippet.isEmpty {
                        Text(result.snippet)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .opacity(0.6)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 12))
                        .opacity(0.8)
                        .foregroundColor(.blue)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .omniboxRowStyle(isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
