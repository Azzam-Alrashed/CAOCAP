# The CAOCAP Codebase Learning Book

This book teaches the CAOCAP codebase as a working system. It is written for a developer who wants to become confident enough to modify the iOS app, especially the spatial canvas, project state, live preview runtime, and CoCaptain agent flow.

Keep these files open while reading:

- `README.md` for the product philosophy.
- `ROADMAP.md` for product priorities.
- `STRUCTURE.md` for the authoritative architecture map.
- `CONTRIBUTING.md` for SwiftUI and workflow standards.
- `AGENTS.md` for repository-specific agent rules.

The short version: CAOCAP is a canvas-first SwiftUI app. The user works with spatial nodes. `ProjectStore` owns the node graph. `InfiniteCanvasView` renders and manipulates it. Services compile previews, persist projects, route commands, and coordinate CoCaptain.

## Learning Map

Use this as a five-day path, or as a reference book when you need to work in a specific subsystem.

- **Day 1:** Chapters 1-4. Learn the product, app shell, routing, and node model.
- **Day 2:** Chapters 5-7. Learn project state, canvas rendering, and node editing.
- **Day 3:** Chapters 8-10. Learn preview compilation, templates, and commands.
- **Day 4:** Chapters 11-12. Learn CoCaptain and patch safety.
- **Day 5:** Chapters 13-17. Learn launch systems, persistence, tests, website, and safe change workflow.

## Core Vocabulary

| Term | Meaning |
|---|---|
| Spatial IDE | CAOCAP's main product idea: software is built in a spatial canvas instead of a conventional file tree. |
| Workspace | The currently active canvas. It can be the root canvas or a project canvas. |
| Project | A saved canvas backed by a project JSON file. |
| `SpatialNode` | The central domain object rendered on the canvas. |
| Node role | The semantic job a node plays, such as SRS, Code, Live Preview, HTML, CSS, or JavaScript. |
| Node type | The concrete node kind, such as `.code`, `.srs`, `.webView`, `.table`, or `.chart`. |
| `ProjectStore` | The observable state owner for one project. |
| Viewport | The canvas offset and zoom level. |
| Live Preview | The rendered WebView result compiled from the canonical Code node. |
| CoCaptain | The assistant flow that reads the current project, streams responses, and proposes actions or edits. |
| Review bundle | A user-approved set of assistant-proposed actions or node edits. |

---

# Chapter 1. Big Picture: What CAOCAP Is

CAOCAP is a spatial, agentic code editor for iOS and iPadOS. The product rejects the idea that building software must start with a file tree. Instead, it gives the user a canvas of meaningful artifacts: requirements, code, previews, data, charts, console output, and assistant nodes.

The repo is a public product monorepo:

- `ios-app/caocap` is the main native SwiftUI product.
- `website` is the public Next.js site for product, support, privacy, and terms pages.
- `android-app` is reserved for future work.
- `docs/agents` stores agent workflow metadata.

The architecture has a simple rule:

- `Models` define pure domain data.
- `Services` do infrastructure, business logic, persistence, compilation, and assistant coordination.
- `Features` render user-facing SwiftUI.
- `Navigation` owns workspace routing.
- `App` wires the shell and app lifecycle.

That split matters because most mistakes in this repo come from putting logic in the wrong layer. If a SwiftUI view starts owning persistence, parsing, or model orchestration, it becomes harder to test and harder to keep the spatial workflow stable.

## What To Read

- `README.md`: the mission and product posture.
- `ROADMAP.md`: what the product is currently optimizing for.
- `STRUCTURE.md`: the file map.
- `CONTRIBUTING.md`: SwiftUI and workflow standards.

## Trace Exercise

Find the phrase "spatial" in `ROADMAP.md`, then map each roadmap feature to a code area. For example:

- Spatial Canvas -> `Features/Canvas`
- CoCaptain UI -> `Features/CoCaptain`
- Context Engine -> `Services/CoCaptain/ProjectContextBuilder.swift`
- Agentic Actions -> `Services/AppActions/AppActionDispatcher.swift`

The point is to learn that product language and code ownership line up fairly directly.

## Checkpoint

You understand Chapter 1 when you can answer:

- Why is the iOS app the primary product?
- What belongs in `Models`, `Services`, and `Features`?
- Why is the app described as canvas-first?

---

# Chapter 2. The App Shell

The app starts at `ios-app/caocap/caocap/App/caocapApp.swift`.

`caocapApp` is the SwiftUI `@main` entry point. It installs an `AppDelegate`, injects `AuthenticationManager` into the SwiftUI environment, applies theme and locale preferences, and defines macOS/iPad keyboard commands for undo, redo, command palette, and CoCaptain.

`AppDelegate` is intentionally thin. It owns an `AuthenticationManager` and forwards launch setup to `AppConfiguration.shared.configure(authManager:)`. This keeps SDK bootstrapping out of views.

The real app shell is `ContentView`. It owns broad presentation state:

