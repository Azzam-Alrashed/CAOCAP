import SwiftUI
import Observation
import OSLog

/// UI state for the command palette. It deliberately emits only `AppActionID`
/// values so action execution remains centralized in `AppActionDispatcher`.
@Observable
public class CommandPaletteViewModel {
    private let logger = Logger(subsystem: "Ficruty", category: "CommandPalette")
    
    public var query: String = "" {
        didSet {
            // Search results are rebuilt from the query, so keep keyboard
            // selection pinned to the first visible command.
            selectedIndex = 0
        }
    }
    public var isPresented: Bool = false
    public var selectedIndex: Int = 0
    public var actions: [AppActionDefinition] = []
    
    /// Filters against localized and canonical titles so command search works
    /// in the UI language while still matching stable English action names.
    public var filteredActions: [AppActionDefinition] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty { return actions }
        
        return actions.filter {
            $0.localizedTitle.localizedCaseInsensitiveContains(trimmedQuery) ||
            $0.title.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }
    
    public var onExecute: ((AppActionID) -> Void)?
    public var onSubmitPrompt: ((String) -> Void)?
    
    public init() {}
    
    /// Closes back to a clean state so each palette open starts from the full
    /// command list.
    public func setPresented(_ presented: Bool) {
        isPresented = presented
        if !presented {
            query = ""
            selectedIndex = 0
        }
    }
    
    public func moveSelection(direction: Direction) {
        let count = filteredActions.count
        guard count > 0 else { return }
        
        switch direction {
        case .up:
            selectedIndex = (selectedIndex - 1 + count) % count
        case .down:
            selectedIndex = (selectedIndex + 1) % count
        }
    }
    
    public func confirmSelection() {
        let filtered = filteredActions
        if selectedIndex >= 0 && selectedIndex < filtered.count {
            let action = filtered[selectedIndex]
            executeAction(action)
        } else {
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

    public var canSubmitPrompt: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && filteredActions.isEmpty
    }

    /// Emits an unmatched palette query as a CoCaptain prompt. Listed commands
    /// continue through `onExecute`; this path is only for no-result queries.
    public func submitPromptIfNeeded() {
        let prompt = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, filteredActions.isEmpty else { return }

        logger.info("Submitting unmatched command palette query to CoCaptain")
        onSubmitPrompt?(prompt)
        setPresented(false)
    }
    
    public enum Direction {
        case up, down
    }
}
