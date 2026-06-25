import SwiftUI
import Observation
import OSLog

/// UI state for the command palette. It deliberately emits only `AppActionID`
/// values so action execution remains centralized in `AppActionDispatcher`.
@Observable
public class CommandPaletteViewModel {
    public enum CommandPaletteMode {
        case search
        case actionsList
    }
    
    private let logger = Logger(subsystem: "CAOCAP", category: "CommandPalette")
    
    public var query: String = "" {
        didSet {
            // Only reset keyboard selection when the query actually changed,
            // so that pressing Enter (which can re-trigger didSet with the
            // same value) doesn't clobber the arrow-key selection.
            guard query != oldValue else { return }
            selectedIndex = 0
        }
    }
    public var isPresented: Bool = false
    public var selectedIndex: Int = 0
    public var actions: [AppActionDefinition] = []
    public var nodes: [SpatialNode] = []
    public var mode: CommandPaletteMode = .search
    
    /// Filters against localized and canonical titles so command search works
    /// in the UI language while still matching stable English action names.
    public var filteredActions: [AppActionDefinition] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let paletteActions = actions.filter { !Self.hiddenCreationActionIDs.contains($0.id) }
        if trimmedQuery.isEmpty { return paletteActions }
        
        return paletteActions.filter {
            $0.localizedTitle.localizedCaseInsensitiveContains(trimmedQuery) ||
            $0.title.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    public var nodeResults: [NodeSearchResult] {
        searchIndex.search(query: query, in: nodes)
    }

    public var nodeCreationResults: [NodeCreationOption] {
        creationCatalog.search(query: query)
    }

    private static let hiddenCreationActionIDs: Set<AppActionID> = [
        .createNode,
        .createFirebaseNode,
        .createSubCanvas
    ]

    private var nodeResultCount: Int { nodeResults.count }
    private var nodeCreationResultCount: Int { nodeCreationResults.count }
    private var actionResultCount: Int { filteredActions.count }

    private var nodeResultsStartIndex: Int { 0 }
    private var nodeCreationResultsStartIndex: Int { nodeResultCount }
    private var actionsStartIndex: Int { nodeResultCount + nodeCreationResultCount }
    private var promptRowIndex: Int { nodeResultCount + nodeCreationResultCount + actionResultCount }

    public var promptSelectionIndex: Int { promptRowIndex }
    
    public var onExecute: ((AppActionID) -> Void)?
    public var onPinAction: ((AppActionID) -> Void)?
    public var onFlyToNode: ((UUID) -> Void)?
    public var onCreateNode: ((NodeType) -> Void)?
    public var onSubmitPrompt: ((String) -> Void)?
    
    @ObservationIgnored
    private let searchIndex = NodeSearchIndex()

    @ObservationIgnored
    private let creationCatalog = NodeCreationCatalog()

    private var totalResultCount: Int {
        var count = nodeResultCount + nodeCreationResultCount + actionResultCount
        if canSubmitPrompt {
            count += 1
        }
        return count
    }
    
    public init() {}
    
    /// Closes back to a clean state so each palette open starts from the full
    /// command list.
    public func setPresented(_ presented: Bool, mode: CommandPaletteMode = .search) {
        self.mode = mode
        isPresented = presented
        if !presented {
            query = ""
            selectedIndex = 0
        }
    }
    
    public func moveSelection(direction: Direction) {
        let count = totalResultCount
        guard count > 0 else { return }
        
        switch direction {
        case .up:
            selectedIndex = (selectedIndex - 1 + count) % count
        case .down:
            selectedIndex = (selectedIndex + 1) % count
        }
    }

    public func selectPromptRowIfAvailable() {
        guard canSubmitPrompt else { return }
        selectedIndex = promptRowIndex
    }
    
    public func confirmSelection() {
        let nodeResults = nodeResults
        let nodeCreationResults = nodeCreationResults
        let actions = filteredActions
        
        if selectedIndex >= nodeResultsStartIndex && selectedIndex < nodeCreationResultsStartIndex {
            flyToNode(nodeResults[selectedIndex - nodeResultsStartIndex])
        } else if selectedIndex >= nodeCreationResultsStartIndex && selectedIndex < actionsStartIndex {
            createNode(nodeCreationResults[selectedIndex - nodeCreationResultsStartIndex])
        } else if selectedIndex >= actionsStartIndex && selectedIndex < promptRowIndex {
            executeAction(actions[selectedIndex - actionsStartIndex])
        } else if canSubmitPrompt && selectedIndex == promptRowIndex {
            submitPromptIfNeeded()
        }
    }
    
    /// Emits the chosen action ID and dismisses. The view model does not perform
    /// side effects directly because the same action system is shared with agents.
    public func executeAction(_ action: AppActionDefinition) {
        logger.info("Executing action: \(action.title)")
        onExecute?(action.id)
        setPresented(false)
    }

    public func pinAction(_ action: AppActionDefinition) {
        logger.info("Pinning action to canvas: \(action.title)")
        onPinAction?(action.id)
        setPresented(false)
    }

    public func flyToNode(_ result: NodeSearchResult) {
        logger.info("Flying to node: \(result.title)")
        onFlyToNode?(result.id)
        setPresented(false)
    }

    public func createNode(_ option: NodeCreationOption) {
        logger.info("Creating node from palette: \(option.title)")
        onCreateNode?(option.id)
        setPresented(false)
    }

    public func selectionIndex(forNodeResultAt index: Int) -> Int {
        nodeResultsStartIndex + index
    }

    public func selectionIndex(forNodeCreationResultAt index: Int) -> Int {
        nodeCreationResultsStartIndex + index
    }

    public func selectionIndex(forActionAt index: Int) -> Int {
        actionsStartIndex + index
    }

    public var canSubmitPrompt: Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
    }

    /// Emits an unmatched palette query as a CoCaptain prompt. Listed commands
    /// continue through `onExecute`; this path is only for no-result queries.
    public func submitPromptIfNeeded() {
        let prompt = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        logger.info("Submitting unmatched command palette query to CoCaptain")
        onSubmitPrompt?(prompt)
        setPresented(false)
    }
    
    public enum Direction {
        case up, down
    }
}