- `AppRouter` for workspace selection.
- `CommandPaletteViewModel` for the Omnibox.
- `CoCaptainViewModel` for the assistant sheet.
- `AppActionDispatcher` for command execution.
- `ViewportState` for the current canvas offset and zoom.
- Global sheets for sign-in, profile, purchase, project explorer, settings, snapshots, export, and node creation.

The important mental model: `ContentView` is a shell, not the product logic. It decides which major surface is visible and wires callbacks from those surfaces into router/store/action methods.

## Flow: App Launch To Canvas

```text
caocapApp
  -> AppDelegate.didFinishLaunching
    -> AppConfiguration.configure(...)
  -> WindowGroup
    -> ContentView
      -> switch router.currentWorkspace
        -> InfiniteCanvasView(store: router.rootStore)
        -> InfiniteCanvasView(store: router.activeStore)
```

The shell switches between root and project workspace by reading `router.currentWorkspace`. Both paths render `InfiniteCanvasView`; the difference is which `ProjectStore` is supplied.

## Keyboard And Global Commands

The app has two command routes:

- SwiftUI `.commands` in `caocapApp` post notifications.
- Hidden buttons in `ContentView` catch hardware shortcuts on iOS.

This duplication exists because iOS and iPadOS keyboard command handling can differ. The command path still ends in app-level state changes such as opening the command palette or summoning CoCaptain.

## What To Read

- `ios-app/caocap/caocap/App/caocapApp.swift`
- `ios-app/caocap/caocap/App/ContentView.swift`
- `ios-app/caocap/caocap/App/AppConfiguration.swift`

## Change Exercise

Pretend you need to add a new global sheet. Before editing, identify:

- Which `@State` boolean would track presentation?
- Which action should open it?
- Whether it belongs in `AppActionDispatcher`.
- Whether it needs a new feature folder or can live in an existing one.

## Checkpoint

You understand Chapter 2 when you can explain why `ContentView` should not contain node mutation rules or persistence code.

---

# Chapter 3. Navigation And Workspaces

Navigation lives in `ios-app/caocap/caocap/Navigation/AppRouter.swift`.

`WorkspaceState` has two cases:

- `.root`
- `.project(String)`, where the string is a project file name

`AppRouter` owns:

- `currentWorkspace`
- `rootStore`
- a dictionary of project file names to `ProjectStore` instances
- a small navigation stack for back navigation

The active store is computed. If the current workspace is `.root`, `activeStore` returns `rootStore`. If the current workspace is `.project(fileName)`, it returns a cached project store or creates one immediately.

That lazy creation is important. It lets the app navigate to saved projects without preloading every project file.

## Flow: Create New Project

```text
User action
  -> AppRouter.createNewProject(template:)
    -> generate project_XXXXXXXX.json
    -> ProjectTemplateProvider.nodes(for:)
    -> ProjectStore(fileName: ..., initialNodes: ...)
    -> cache store in projects
    -> navigate(to: .project(fileName))
```

`AppRouter` does not know how to build the node graph itself. It delegates initial project contents to `ProjectTemplateProvider`, which keeps graph factory work out of routing.

## Flow: Resume Last Project

```text
AppRouter.resumeLastProject()
  -> read lastProjectFileName from UserDefaults
  -> navigate(to: .project(fileName))
  -> activeStore lazily creates ProjectStore if needed
  -> ProjectStore loads file from disk
```

## Sub-Canvases

A sub-canvas is represented by a node with type `.subCanvas` and a `linkedCanvasFileName`. Tapping it navigates to another project workspace. This preserves the canvas-first mental model while allowing nested spatial organization.

## What To Read

- `ios-app/caocap/caocap/Navigation/AppRouter.swift`
- `ios-app/caocap/caocap/Features/Canvas/Providers/ProjectTemplateProvider.swift`
- `ios-app/caocap/caocap/Models/SpatialNode.swift`

## Checkpoint

You understand Chapter 3 when you can answer:

- Why does `AppRouter` own project stores?
- Why should node graph construction stay out of `AppRouter`?
- How does a project file name become a loaded canvas?

---

# Chapter 4. The Core Data Model

The central model is `SpatialNode`.

A `SpatialNode` is both a visual thing and a semantic artifact. It has an `id`, `type`, `position`, title/subtitle/icon, theme, relationships, optional action, content fields, agent metadata, chart settings, input node IDs, Firebase config, and sub-canvas link.

The node type is concrete UI/data shape:

- `.standard`
- `.webView`
- `.srs`
- `.code`
- `.art`
- `.text`
- `.number`
- `.table`
- `.calculation`
- `.display`
- `.aiAgent`
- `.chart`
- `.firebase`
- `.subCanvas`
- `.console`

The node role is semantic. `NodeRole` asks, "What job does this node perform in the project?" The `.code` node is the canonical single-file implementation artifact.

This distinction is important: UI often cares about type, but CoCaptain and live preview often care about role.

## Relationships

Nodes can be linked in several ways:

- `nextNodeId` supports a linear next relationship.
- `connectedNodeIds` supports directed 1-to-many canvas links.
- `inputNodeIds` supports dataflow-like input relationships for calculation, display, chart, and AI nodes.

These are UUID references, not direct object references. That keeps project snapshots Codable and local-first.

