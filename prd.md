## Problem Statement

The `ProjectStore` in CAOCAP is a massive monolithic file (over 1000 lines) that handles state management, persistence, compilation, checkpoints, reactive graph calculation, node mutation, and agent pipelines all in one place. This creates significant architectural debt, making it difficult to maintain, prone to bugs, and challenging to unit test independently.

## Solution

Decompose the `ProjectStore` incrementally into a thin coordinator that delegates to 6 focused sub-engines. The public API of `ProjectStore` will remain identical to avoid any view code changes. Undo behavior will be preserved exactly by passing the `UndoManager` to sub-engines. Each extracted concern will be accompanied by dedicated unit tests.

## User Stories

1. As a developer maintaining CAOCAP, I want `ProjectStore` to only coordinate tasks instead of doing all the heavy lifting, so that I can more easily reason about the architecture.
2. As a developer, I want the persistence logic extracted into its own type (`ProjectPersistenceEngine`), so that save, load, and debouncing logic is isolated and easily testable.
3. As a developer, I want checkpoint creation and restoration isolated in a `CheckpointEngine`, so that project history and undo/redo logic are easier to manage and test.
4. As a developer, I want live preview compilation moved to a `LivePreviewEngine`, so that compilation dependencies are cleanly decoupled from core state management.
5. As a developer, I want reactive graph calculations separated into a `ReactiveGraphEngine`, so that node linking and evaluation can be unit tested without UI and persistence dependencies.
6. As a developer, I want node mutation logic (adding, removing, updating nodes) housed in a `NodeMutationEngine`, so that state changes are centralized and predictable.
7. As a developer, I want agent pipeline state extracted to an `AgentPipelineEngine`, so that the LLM flow and project state are kept separate.
8. As a developer, I want unit tests for each of these engines, so that I can confidently modify these subsystems in the future.
9. As a user, I want the app's functionality to remain exactly the same without any noticeable regressions, so that my experience using the spatial editor is uninterrupted.

## Implementation Decisions

- **Strategy**: Incremental extraction — extract one concern at a time. Each step must compile and work.
- **Extraction Order**: 
  1. Persistence (save/load/debouncing)
  2. Checkpoints
  3. Live Preview Compilation
  4. Reactive Graph Calculation
  5. Node Mutations
  6. Agent Pipeline
- **File Structure**: The extracted engines will live in a new `Services/ProjectStore/` subfolder (e.g., `Services/ProjectStore/ProjectPersistenceEngine.swift`).
- **Ownership Model**: Internal types owned by `ProjectStore`. Views only interact with `ProjectStore`'s public API — no direct access to sub-engines.
- **Undo System**: Preserve the existing undo behavior exactly. Each sub-engine receives the `UndoManager` reference from `ProjectStore` and registers undo actions the same way.
- **Public API**: Keep the `ProjectStore`'s public API identical. Every existing call like `store.save()` stays exactly the same. Zero view changes.
- **Commit Strategy**: One commit per extracted concern, following the extraction order.

## Testing Decisions

- Add unit tests for each extracted type as we go. This validates the extraction and addresses the AGENTS.md tech debt.
- Tests will only test external behavior of the sub-engines, not implementation details.
- The `ProjectMutationTests.swift` file will be used as prior art for testing mutations.
- Specific modules to be tested: `ProjectPersistenceEngine`, `CheckpointEngine`, `LivePreviewEngine`, `ReactiveGraphEngine`, `NodeMutationEngine`, and `AgentPipelineEngine`.

## Out of Scope

- Modifying SwiftUI views or routing.
- Changing the feature set or public API of `ProjectStore`.
- Refactoring `AppRouter` or other unrelated services.
- Changing the serialization format or introducing a schema migration strategy right now (this is a separate debt item).
- Fixing UI bugs (e.g., the canvas gesture dragging bug).

## Further Notes

This decomposition sets a strong foundation for future improvements, such as fixing node graph serialization and replacing the canvas gesture system, by making the state management layer modular and well-tested.
