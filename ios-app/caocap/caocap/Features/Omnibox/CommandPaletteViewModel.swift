import SwiftUI
import Observation
import OSLog

/// UI state for the command palette. It deliberately emits only `AppActionID`
/// values so action execution remains centralized in `AppActionDispatcher`.
@Observable
public class CommandPaletteViewModel {
    public enum CommandPaletteMode {
        /// Standard mode: shows node results, action commands, and node-creation options.
        case search
        /// Dedicated actions-only list, entered via the "Show all actions" shortcut.
        case actionsList
    }
    
    private let logger = Logger(subsystem: "CAOCAP", category: "CommandPalette")
    
    /// Bound to the search field; resets keyboard selection whenever the value changes.
    public var query: String = "" {
        didSet {
            // Only reset keyboard selection when the query actually changed,
            // so that pressing Enter (which can re-trigger didSet with the
            // same value) doesn't clobber the arrow-key selection.
            guard query != oldValue else { return }
            if prefersPromptSubmission {
                selectPromptRowIfAvailable()
            } else {
                selectedIndex = 0
            }
        }
    }
    public var isPresented: Bool = false
    /// Flat index across all result sections (node results → actions → node creation → prompt row).
    public var selectedIndex: Int = 0
    /// Full list of registered app actions; filtered by `filteredActions` before display.
    public var actions: [AppActionDefinition] = []
    /// The current canvas nodes; searched by `nodeResults` when the query is non-empty.
    public var nodes: [SpatialNode] = []
    public var mode: CommandPaletteMode = .search
    /// When `true` the palette automatically moves the selection to the CoCaptain prompt row
    /// instead of the first command, letting the user hit Return to send a message immediately.
    public var prefersPromptSubmission: Bool = false {
        didSet {
            guard prefersPromptSubmission != oldValue else { return }
            if prefersPromptSubmission {
                selectPromptRowIfAvailable()
            }
        }
    }
    
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
    private var actionsStartIndex: Int { nodeResultCount }
    private var nodeCreationResultsStartIndex: Int { nodeResultCount + actionResultCount }
    private var promptRowIndex: Int { nodeResultCount + actionResultCount + nodeCreationResultCount }

    public var promptSelectionIndex: Int { promptRowIndex }
    
    /// Called by the host when an action should be executed; avoids duplicating dispatch logic here.
    public var onExecute: ((AppActionID) -> Void)?
    /// Called when the user requests to pin an action shortcut onto the canvas.
    public var onPinAction: ((AppActionID) -> Void)?
    /// Called when the user selects a node result, asking the canvas to fly to that node.
    public var onFlyToNode: ((UUID) -> Void)?
    /// Called when the user picks a node-creation option from the palette.
    public var onCreateNode: ((NodeType) -> Void)?
    /// Called when the user submits a free-text query that didn't match any command or node.
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
        
        if selectedIndex >= nodeResultsStartIndex && selectedIndex < actionsStartIndex {
            flyToNode(nodeResults[selectedIndex - nodeResultsStartIndex])
        } else if selectedIndex >= actionsStartIndex && selectedIndex < nodeCreationResultsStartIndex {
            executeAction(actions[selectedIndex - actionsStartIndex])
        } else if selectedIndex >= nodeCreationResultsStartIndex && selectedIndex < promptRowIndex {
            createNode(nodeCreationResults[selectedIndex - nodeCreationResultsStartIndex])
        } else if canSubmitPrompt && selectedIndex == promptRowIndex {
            submitPromptIfNeeded()
        }
    }
    
    /// Emits the chosen action ID and dismisses. The view model does not perform
    /// side effects directly because the same action system is shared with agents.
    public func executeAction(_ action: AppActionDefinition) {
        logger.info("Executing action: \(action.title)")
        onExecute?(action.id)
        if action.id == .showActionsList {
            query = ""
            selectedIndex = 0
            setPresented(true, mode: .actionsList)
            return
        }
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

    /// Maps a node-result list index into the unified `selectedIndex` space.
    public func selectionIndex(forNodeResultAt index: Int) -> Int {
        nodeResultsStartIndex + index
    }

    /// Maps a node-creation list index into the unified `selectedIndex` space.
    public func selectionIndex(forNodeCreationResultAt index: Int) -> Int {
        nodeCreationResultsStartIndex + index
    }

    /// Maps an action list index into the unified `selectedIndex` space.
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
        /// Move the keyboard highlight upward through results, wrapping from the top.
        case up
        /// Move the keyboard highlight downward through results, wrapping from the bottom.
        case down
    }
}