## Content Fields

`SpatialNode` has multiple optional content fields because different node types store different payloads:

- `textContent` for editable text/code/SRS/table-like data.
- `htmlContent` for compiled preview HTML on WebView nodes.
- `drawingData` for PencilKit art nodes.
- `aiResponse` and `promptTemplate` for AI processing nodes.
- `firebaseFirestorePath` and `textContent` for Firebase configuration.

This model is broad, but it is still pure. It does not import SwiftUI, Firebase, WebKit, or persistence services.

## What To Read

- `ios-app/caocap/caocap/Models/SpatialNode.swift`
- `ios-app/caocap/caocap/Models/NodeRole.swift`
- `ios-app/caocap/caocap/Models/NodeTheme.swift`
- `ios-app/caocap/caocap/Models/SRSScaffold.swift`
- `ios-app/caocap/caocap/Models/SRSReadinessState.swift`

## Change Exercise

Pretend you are adding a new node type named "Checklist". Write down every likely place you would inspect:

- `SpatialNode` and `NodeType`
- `NodeView`
- `NodeDetailView`
- `ProjectContextBuilder`
- `NodeMutationEngine`
- tests around persistence or node mutation

The lesson: adding a node type is cross-cutting. Do not treat it as a single-view change.

## Checkpoint

You understand Chapter 4 when you can explain the difference between node type, node role, and node relationship.

---

# Chapter 5. ProjectStore: The Heart Of The App

`ProjectStore` is the observable state owner for one spatial project.

It owns durable state:

- `projectName`
- `nodes`
- `viewportOffset`
- `viewportScale`
- checkpoint history
- save status

It also coordinates engines:

- `ProjectPersistenceService` for project JSON.
- `ProjectSaveController` for debounced saves.
- `CheckpointManager` for snapshots.
- `LivePreviewOrchestrator` for WebView compilation.
- `ReactiveGraphEngine` for graph recalculation.
- `NodeMutationEngine` for focused mutations.
- `AgentPipelineEngine` for downstream node agents.

The important design move is that `ProjectStore` is an owner and facade. It exposes methods views can call, but it delegates specialized work to smaller engines.

## Loading

When a store initializes, it calls `load(initialNodes:initialViewportScale:)`.

If no project file exists:

- it initializes with default nodes,
- sets the initial viewport scale,
- compiles live preview immediately,
- schedules an initial save for normal project files.

If a project file exists:

- it asks `ProjectPersistenceService` to load it,
- applies the snapshot,
- saves again if the file was migrated,
- compiles live preview,
- loads checkpoint history.

## Saving

`ProjectStore` can save immediately with `save(showIndicator:)`, or debounce with `requestSave(showIndicator:)`.

Most UI edits should use debounced saves. That keeps typing and dragging from writing to disk on every frame.

## Mutations

Views should call store methods, not mutate `store.nodes` directly. Examples:

- `updateNodePosition`
- `updateNodeTextContent`
- `updateNodeTheme`
- `updateNodeType`
- `addNode`
- `deleteNode`
- `restore(from:)`

Many of these methods register undo operations, request saves, recalculate graph outputs, or trigger live preview compilation.

## Flow: Edit Code Text

```text
CodeEditorView
  -> store.updateNodeTextContent(id:text:)
    -> NodeMutationEngine.updateNodeTextContent(...)
      -> register undo
      -> mutate node.textContent
      -> request save
      -> recalculate graph
      -> trigger downstream agents
    -> ProjectSaveController debounce
    -> LivePreviewOrchestrator compile on debounce completion
```

## Checkpoints

Checkpoints protect user work before significant changes, especially assistant changes. A checkpoint is a saved `ProjectSnapshot` plus metadata. The snapshot browser reads this history and can restore an older graph.

## What To Read

- `ios-app/caocap/caocap/Services/ProjectStore/ProjectStore.swift`
- `ios-app/caocap/caocap/Services/ProjectStore/NodeMutationEngine.swift`
- `ios-app/caocap/caocap/Services/ProjectStore/ProjectSaveController.swift`
- `ios-app/caocap/caocap/Services/ProjectStore/CheckpointManager.swift`

## Checkpoint

You understand Chapter 5 when you can trace a node text edit from a SwiftUI binding to disk persistence and live preview refresh.

---

# Chapter 6. The Spatial Canvas

The canvas runtime starts in `InfiniteCanvasView`.

It composes three visual layers:

1. Dotted background.
2. Connection layer.
3. Scaled and offset node layer.

Node positions are stored as offsets from the visible center. The viewport then transforms the whole node layer with an offset and scale.

## Coordinate Model

There are two coordinate systems:

- Canvas space: where `SpatialNode.position` lives.
- Screen space: where SwiftUI draws pixels after viewport transforms.

`ConnectionLayer` uses screen-space conversion so arrows point at rendered node frames and do not clip strangely during pan and zoom.

`ViewportState` owns gesture math. This prevents pan/zoom calculations from being scattered through views.

## Gesture State

`InfiniteCanvasView` keeps transient interaction state:

