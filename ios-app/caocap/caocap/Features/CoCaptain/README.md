# CoCaptain Feature

CoCaptain is the agentic assistant for CAOCAP. It reads the current spatial project, streams model responses, executes safe app actions, and stages code changes for human review.

## Ownership

- `Chat/` owns the CoCaptain sheet, timeline, bubbles, input composer (including the Agent/Ask mode chip and `cocaptain.chatMode` persistence), streaming task lifetime, direct command handling, and review item application.
- `AgentContract/` owns the machine-readable agent contract: coordinator, parser, output adapters, validator, and shared agent/review/timeline models.
- `Review/` owns review bundle and pending edit/action card rendering for human approval.
- `Analysis/` owns structural parser warnings and project recommendations from the analyzer.
- `NodeAgent/` owns the embedded node-scoped chat interface.

Supporting services live outside this feature:

- `ProjectContextBuilder` serializes the canvas for the model.
- `LLMService` streams from Firebase AI Logic.
- `AppActionDispatcher` performs high-level app actions.
- `NodePatchEngine` previews and applies node edits using flexible target matching for all exact operations.

## Agent Flow

1. The user picks Agent or Ask in the composer (persisted as `cocaptain.chatMode`, default Agent) and sends a message through `CoCaptainViewModel`.
2. Direct commands are resolved locally with `CommandIntentResolver` when possible. In Ask mode, mutating shortcuts are skipped so those messages go to the model as chat.
3. Otherwise, `CoCaptainAgentCoordinator` builds project context from the active `ProjectStore` using the turn plan’s detail level (implementation for Agent, product for Ask). By default Agent context carries only a short head of each Mini-App's code/SRS; the model reads full sections on demand (see the read tool below). The full-budget context is kept when the local MLX backend (`gemma-4-local`) is selected, since it has no function calling.
4. `CoCaptainTurnPlan` merges turn purpose with the selected `CoCaptainChatMode` to choose the effective execution policy. There is no keyword intent classifier.
5. `LLMService` streams text back into the current assistant bubble. When the model calls the read-only `read_node_section(nodeId, section)` tool, the coordinator answers it inline against the active `ProjectStore` and `LLMService` sends the result back on the same chat session (bounded to 4 tool-response rounds per turn).
6. `CoCaptainAgentOutputAdapter` hides machine output while streaming and turns the final response into a directive.
7. For structured turns, `CoCaptainAgentValidator` checks action IDs, action safety, and node edit shape. Executable work is enforced only when the policy requires it (onboarding guided edit), not for standard Agent chat.
8. Safe actions execute immediately when autonomous; pending actions and node edits become `ReviewBundleItem` entries for human approval.
9. Applying a review item revalidates the original base node text before writing changes to `ProjectStore`. Undo and checkpoints remain available after Apply.

The core contract is human-in-the-loop code editing. Do not auto-apply node edits without explicit user approval.
Free-usage and subscription prompts are product CTA timeline items, not review bundles.

### Flexible Patch Matching

`NodePatchEngine.apply` resolves `replace_exact` / insert-exact targets with one matcher (`PatchTargetMatcher`). It tries, in order:

