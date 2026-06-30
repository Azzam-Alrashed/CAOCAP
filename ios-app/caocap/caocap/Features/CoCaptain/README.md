# CoCaptain Feature

CoCaptain is the agentic assistant for CAOCAP. It reads the current spatial project, streams model responses, executes safe app actions, and stages code changes for human review.

## Ownership

- `Chat/` owns the CoCaptain sheet, timeline, bubbles, input composer, streaming task lifetime, direct command handling, and review item application.
- `AgentContract/` owns the machine-readable agent contract: coordinator, parser, output adapters, validator, and shared agent/review/timeline models.
- `Review/` owns review bundle and pending edit/action card rendering for human approval.
- `Analysis/` owns structural parser warnings and project recommendations from the analyzer.
- `NodeAgent/` owns the embedded node-scoped chat interface.

Supporting services live outside this feature:

- `ProjectContextBuilder` serializes the canvas for the model.
- `LLMService` streams from Firebase AI Logic.
- `AppActionDispatcher` performs high-level app actions.
- `NodePatchEngine` previews and applies exact node edits.
- `MiniAppVerificationService` executes staged code in an isolated offline WebView.

## Agent Flow

1. The user sends a message through `CoCaptainViewModel`.
2. Direct commands are resolved locally with `CommandIntentResolver` when possible.
3. Otherwise, `CoCaptainAgentCoordinator` builds project context from the active `ProjectStore`.
4. `CoCaptainTurnPurpose` selects both prompt instructions and a turn execution policy.
5. `LLMService` streams text back into the current assistant bubble.
6. `CoCaptainAgentOutputAdapter` hides machine output while streaming and turns the final response into a directive.
7. For agentic turns, `CoCaptainAgentValidator` checks action IDs, action safety, node edit shape, and required agentic work.
8. Eligible existing Mini-App code edits enter the verified coding loop.
9. CoCaptain stages the candidate, runs behavioral checks, and may repair it twice without mutating `ProjectStore`.
10. Safe actions remain buffered until verification succeeds.
11. The final verified code and pending actions become `ReviewBundleItem` entries.
12. Applying a review item revalidates the original base node text before writing changes to `ProjectStore`.

The core contract is human-in-the-loop code editing. Do not auto-apply node edits without explicit user approval.
Free-usage and subscription prompts are product CTA timeline items, not review bundles.

### Verified Coding Loop

The loop is limited to one existing, non-empty, offline Mini-App code edit. It uses at most three candidates and converts the passing result into one `replace_all` review proposal against the original base text. Blank Mini-Apps, SRS edits, multi-node edits, and network-dependent Mini-Apps continue through their existing paths.

Verification uses a non-persistent WebView, blocks external effects, captures runtime errors and `console.error`, and requires every declared behavioral check to return `true`. Failed or unsupported runs produce diagnostics without an Apply control. The rollout gate is enabled by default in Debug and TestFlight, disabled in production App Store builds, and can be overridden with `cocaptain.verifiedCodingLoopEnabled`.

## Turn Execution Modes

`CoCaptainTurnPurpose` maps to a `CoCaptainTurnExecutionPolicy` in `CoCaptainAgentModels.swift`. The coordinator reads policy flags instead of hardcoding onboarding exceptions.

| Mode | Purposes | Structured XML | Agentic retry | Execute actions / review |
|------|----------|----------------|---------------|--------------------------|
| Agentic | `.standard` | Yes | Yes | Yes |
| Conversational | `.onboardingWelcome`, `.onboardingBuildHandoff` | No | No | No — prose only |

Conversational turns still receive canvas context and purpose-specific prompt instructions, but the agent contract block is omitted from the LLM prompt. If the model disobeys and emits `cocaptain_actions`, the coordinator ignores the payload and surfaces visible prose only.

When adding a new turn purpose, declare its execution policy in the same enum switch as its prompt instructions.

## Structured Payload Contract

The model may include one trailing XML block:

```xml
<cocaptain_actions>
  <assistant_message>Visible fallback text.</assistant_message>
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
      <verification_checks>
        <verification_check id="headline" description="Headline shows the new text">
          <script><![CDATA[
            return document.querySelector("h1")?.textContent === "New text";
          ]]></script>
        </verification_check>
      </verification_checks>
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
- Verified code edits require 1–5 uniquely identified checks. Each offline script must return a Boolean, stay under 2,000 characters, and keep the combined scripts under 8,000 characters.

Invalid structured payloads are not partially executed. The coordinator retries once with parse or validation feedback. If the retry is still invalid, the user sees a conflicted review item rather than a silent no-op or unsafe action.

Firebase function calling is the preferred path for app actions through the `request_app_action` tool. The XML block remains the compatibility format for node edits until structured-output node edit payloads replace it.

If this payload changes, update parser/coordinator tests and the prompt contract in `LLMService`.

## Review Safety

Node edits store their original section `baseText` when the review bundle is created. On apply, the view model checks that the current Mini-App section text still matches that base text before applying operations. This prevents silently overwriting user edits made after the model response.

Preserve this conflict guard when refactoring review state.

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
- node edit conflict handling when base text changes.
- direct command handling for autonomous vs review-required actions.
- retry behavior when agentic work is requested but no structured payload is returned.
- retry behavior when the structured payload is present but invalid.