- currently selected node
- drag offsets per node
- whether a node is being dragged
- measured node frames

During drag, the node follows the finger using local `nodeDragOffsets`. Only when the drag ends does the view commit the final position to `ProjectStore`. This is the right split: smooth UI in local state, durable model change at gesture completion.

## Flow: Drag A Node

```text
DragGesture.onChanged
  -> nodeDragOffsets[node.id] = value.translation
  -> NodeView renders at position + temporary offset

DragGesture.onEnded
  -> final position = node.position + translation
  -> store.updateNodePosition(id:position:persist:)
  -> clear temporary drag offset
  -> save debounced
```

## Flow: Open A Node

```text
Tap NodeView
  -> if node.action exists: call onNodeAction
  -> else if subCanvas: navigate to linked canvas
  -> else: selectedNode = node
  -> sheet presents NodeDetailView
```

## What To Read

- `ios-app/caocap/caocap/Features/Canvas/README.md`
- `ios-app/caocap/caocap/Features/Canvas/InfiniteCanvasView.swift`
- `ios-app/caocap/caocap/Features/Canvas/ViewportState.swift`
- `ios-app/caocap/caocap/Features/Canvas/Components/ConnectionLayer.swift`
- `ios-app/caocap/caocap/Features/Canvas/Components/NodeView.swift`

## Change Exercise

If arrows look wrong after zooming, do not start in `NodeView`. Start by checking:

- whether `NodeFrameData` reports the right frames,
- whether `ViewportState` scale/offset are current,
- whether `ConnectionLayer` converts from canvas space to screen space correctly.

## Checkpoint

You understand Chapter 6 when you can explain why drag state is temporary but node position is durable.

---

# Chapter 7. Node Editing Flow

`NodeDetailView` is the sheet-level router for editing one node.

It inspects `currentNode.type` and chooses the right editor:

- `.firebase` -> `FirebaseConfigNodeEditorView`
- `.webView` -> `HTMLWebView`
- `.code` -> `CodeEditorView`
- `.srs` -> `SRSEditorView`
- `.art` -> `ArtEditorView`
- other types -> a generic inspector/editor with specialized controls

On compact devices, `NodeDetailView` uses tabs: artifact/editor and node agent. On regular width, it uses a split layout with the editor and `NodeAgentChatView` side by side.

## Code Editing

`CodeEditorView` wraps `LineNumberedTextView`, a UIKit-backed editor with line numbers and syntax highlighting. Edits flow into `ProjectStore`, which schedules persistence and preview compilation.

## SRS Editing

`SRSEditorView` is the requirement-writing surface. SRS text also updates `srsReadinessState` through `SRSReadinessEvaluator`, so the app and CoCaptain know whether requirements are empty, drafted, structured, or ready.

## Web Preview

For `.webView` nodes, `NodeDetailView` shows `HTMLWebView` with the node's compiled `htmlContent`. The user does not edit the WebView directly; it is a render target.

## Generic Node Inspector

The generic editor handles nodes like text, number, table, calculation, display, chart, and AI agent nodes. It includes agent profile configuration and type-specific input controls.

## What To Read

- `ios-app/caocap/caocap/Features/Canvas/Components/NodeDetailView.swift`
- `ios-app/caocap/caocap/Features/Canvas/Components/CodeEditorView.swift`
- `ios-app/caocap/caocap/Features/Canvas/Components/SRSEditorView.swift`
- `ios-app/caocap/caocap/Features/Canvas/Components/HTMLWebView.swift`
- `ios-app/caocap/caocap/Features/CoCaptain/NodeAgent/NodeAgentChatView.swift`

## Checkpoint

You understand Chapter 7 when you can describe the difference between editing a Code node and viewing a WebView node.

---

# Chapter 8. Live Preview Runtime

`LivePreviewCompiler` turns project nodes into a WebView payload.

The preferred modern path is:

```text
Code node textContent
  -> LivePreviewCompiler.compile(nodes:)
  -> inject Firebase head if needed
  -> inject viewport meta if needed
  -> write htmlContent to Live Preview node
  -> HTMLWebView renders it
```

If no Code node exists, live preview compilation returns nil and the WebView is not updated.

## Firebase Injection

If the canvas has a Firebase node with valid config, `FirebasePreviewBootstrap` produces head injection HTML. The preview exposes Firebase state through globals like `window.__caocapFirestore`. CoCaptain is instructed to use that existing bootstrap instead of initializing Firebase again.

If Firebase is present but not ready, diagnostics can be injected into the preview so users understand why persistence is not working.

## Console Output

Console-related services and nodes support runtime feedback from the WebView. This is part of the roadmap direction toward a richer execution environment.

## What To Read

- `ios-app/caocap/caocap/Services/Runtime/LivePreviewCompiler.swift`
- `ios-app/caocap/caocap/Services/ProjectStore/LivePreviewOrchestrator.swift`
- `ios-app/caocap/caocap/Services/Runtime/FirebasePreviewBootstrap.swift`
- `ios-app/caocap/caocap/Services/Runtime/ConsoleLogStore.swift`
- `ios-app/caocap/caocap/Features/Canvas/Components/ConsoleNodeView.swift`

