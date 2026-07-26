# CoCaptain Chat UI/UX Plan

## Implementation Status

Implemented on `codex/cocaptain-chat-ux` on July 26, 2026. The six phases are
represented in the app code and feature documentation. The follow-up polish
pass adds a calmer message hierarchy, grouped conversation history, a
context-aware composer, visible pending-review entry point, context/privacy
disclosure, compact secondary actions, Review Bundle hierarchy, semantic
feedback, haptics, and adaptive accessibility behavior. Static consistency
checks, an iOS Simulator build, targeted CoCaptain tests, and live iPhone/iPad
visual passes—including Arabic RTL—were completed as part of this change.

## Outcome

Make CoCaptain feel as dependable and understandable as a modern AI chat while
remaining native to CAOCAP:

- the canvas stays primary;
- project context is always explicit;
- AI work remains human-reviewed;
- conversations survive relaunches;
- every failure has a clear recovery path;
- applied changes remain easy to inspect and undo.

This plan intentionally does not turn CoCaptain into a generic full-screen
chatbot. On iPad it should become a workspace companion beside the canvas; on
iPhone it should remain a focused sheet.

## Success Measures

- A builder can leave and return without losing a project conversation.
- A builder can create, rename, search, switch, and delete conversations.
- A builder can copy or retry an assistant response and edit or resend a user
  message without reconstructing the prompt manually.
- Network, quota, attachment, cancellation, and model failures have distinct
  presentation and an actionable next step.
- The active mode, canvas scope, pinned nodes, and agent progress are visible
  without opening a hidden menu.
- Long timelines remain performant and offer an obvious path back to the latest
  response or pending Review Bundle.
- Completed Review Bundles collapse, diffs are scannable, and applied changes
  expose Undo.
- The composer works well with touch, hardware keyboards, VoiceOver, Dynamic
  Type, and right-to-left layouts.

## Product Guardrails

1. Node edits and mutating actions are never auto-applied.
2. Raw tool calls, XML payloads, and chain-of-thought remain hidden.
3. Progress copy describes observable work only, such as “Reading canvas” or
   “Preparing changes.”
4. Conversation persistence is local-first and scoped to the current canvas
   file.
5. Node-scoped chat persistence and Review Lifecycle identity remain intact.
6. Copying the interaction patterns of other AI products is secondary to
   preserving CAOCAP’s spatial mentor experience.

## Phase 1 — Conversation Foundation

### Deliverables

- Add a local `CoCaptainConversationStore` under `Services/CoCaptain`.
- Persist project-scoped conversations in a sidecar JSON file keyed by canvas
  file name so the project snapshot schema does not need to change.
- Define codable conversation, message, timeline, and turn-state records.
- Add New Chat, conversation switcher, rename, search, and delete.
- Confirm destructive deletion; make New Chat the primary navigation action.
- Keep unresolved project Review Bundles attached to their originating
  conversation.

### Acceptance Criteria

- Relaunching the app restores the most recently active project conversation.
- Switching canvases restores each canvas’s active conversation independently.
- Deleting a conversation cannot delete canvas nodes or snapshots.
- At least one conversation always exists for a project.

## Phase 2 — Message Actions And Recovery

### Deliverables

- Add an action row/context menu to assistant messages: Copy, Retry, Share, and
  feedback.
- Add an action row/context menu to user messages: Copy, Edit, and Resend.
- Store enough turn metadata to retry with the original mode, mentions,
  attachments, and purpose.
- Replace error-shaped assistant prose with typed error timeline items.
- Add Retry to recoverable errors and Continue/Retry to stopped responses.
- Continue active generation while the chat surface is dismissed. Only explicit
  Stop cancels a turn.

### Acceptance Criteria

- Retry creates a new response without duplicating the original user message.
- Edit places the old prompt and its context back in the composer for review.
- Technical error details are available without dominating the primary message.
- A dismissed sheet can be reopened to the same in-progress turn.

## Phase 3 — Empty State, Context, And Progress

### Deliverables