1. Semantic alias resolution (beginner phrases like `title`, `headline`, `heading`, `big text` resolve to the page's `<h1>` inner text, never the `<title>` tag)
2. Literal match
3. Case-insensitive match
4. Token-sequence match (ignores punctuation differences such as `hello world` vs `Hello World!`)
5. Whitespace-flexible match

Each tier returns a 3-way `Resolution` (`unique` / `ambiguous` / `none`) instead of silently failing:

- **Unique** matches apply normally. Review staging still normalizes successful results to a single canonical `replace_all` operation.
- **Ambiguous** matches (2+ hits in one tier) throw `NodePatchError.ambiguous` carrying `PatchMatchCandidate` values — plain-language labels plus a context slice that occurs exactly once in the text, so a later pick re-resolves deterministically.
- **No match** computes up to three near-match candidates from token overlap ("did you mean one of these?"); only when no decent candidate exists does the edit conflict, with friendly mentor-tone copy.

### Clarification Flow (Never Reject, Always Guide)

Ambiguity never dead-ends:

- `buildReviewBundle` converts `NodePatchError.ambiguous` into a `.needsClarification` review item whose card asks "Which one did you mean?" with one tappable button per candidate.
- `CoCaptainViewModel.resolveClarification` re-stages the chosen candidate locally — no model round-trip — and the item becomes a normal `.pending` review.

Intent-level ambiguity ("make it pop") is handled by the model with a `clarifying_question` contract element (see below), rendered as a tappable option card. Picking an option sends it as the user's next message. Validation failures also append a locally-built recovery question so every failure path has a tappable next step.

## Turn Execution Modes

`CoCaptainTurnPlan` merges `CoCaptainTurnPurpose` with `CoCaptainChatMode` into a `CoCaptainTurnExecutionPolicy` in `CoCaptainAgentModels.swift`. The coordinator reads `turnPlan.effectivePolicy` instead of hardcoding onboarding exceptions. Onboarding purposes override the chat mode; standard turns follow the composer’s Agent/Ask selection (`chatMode`, default Agent, persisted under `cocaptain.chatMode`). Project-scoped and node-scoped CoCaptain share that same stored mode.

| Policy | When | Structured tools | Enforce edit | Agentic retry | Execute / stage | Context |
|------|------|------------------|--------------|---------------|-----------------|---------|
| Agent | Standard turn + `.agent` mode | Yes | No — pure chat OK | Yes — invalid structured output only | Yes when the model emits work | Implementation |
| Ask | Standard turn + `.ask` mode | No | No | No | No — prose only | Product |
| Conversational | `.onboardingWelcome`, `.onboardingBuildHandoff` | No | No | No | No — prose only | Product |
| Agentic (onboarding) | `.onboardingGuidedEdit` | Yes | Yes | Yes — missing or invalid work | Yes — stages a guided code edit for review | Implementation |

Do not reintroduce keyword intent classification. Agent mode must stage reviewable edits from structured fixtures even when the user message lacks verbs like “make” or “build,” and must finish pure prose turns without “must include an edit” failures.

Ask and conversational turns still receive canvas context and mode/purpose prompt instructions, but the agent contract block is omitted from the LLM prompt and action catalogs / in-turn tool executors are not passed. If the model disobeys and emits `cocaptain_actions`, the coordinator ignores the payload and surfaces visible prose only. Connection-fallback “edits unavailable” notices apply only when the turn expected canvas work (`requiresDegradedConnectionNotice`), not Ask.

`CoCaptainTurnCompletion.shouldAdvanceToOnboardingReview` is `true` when a guided-edit turn succeeds and presents a review bundle. If the model or network fails, `OnboardingCoCaptainReviewFixture` injects a local review bundle so onboarding never hard-blocks.

When adding a new turn purpose, declare its execution policy in the same enum switch as its prompt instructions. When changing mode → policy mapping, update the turn-plan / coordinator policy tests.

## Structured Payload Contract

There are two wire formats for node edits and clarifying questions; both converge on the same `CoCaptainAgentPayload`, so the validator, review builder, and conflict guard are format-independent.

### Native node-edit tools (preferred, feature-gated)

When `NodeEditToolsFeature` is enabled (default on in Debug/TestFlight, off in production App Store builds, overridable via `cocaptain.nodeEditToolsEnabled`), the model is instructed to use Gemini function calling:

- `propose_node_edit(nodeId, section, summary, operations[], learningNote)` — one call per node edit, with nested operation objects mirroring the XML shapes below.
- `ask_clarifying_question(prompt, options[])` — one short question with 2–4 outcome-phrased options.

`CoCaptainNodeEditFunctionAdapter` maps these calls into the payload. With the flag on, the XML schema block is omitted from the prompt and the agentic retry message references the tools; the XML parser stays in place as a silent fallback for models that still emit it. If a turn contains both tool calls and an XML block, the function-call edits win and the XML edits are dropped. `CoCaptainAgentOutputSource` records which format delivered each directive for rollout telemetry.

### XML block (fallback, and the only format for the local MLX backend)

The model may include one trailing XML block:

```xml
<cocaptain_actions>
  <assistant_message>Visible fallback text.</assistant_message>
  <clarifying_question prompt="One short question when the request is too vague to act on">
    <option>First concrete outcome</option>
    <option>Second concrete outcome</option>
  </clarifying_question>
  <safe_actions>
    <action id="id" />
  </safe_actions>
  <pending_actions>
    <action id="id" />
  </pending_actions>
  <node_edits>
    <node_edit role="miniApp" section="code" summary="Update headline">
      <operation type="replace_all">
        <content><![CDATA[<h1>New text</h1>]]></content>
      </operation>
      <learning_note concept="Short concept name">2-3 plain sentences about what this change teaches, referencing the user's own app.</learning_note>
    </node_edit>
  </node_edits>
</cocaptain_actions>
```

Rules:

- The parser uses the last `cocaptain_actions` tag in the response.
- Malformed XML falls back to visible text with no payload.
- `safeActions` may only contain available, non-mutating, autonomous actions.
- `pendingActions` are shown for review before execution and are required for mutating or non-autonomous app actions.
- `nodeEdits` target Mini-App nodes by `nodeId`, `role="miniApp"`, and `section="srs"` or `section="code"`, plus `NodePatchOperation` arrays.
- Node edits require a non-empty summary and at least one operation.
- Exact operations require a non-empty target.
- `clarifying_question` needs a non-empty `prompt` and 2–4 non-empty options; malformed questions degrade to prose. A question-only payload counts as valid agentic work, and a question always takes precedence over node edits in the same turn (the edits are dropped). The same precedence applies to `ask_clarifying_question` vs `propose_node_edit` function calls.
- `learning_note` (or the `learningNote` tool argument) is an optional short lesson attached to a node edit: a `concept` name plus 2–3 plain sentences. It is revealed as a "What you just learned" timeline card only after the user applies the edit — never on the review card. Malformed notes degrade to nil without invalidating the edit; when the model omits one, the coordinator builds a local fallback from the edit summary.
- Prompt rules keep the mentor tone: never refuse, use plain non-technical language, and ask exactly one clarifying question with outcome-phrased options when unsure. "Title"/"headline" mean the visible page heading, not the browser tab title.

Invalid structured payloads are not partially executed. The coordinator retries once with parse or validation feedback. If the retry is still invalid, the user sees a recovery question rather than a silent no-op or unsafe action.

Firebase function calling is the preferred path for app actions through the `request_app_action` tool, and — behind `NodeEditToolsFeature` — for node edits and clarifying questions through `propose_node_edit` / `ask_clarifying_question`. The XML block remains the compatibility format until tool usage dominates the output-source telemetry.

If this payload changes, update parser/coordinator tests and the prompt contract in `LLMService`.

## Review Safety

Node edits store their original section `baseText` when the review bundle is created. On apply, the view model checks that the current Mini-App section text still matches that base text before applying operations. This prevents silently overwriting user edits made after the model response.

Preserve this conflict guard when refactoring review state.

## Node-Scoped Review Persistence

Pending review bundles on node-scoped CoCaptain sessions are JSON-encoded into
`NodeAgentState.pendingReviewBundlesData` and restored when the node CoCaptain
panel reopens. Auto-triggered agent pipeline runs use the same persistence path so
`awaitingReview` nodes expose Apply/Reject controls after reopening CoCaptain.

Clearing node chat history also clears persisted pending review bundles.

Review cards with a target node include **View on Canvas**, which flies the workspace viewport to that node while CoCaptain stays open.

## Editing Guidance

- Keep sheet UI rendering in `Chat/CoCaptainView`; keep timeline and async state in `Chat/CoCaptainViewModel`.
- Assistant chat bubbles may render Markdown for readable explanations, but raw structured payloads must stay hidden.
- Keep model orchestration in `AgentContract/CoCaptainAgentCoordinator`.
- Keep payload parsing deterministic and tolerant of malformed model output.
- Prefer adding new app capabilities through `AppActionDispatcher` and `AppActionID`.
- Add tests when changing parser fences, action classification, review item states, patch behavior, or retry behavior.
- Do not leak raw structured payload text into the visible chat timeline.
- Be careful with cancellation: closing the sheet cancels streaming and removes empty assistant messages.
- Keep validation near the coordinator boundary. SwiftUI views should render review state, not decide whether model output is safe.
- Keep raw model wire formats behind output adapters. The coordinator should consume directives, not Firebase/Gemini-specific response parts.
- Keep app actions in `request_app_action`; keep Mini-App SRS/code changes in `nodeEdits`.
- Keep free-tier quota enforcement in `LLMService`/`TokenUsageLimiter`; CoCaptain UI should only surface quota state when a hard limit blocks a request, then route upgrades through a product CTA. Review bundles are reserved for workspace changes and assistant-proposed app actions.

## Verification Checklist

- Send a normal chat message and confirm streaming text appears.
- Confirm assistant Markdown renders cleanly and message text can be selected or copied.
- Open the input plus menu and confirm quick prompts send once.
- Switch Agent ↔ Ask from the composer chip; confirm the placeholder updates and the choice survives relaunch (default Agent).
- In Agent mode, ask to rename a Mini-App headline and confirm a review bundle can stage Apply.
- Switch to Ask and send the same rename prompt; confirm prose-only reply with no review staging.
- Open node-scoped CoCaptain and confirm it uses the same Agent/Ask selection.
- Send a direct navigation command and confirm safe actions execute or review appears as expected.
- Ask for a code change and confirm review items are created rather than auto-applied.
- Apply a Mini-App code edit and confirm the target Mini-App section updates plus the preview recompiles.
- Modify a node after a review bundle is created, then apply the stale review item and confirm it conflicts.
- Switch projects while streaming and confirm the task cancels and history resets.

## Test Targets

Useful test coverage for this feature:

- parser success, malformed JSON fallback, and trailing fence behavior.
- coordinator safe action execution and review bundle generation.
- validator rejection for unknown actions, unsafe safe actions, unavailable pending actions, and empty node edit operations.
- function-call adapter mapping for safe actions, pending actions, malformed arguments, and mixed function-call + fenced node edits.
- node-edit function adapter mapping for `propose_node_edit` / `ask_clarifying_question`, precedence of tool edits over XML edits, and flag-dependent prompt/retry content.
- learning-note extraction, coordinator carry-through, fallback generation, and the apply-time mentor card.
- `read_node_section` tool round-trips and context-budget slimming behavior.
- node edit conflict handling when base text changes.
- direct command handling for autonomous vs review-required actions; Ask skips mutating short-circuits.
- retry behavior when agentic work is required (onboarding guided edit) but no structured payload is returned.
- retry behavior when the structured payload is present but invalid (Agent and guided edit).
- Agent pure-prose turns finish without forced edit retries; Agent stages reviews from structured fixtures without keyword verbs.
- Ask never stages a review bundle from model output; Ask uses product context and omits degraded edit notices.
- turn-plan policy mapping for Agent, Ask, and onboarding purposes.