## Change Exercise

If a Code node edit does not update the preview, trace:

1. Did the editor call `store.updateNodeTextContent`?
2. Did the save debounce complete?
3. Did `LivePreviewOrchestrator` run?
4. Did `LivePreviewCompiler` find a `.livePreview` role node?
5. Did the WebView node's `htmlContent` change?

## Checkpoint

You understand Chapter 8 when you can explain why the WebView node is a render target, not the source of truth.

---

# Chapter 9. Project Templates And Providers

Initial graph construction belongs in providers, not routers or large views.

Providers create static node graphs:

- `ProjectTemplateProvider` creates new project templates.
- The root/home graph is generated through provider-style code in the Canvas feature.

These providers decide:

- which nodes exist,
- where they are positioned,
- how they are titled,
- what content they start with,
- how they are linked.

Keeping this logic in providers makes it easier to reason about launch state, onboarding, examples, and project templates without bloating `AppRouter` or `ContentView`.

## Flow: New Project Template

```text
AppRouter.createNewProject(template:)
  -> ProjectTemplateProvider.nodes(for: template)
  -> ProjectStore(initialNodes: nodes, initialViewportScale: 0.3)
  -> InfiniteCanvasView renders the graph
```

## What To Read

- `ios-app/caocap/caocap/Features/Canvas/Providers/ProjectTemplateProvider.swift`
- `ios-app/caocap/caocap/Features/ProjectExplorer/NewProjectSheetView.swift`
- `ios-app/caocap/caocap/Navigation/AppRouter.swift`

## Checkpoint

You understand Chapter 9 when you can explain why creating default nodes inside `ContentView` would be an architectural smell.

---

# Chapter 10. Omnibox And App Actions

The Omnibox is the command palette. It gives users a fast way to search, navigate, create nodes, open surfaces, and invoke AI.

The core pieces are:

- `CommandPaletteView`: the UI.
- `CommandPaletteViewModel`: query state, matching, and execution.
- `CommandIntentResolver`: maps natural language commands to app actions.
- `AppActionDispatcher`: central action registry and execution boundary.

`AppActionDispatcher` matters because it is shared by humans and agents. The UI and CoCaptain both ask for actions by typed IDs, not ad hoc strings.

## Action Safety

Each action definition includes:

- ID
- title
- icon
- category
- whether it is mutating
- whether it allows autonomous execution

This is how CAOCAP separates safe navigation from changes that should require review.

Examples:

- `go_root` can execute autonomously.
- `new_project` is mutating and does not allow autonomous execution.
- some create-node actions are mutating but may allow autonomous execution because they are small, visible, reversible workspace actions.

## Flow: User Opens Command Palette

```text
Cmd+K
  -> notification or hidden iOS shortcut button
  -> CommandPaletteViewModel.setPresented(true)
  -> user chooses action
  -> AppActionDispatcher.perform(...)
  -> configured closure mutates router/store/presentation state
```

## Flow: CoCaptain Requests Action

```text
LLM output / function call
  -> CoCaptainAgentOutputAdapter
  -> CoCaptainAgentValidator
  -> safe action: dispatcher.perform(..., source: .agentAutomatic)
  -> pending action: review bundle
```

## What To Read

- `ios-app/caocap/caocap/Features/Omnibox/README.md`
- `ios-app/caocap/caocap/Features/Omnibox/CommandPaletteView.swift`
- `ios-app/caocap/caocap/Features/Omnibox/CommandPaletteViewModel.swift`
- `ios-app/caocap/caocap/Services/AppActions/AppActionDispatcher.swift`
- `ios-app/caocap/caocap/Services/CoCaptain/CommandIntentResolver.swift`

## Checkpoint

You understand Chapter 10 when you can explain why app actions are typed and centralized.

---

# Chapter 11. CoCaptain: Agentic Flow

CoCaptain is the assistant path. It reads the current spatial project, streams model output, executes safe actions, and stages code edits for review.

The UI layer:

- `CoCaptainView`
- `CoCaptainViewModel`
- `CoCaptainTimelineListView`
- `CoCaptainInputComposer`
- `CoCaptainBubbleViews`
- `CoCaptainReviewViews`

The orchestration layer:

- `CoCaptainAgentCoordinator`
- `CoCaptainAgentOutputAdapter`
- `CoCaptainAgentParser`
- `CoCaptainAgentValidator`
- `CoCaptainAgentModels`

The supporting services:

- `ProjectContextBuilder`
- `LLMService`
- `AppActionDispatcher`
- `NodePatchEngine`
- `TokenUsageLimiter`

## One Assistant Turn

```text
User sends message
  -> CoCaptainViewModel
    -> try direct command resolution
    -> otherwise CoCaptainAgentCoordinator.run(...)
      -> ProjectContextBuilder builds canvas context
      -> LLMService streams text/function calls
      -> output adapter hides machine-readable payload while streaming
      -> parser extracts final action directive
      -> validator checks action IDs, safety, and node edit shape
      -> safe actions execute
      -> pending actions and node edits become review bundle items
```