- Replace the generic greeting-only state with a project-aware welcome surface
  and three or four starter prompts.
- Show a persistent context strip above the composer:
  current canvas, node count, pinned nodes, and local/cloud route when relevant.
- Render `@` references as removable context chips in the draft and as distinct
  chips on sent messages.
- Explain Agent, Ask, and Plan in the mode picker.
- Introduce typed, user-facing progress phases:
  connecting, reading context, thinking, preparing changes, and applying.

### Acceptance Criteria

- A new user can explain what each mode does before sending a prompt.
- A user can identify the exact pinned nodes without parsing prompt text.
- Progress labels never claim an operation the coordinator is not performing.

## Phase 4 — Timeline And Composer

### Deliverables

- Replace the eager timeline stack with lazy rendering.
- Add a floating “Jump to latest” control when the user is away from the bottom.
- Restore per-conversation scroll position.
- Add lightweight timestamps and day separators.
- Use Return to send and Shift-Return for a newline when a hardware keyboard is
  present; provide Command-Return as an explicit alternative.
- Align onboarding instructions with actual composer behavior.

### Acceptance Criteria

- Streaming does not pull a reader away from an older message.
- Returning to a conversation restores a useful reading position.
- Sending and inserting a newline are both discoverable and accessible.

## Phase 5 — Review Bundle Polish

### Deliverables

- Collapse resolved Review Bundles by default while keeping their outcome
  visible.
- Show line-oriented before/after changes with added and removed emphasis.
- Keep unresolved items expanded and pending actions prominent.
- Add Undo beside successful applied-change summaries.
- Keep View on Canvas available while a Review Bundle is unresolved.

### Acceptance Criteria

- A long conversation is not dominated by completed review UI.
- A beginner can distinguish what will be removed from what will be added.
- Undo uses the existing `UndoManager`/checkpoint behavior and never bypasses
  ProjectStore.

## Phase 6 — Adaptive Layout, Attachments, And Accessibility

### Deliverables

- Use an inspector-like side companion on regular-width iPad layouts and the
  existing detented sheet on compact layouts.
- Add attachment loading, validation, failure, retry/removal, type, and size
  feedback.
- Make sent images previewable at full size.
- Use semantic text styles and allow Dynamic Type to reflow controls.
- Enforce 44-point interactive targets, coherent VoiceOver groups, meaningful
  labels/hints, reduced-motion behavior, and RTL-safe alignment.

### Acceptance Criteria

- Canvas and CoCaptain can remain visible and useful together on iPad.
- Every attachment has a visible state before sending.
- The core send, stop, retry, mode, context, and review paths are operable with
  VoiceOver and hardware keyboards.

## Implementation Sequence

1. Conversation models and persistence service.
2. View-model conversation lifecycle.
3. Conversation browser and navigation.
4. Typed turn/error state and retry/edit actions.
5. Bubble action UI and composer draft restoration.
6. Context strip, mode education, empty state, and progress.
7. Lazy timeline, scroll restoration, and keyboard behavior.
8. Review Bundle disclosure/diff/undo.
9. Adaptive presentation, attachment state, and accessibility.
10. Documentation and targeted regression coverage.

## Verification Scope

Repository guidance requires builds and tests only when explicitly requested.
Implementation should still receive a static consistency pass. When verification
is requested, prioritize:

- conversation-store encoding, migration, isolation, and deletion;
- retry/edit semantics and turn-state transitions;
- project switching and in-progress dismissal behavior;
- Review Bundle restoration and undo;
- compact/regular-width UI snapshots;
- VoiceOver labels and keyboard submission behavior.

## Repository Notes

At the start of this work, `ROADMAP.md`, `docs/agents/issue-tracker.md`,
`docs/agents/triage-labels.md`, and `docs/agents/domain.md` were referenced by
repository instructions but were not present. This plan uses `README.md`,
`CONTEXT.md`, `STRUCTURE.md`, `CONTRIBUTING.md`, the CoCaptain feature README,
and the App Session README as the available source of truth.
