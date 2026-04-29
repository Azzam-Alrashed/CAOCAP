# CoCaptain Feature

CoCaptain is the agentic assistant for Ficruty. It reads the current spatial project, streams model responses, executes safe app actions, and stages code changes for human review.

## Ownership

- `CoCaptainView` renders the timeline, input, streaming state, and review controls.
- `CoCaptainViewModel` owns presentation state, timeline items, streaming task lifetime, direct command handling, and review item application.
- `CoCaptainAgentCoordinator` orchestrates the model run: build context, stream text, parse structured actions, execute safe actions, and build review bundles.
- `CoCaptainAgentParser` extracts the trailing structured payload from a `cocaptain-actions` fenced block.
- `CoCaptainAgentModels` defines timeline, review, action, and node edit domain models.

Supporting services live outside this feature:

- `ProjectContextBuilder` serializes the canvas for the model.
- `LLMService` streams from Firebase AI Logic.
- `AppActionDispatcher` performs high-level app actions.
- `NodePatchEngine` previews and applies exact node edits.

## Agent Flow

1. The user sends a message through `CoCaptainViewModel`.
2. Direct commands are resolved locally with `CommandIntentResolver` when possible.
3. Otherwise, `CoCaptainAgentCoordinator` builds project context from the active `ProjectStore`.
4. `LLMService` streams text back into the current assistant bubble.
5. `CoCaptainAgentParser` hides the structured fenced block from visible text.
6. Safe actions are executed immediately through `AppActionDispatcher`.
7. Mutating app actions and node edits become `ReviewBundleItem` entries.
8. Applying a review item revalidates the base node text before writing changes to `ProjectStore`.

The core contract is human-in-the-loop code editing. Do not auto-apply node edits without explicit user approval.

## Structured Payload Contract

The model may include one trailing fenced block:

````text
```cocaptain-actions
{
  "assistantMessage": "Visible fallback text.",
  "safeActions": [],
  "pendingActions": [],
  "nodeEdits": []
}
```
````

Rules:

- The parser uses the last `cocaptain-actions` fence in the response.
- Malformed JSON falls back to visible text with no payload.
- `safeActions` should only contain actions that can run autonomously.
- `pendingActions` are shown for review before execution.
- `nodeEdits` target `NodeRole` values and `NodePatchOperation` arrays.

If this payload changes, update parser/coordinator tests and the prompt contract in `LLMService`.

## Review Safety

Node edits store their original `baseText` when the review bundle is created. On apply, the view model checks that the current node text still matches that base text before applying operations. This prevents silently overwriting user edits made after the model response.

Preserve this conflict guard when refactoring review state.

## Editing Guidance

- Keep UI rendering in `CoCaptainView`; keep timeline and async state in `CoCaptainViewModel`.
- Keep model orchestration in `CoCaptainAgentCoordinator`.
- Keep payload parsing deterministic and tolerant of malformed model output.
- Prefer adding new app capabilities through `AppActionDispatcher` and `AppActionID`.
- Add tests when changing parser fences, action classification, review item states, patch behavior, or retry behavior.
- Do not leak raw structured payload text into the visible chat timeline.
- Be careful with cancellation: closing the sheet cancels streaming and removes empty assistant messages.

## Verification Checklist

- Send a normal chat message and confirm streaming text appears.
- Send a direct navigation command and confirm safe actions execute or review appears as expected.
- Ask for a code change and confirm review items are created rather than auto-applied.
- Apply a node edit and confirm the target node updates plus Live Preview recompiles.
- Modify a node after a review bundle is created, then apply the stale review item and confirm it conflicts.
- Switch projects while streaming and confirm the task cancels and history resets.

## Test Targets

Useful test coverage for this feature:

- parser success, malformed JSON fallback, and trailing fence behavior.
- coordinator safe action execution and review bundle generation.
- node edit conflict handling when base text changes.
- direct command handling for autonomous vs review-required actions.
- retry behavior when agentic work is requested but no structured payload is returned.