The key product contract: assistant code/content edits are human-in-the-loop. The model may propose edits, but it should not silently rewrite user nodes.

## Project Context

`ProjectContextBuilder` serializes the canvas into a compact prompt:

- project name
- workspace file name
- node count
- SRS readiness
- Firebase context
- node graph inventory
- canonical editable node contents

For node-scoped assistant chat, it includes selected node content, linked neighbors, and node agent profile/memory.

Prompt context is intentionally trimmed. Large prompts can cause opaque Firebase AI Logic failures, so the builder keeps node content bounded.

## Structured Output

CoCaptain supports structured directives through adapters. The current compatibility format includes a trailing XML-style `cocaptain_actions` block, while Firebase function calls are preferred for app actions.

The coordinator only parses executable work after the model finishes streaming. During streaming, the user sees only visible assistant text.

## Retry Behavior

If the model is asked to build or edit something but fails to return usable structured work, the coordinator retries once with stronger instructions. If validation still fails, the user sees a conflicted review item rather than silent failure.

## What To Read

- `ios-app/caocap/caocap/Features/CoCaptain/README.md`
- `ios-app/caocap/caocap/Features/CoCaptain/Chat/CoCaptainViewModel.swift`
- `ios-app/caocap/caocap/Features/CoCaptain/AgentContract/CoCaptainAgentCoordinator.swift`
- `ios-app/caocap/caocap/Features/CoCaptain/AgentContract/CoCaptainAgentOutputAdapter.swift`
- `ios-app/caocap/caocap/Features/CoCaptain/AgentContract/CoCaptainAgentValidator.swift`
- `ios-app/caocap/caocap/Services/CoCaptain/ProjectContextBuilder.swift`
- `ios-app/caocap/caocap/Services/CoCaptain/LLMService.swift`

## Checkpoint

You understand Chapter 11 when you can describe why CoCaptain has parser, validator, coordinator, and review UI as separate responsibilities.

---

# Chapter 12. Node Patch Safety

`NodePatchEngine` applies deterministic text operations to editable nodes.

Supported operations:

- `replace_all`
- `replace_exact`
- `insert_before_exact`
- `insert_after_exact`
- `append`
- `prepend`

Exact operations fail if the target text is not found. That is not annoying defensive coding; it is the safety mechanism. If the model says "replace this exact block" and the block is gone, applying the edit anyway would risk changing the wrong thing.

## Preview First

The patch engine can preview a change:

```text
resolve target node
  -> read original text
  -> apply operations to a copy
  -> return NodePatchPreview(originalText, resultText)
```

The review UI then shows the proposed change. Applying the review item later should re-check that the base text still matches what the model saw.

## Conflict Protection

Review items store base text. If the user edits the node after CoCaptain creates a review bundle, applying the stale review should conflict instead of overwriting the user's newer work.

This is one of the most important safety properties in the app.

## What To Read

- `ios-app/caocap/caocap/Services/CoCaptain/NodePatchEngine.swift`
- `ios-app/caocap/caocap/Features/CoCaptain/Review/CoCaptainReviewViews.swift`
- `ios-app/caocap/caocap/Features/CoCaptain/Chat/CoCaptainViewModel.swift`
- tests covering node patch and review behavior in `ios-app/caocap/caocapTests/CoCaptain`

## Change Exercise

If you add a new patch operation, update:

- `NodePatchOperationType`
- `NodePatchEngine.apply`
- validator rules for required fields
- parser/adapter contract if wire format changes
- focused tests for success and conflict cases

## Checkpoint

You understand Chapter 12 when you can explain why `replace_exact` should fail loudly.

---

# Chapter 13. Authentication, Subscriptions, And Compliance

Launch readiness matters in CAOCAP. The app has real product surfaces for identity, subscriptions, privacy, account deletion, and required updates.

## Authentication

`AuthenticationManager` wraps Firebase Auth. It supports anonymous use, account linking, and social providers through feature coordinators:

- `AppleSignInCoordinator`
- `GoogleSignInCoordinator`
- sign-in UI in `SignInView`

Anonymous login matters because CAOCAP is local-first and should let users start working quickly. Account linking matters because users need a path to save or connect work without losing local progress.

## Subscriptions

`SubscriptionManager` uses StoreKit 2. The subscription feature owns purchase UI and components. Pro entitlement influences AI usage limits and product surfaces.

## Compliance

Compliance code and docs are not decorative. App Store readiness depends on:

- privacy policy and terms pages,
- account deletion,
- restore purchases,
- subscription wording,
- privacy manifest,
- required update prompts,
- Firebase and StoreKit behavior.

## What To Read

- `ios-app/caocap/caocap/Features/Auth/README.md`
- `ios-app/caocap/caocap/Services/Account/AuthenticationManager.swift`
- `ios-app/caocap/caocap/Features/Auth/SignInView.swift`
- `ios-app/caocap/caocap/Features/Subscription/README.md`
- `ios-app/caocap/caocap/Services/Account/SubscriptionManager.swift`
- `ios-app/caocap/caocap/Features/Settings`
- `ios-app/caocap/caocap/App/PrivacyInfo.xcprivacy`
- `website/src/app`

## Checkpoint

You understand Chapter 13 when you can name which launch-readiness areas must be rechecked before each App Store update.

---

# Chapter 14. Persistence And File Boundaries

CAOCAP project files are local JSON snapshots.

`ProjectSnapshot` contains:

- schema version
- project name
- nodes
- viewport offset
- viewport scale
- optional checkpoint label

`ProjectPersistenceService` owns:

- file URLs,
- project existence checks,
- decoding,
- schema version checks,
- atomic writes,
- snapshot save/load/delete/list,
- project directory lookup.

## Schema Versioning

`ProjectPersistenceService.currentSchemaVersion` is the current project file format version. When loading a file, the service checks the saved schema version.

- Only the current schema version is accepted.
- Missing, older, or future schema versions throw `unsupportedSchemaVersion` and `ProjectStore` falls back to in-memory defaults without overwriting the file.

## Atomic Writes

Saves write to a temporary file first, then replace or move into place. This prevents interrupted writes from corrupting the main project file.

## Project Manager

`ProjectManager` is an actor for listing and managing saved project files asynchronously. This keeps file work off the main actor where possible.

## Export And Import

Project export/import is part of the file boundary story. The app can share project data and open project files from the system file picker.

## What To Read

- `ios-app/caocap/caocap/Services/ProjectStore/ProjectPersistenceService.swift`
- `ios-app/caocap/caocap/Services/ProjectStore/ProjectManager.swift`
- `ios-app/caocap/caocap/Services/ProjectStore/ExportService.swift`
- `ios-app/caocap/caocap/Features/ProjectExplorer/ProjectExplorerView.swift`

## Checkpoint

You understand Chapter 14 when you can explain why loading a future schema version should fail instead of attempting a best-effort decode.

---

# Chapter 15. Tests And Verification Strategy

Tests in this repo should protect contracts, not just lines.

High-value test areas:

- parser and structured payload behavior,
- validator safety rules,
- node patch operations and conflicts,
- project persistence and schema version checks,
- live preview compilation,
- graph recalculation,
- project store mutations,
- viewport math,
- action dispatch safety.

## When To Add Tests

Add tests when changing:

- payload wire formats,
- parser/validator/coordinator behavior,
- patch operation semantics,
- project JSON schema,
- node role inference,
- live preview compilation,
- save/load or schema version behavior,
- AppAction safety classification,
- graph and node mutation behavior.

## Verification Commands

iOS build verification uses `xcodebuild` from the repo root. The AGENTS instructions say to run tests/builds only when explicitly requested. When you do verify iOS, prefer the latest available simulator instead of hard-coding a device name unless a specific command is already approved.

Website verification:

```bash
cd website
npm install
npm run lint
npm run build
```

## Manual Verification For UI

For canvas changes, manually check:

- open/create project,
- pan,
- zoom,
- drag nodes,
- double-tap focus,
- open editor sheet,
- edit Code node,
- confirm Live Preview updates,
- open WebView full-screen,
- confirm arrows stay attached.

For CoCaptain changes, manually check:

- normal chat streaming,
- direct command handling,
- safe action execution,
- review bundle creation,
- stale edit conflict,
- cancellation on sheet close or project switch.

## What To Read

- `ios-app/caocap/caocapTests`
- `ios-app/caocap/caocapUITests`
- `CONTRIBUTING.md`
- feature READMEs for verification checklists

## Checkpoint

You understand Chapter 15 when you can choose the smallest useful test for a change without ignoring cross-module contracts.

---

# Chapter 16. Website Overview

The website is the public product surface. It supports launch readiness rather than the core spatial editing runtime.

The website lives in `website` and uses Next.js App Router under `website/src/app`.

Common responsibilities:

- product presentation,
- support pages,
- privacy policy,
- terms of service,
- App Store compliance links.

The iOS app and website are coupled at the product/compliance level, not through shared runtime code. If subscription wording, account deletion, privacy links, or support routes change, verify both app surfaces and website pages.

## What To Read

- `website/README.md`
- `website/src/app`
- `ios-app/caocap/caocap/Features/Settings`
- `ROADMAP.md` release-hardening items

## Checkpoint

You understand Chapter 16 when you can explain why a website privacy page can block an iOS launch even though it is not part of the app binary.

---

# Chapter 17. How To Make A Change Safely

Use this workflow whenever you modify the repo.

## 1. Locate Ownership

Before editing, decide which layer owns the change:

- Pure domain shape -> `Models`
- Long-lived behavior/infrastructure -> `Services`
- User-facing UI -> `Features`
- Workspace transition -> `Navigation`
- App launch/global shell -> `App`

If the change crosses layers, identify the contract between them.

## 2. Read The Nearest README

Feature READMEs exist for a reason. Before editing Canvas, CoCaptain, Auth, Subscription, or Omnibox, read the feature README.

## 3. Trace One Real User Flow

Do not edit from file names alone. Trace a concrete action:

- User taps a node.
- User edits code.
- User creates a project.
- User asks CoCaptain for a change.
- User applies a review item.

Then change the owner of the behavior, not the most convenient caller.

## 4. Keep Views Thin

SwiftUI views can own presentation state and gestures. They should not own persistence, parsing, LLM orchestration, schema version checks, or patch semantics.

Good view behavior:

- bind text fields,
- call store methods,
- present sheets,
- route taps.

Bad view behavior:

- directly rewrite `store.nodes` in complex ways,
- parse model payloads,
- write files,
- decide assistant safety policy.

## 5. Preserve Human-In-The-Loop AI

When touching CoCaptain:

- safe autonomous actions may execute,
- mutating or risky actions should become review items,
- node edits must not auto-apply without user approval,
- stale base text must conflict.

## 6. Update Architecture Docs When Needed

If you add a new architectural area, change ownership boundaries, add major services, or alter source tree structure, update `STRUCTURE.md` in the same change.

## 7. Add Focused Tests

Tests should match risk:

- small view-only polish may need manual UI verification,
- parser/patch/persistence changes need unit tests,
- shared contract changes need broader tests.

## Final Change Checklist

Before finishing a change, ask:

- Did I avoid reverting unrelated user work?
- Did I keep the edit scoped?
- Did I use existing patterns?
- Did I update docs if architecture changed?
- Did I add or run the relevant tests if the behavior is contract-heavy?
- Did I mention any verification I could not run?

---

# Appendix A. Common Codebase Tours

## Tour 1: Create Project

```text
ProjectExplorer / action
  -> AppRouter.createNewProject
  -> ProjectTemplateProvider
  -> ProjectStore
  -> ProjectPersistenceService
  -> InfiniteCanvasView
```

## Tour 2: Edit Code And Preview

```text
NodeView tap
  -> NodeDetailView
  -> CodeEditorView
  -> ProjectStore.updateNodeTextContent
  -> NodeMutationEngine
  -> ProjectSaveController
  -> LivePreviewOrchestrator
  -> LivePreviewCompiler
  -> WebView node htmlContent
  -> HTMLWebView
```

## Tour 3: Ask CoCaptain To Change Code

```text
CoCaptainInputComposer
  -> CoCaptainViewModel
  -> CoCaptainAgentCoordinator
  -> ProjectContextBuilder
  -> LLMService
  -> OutputAdapter / Parser
  -> Validator
  -> NodePatchEngine.preview
  -> ReviewBundleItem
  -> user applies
  -> ProjectStore.updateNodeTextContent
```

## Tour 4: Restore A Snapshot

```text
SnapshotBrowserView
  -> ProjectStore.restore
  -> CheckpointManager
  -> ProjectPersistenceService.loadSnapshot
  -> ProjectStore.apply(snapshot)
  -> save
  -> compile live preview
```

# Appendix B. Where To Start By Task

| Task | Start Here |
|---|---|
| Change app launch behavior | `App/caocapApp.swift`, `App/ContentView.swift` |
| Change project navigation | `Navigation/AppRouter.swift` |
| Add or alter node data | `Models/SpatialNode.swift`, `Models/NodeRole.swift` |
| Change canvas gestures | `Features/Canvas/InfiniteCanvasView.swift`, `Features/Canvas/ViewportState.swift` |
| Change node rendering | `Features/Canvas/Components/NodeView.swift` |
| Change node editor routing | `Features/Canvas/Components/NodeDetailView.swift` |
| Change code preview | `Services/Runtime/LivePreviewCompiler.swift` |
| Change project save/load | `Services/ProjectStore/ProjectPersistenceService.swift` |
| Change command palette behavior | `Features/Omnibox`, `Services/AppActions/AppActionDispatcher.swift` |
| Change CoCaptain behavior | `Features/CoCaptain/README.md`, `Features/CoCaptain/AgentContract/CoCaptainAgentCoordinator.swift` |
| Change assistant patching | `Services/CoCaptain/NodePatchEngine.swift` |
| Change subscriptions | `Features/Subscription`, `Services/Account/SubscriptionManager.swift` |
| Change auth | `Features/Auth`, `Services/Account/AuthenticationManager.swift` |
| Change public policy pages | `website/src/app` |

# Appendix C. Reading Questions

Use these when studying a file:

- What layer does this file belong to?
- What state does it own?
- What state does it read but not own?
- What methods are called by views?
- What methods are called by services?
- What work is intentionally delegated?
- What user flow would break if this file changed?
- What tests would catch a bad change here?

# Appendix D. Mini Glossary For New Contributors

- **Canvas-first:** The canvas is the primary workspace, not a secondary visualization.
- **Local-first:** Project state is saved locally; network behavior is limited and intentional.
- **Canonical node:** The node CoCaptain or preview logic treats as the main artifact for a role.
- **Legacy node:** Older project shape still supported for saved-user compatibility.
- **Autonomous action:** An app action CoCaptain may execute without review.
- **Pending action:** An app action staged for user approval.
- **Review-required edit:** A content change proposed by CoCaptain that needs explicit user approval.
- **Conflict:** A proposed edit no longer applies because the underlying node changed.
