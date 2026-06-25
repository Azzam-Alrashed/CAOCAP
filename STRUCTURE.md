# CAOCAP — Codebase Architecture

This document is the authoritative map of the CAOCAP codebase. CAOCAP is organized as a public product monorepo, with each platform isolated in its own top-level directory. The iOS app uses a **domain-driven, feature-based structure** to maximize isolation, scalability, and developer clarity.

> [!NOTE]
> If you add a new file that changes the architecture, update this document in the same commit.

---

## Repository Root

```
CAOCAP/
├── ios-app/              # Native iOS/iPadOS app
│   └── caocap/           # Xcode project and all Swift source files
├── android-app/          # Future Android app
├── website/              # Public website, support pages, and policies
├── README.md             # Project overview, mission, and devlog
├── ROADMAP.md            # Strategic milestone tracker
├── STRUCTURE.md          # This document — the architectural map
├── CONTRIBUTING.md       # Contribution standards and git workflow
└── LICENSE               # GNU GPL v3.0
```

---

## iOS Source Tree (`ios-app/caocap/caocap/`)

```
caocap/
├── App/
├── Navigation/
├── Models/
├── Services/
│   ├── Account/
│   ├── AppActions/
│   ├── AppEnvironment/
│   ├── CoCaptain/
│   ├── ProjectStore/
│   ├── Runtime/
│   └── WorkspaceIntelligence/
├── Extensions/
├── Features/
│   ├── Auth/
│   ├── Canvas/
│   │   ├── Components/
│   │   └── Providers/
│   ├── Omnibox/
│   ├── CoCaptain/
│   │   ├── AgentContract/
│   │   ├── Analysis/
│   │   ├── Chat/
│   │   ├── NodeAgent/
│   │   └── Review/
│   ├── Launch/
│   ├── Overlays/
│   ├── Settings/
│   └── Subscription/
├── Resources/
└── Preview Content/
```

## iOS Test Tree (`ios-app/caocap/caocapTests/`)

```
caocapTests/
├── AppEnvironment/
├── Canvas/
├── CoCaptain/
├── Onboarding/
├── ProjectStore/
├── Runtime/
├── Smoke/
└── WorkspaceIntelligence/
```

---

## Directory Reference

### `App/`
The application shell and lifecycle management. The thinnest layer possible — no business logic lives here.

| File | Responsibility |
|---|---|
| `caocapApp.swift` | `@main` entry point. Initializes Firebase and injects `AppRouter` as an environment object. |
| `ContentView.swift` | Root view. Observes `AppRouter` and switches between Home and Project workspaces while presenting global sheets. |
| `AppConfiguration.swift` | Static configuration for Firebase Function names and environment keys. |
| `Info.plist` | System-level permissions and metadata. |

---

### `Navigation/`
Centralized, type-safe routing. All workspace transitions flow through here — nothing navigates by string.

| File | Responsibility |
|---|---|
| `AppRouter.swift` | `@Observable` class managing `WorkspaceState` (`.home`, `.project`). Owns all `ProjectStore` instances, root/sub-canvas navigation stack, and session tracking for the last opened canvas file. |

---

### `Models/`
Pure domain data. No UI, no persistence, no side effects. These structs define the *language* of the entire app.

| File | Responsibility |
|---|---|
| `SpatialNode.swift` | The core canvas primitive. Holds `id`, `type` (`.standard`, `.miniApp`, `.subCanvas`), position, relationships, action shortcuts, agent metadata, linked sub-canvas metadata, theme, and nested `MiniAppState` for runnable app internals. |
| `NodeTheme.swift` | Pure enum for color tokens for the six node themes (blue, purple, green, orange, red, gray). |
| `NodeRole.swift` | Canonical role inference for Mini-App, Sub-Canvas, and custom/action nodes. |
| `SRSReadinessState.swift` | Domain state for whether a Mini-App SRS section is empty, structured, drafted, or ready. |
| `SRSScaffold.swift` | Definition of Software Requirements Specification (SRS) templates and check helpers. |

---

### `Services/`
Infrastructure and heavy-lifting. These are long-lived objects that outlive individual views.

| Folder | Responsibility |
|---|---|
| `Account/` | Firebase Auth and StoreKit subscription infrastructure. |
| `AppActions/` | Centralized action registry for app, Omnibox, and agent-triggered actions. |
| `AppEnvironment/` | App-wide environment helpers such as localization, haptics, and update prompts. |
| `Runtime/` | Mini-App preview compilation and preview bootstrapping. |
| `WorkspaceIntelligence/` | Spatial layout, search indexing, project analysis, and SRS readiness evaluation. |
| `ProjectStore/` | Project state, persistence, checkpoints, exports, and reactive compilation. |
| `CoCaptain/` | Backend engines and API clients specific to the CoCaptain agentic flow. |

#### `Services/Account/`
Identity and monetization infrastructure.

| File | Responsibility |
|---|---|
| `AuthenticationManager.swift` | Wraps Firebase Auth. Handles anonymous login, account linking, and social provider flows. |
| `SubscriptionManager.swift` | StoreKit 2 integration. Manages Pro subscription state, purchase flow, and transaction verification. |

#### `Services/AppActions/`
App action registry and execution.

| File | Responsibility |
|---|---|
| `AppActionDispatcher.swift` | Centralized action registry. Allows the app and the AI agent to trigger high-level navigation and project mutations. |

#### `Services/AppEnvironment/`
App-wide support helpers.

| File | Responsibility |
|---|---|
| `AppUpdateService.swift` | Firebase Remote Config minimum-version gate for required App Store update prompts. |
| `HapticsManager.swift` | Central haptic feedback helper that honors app haptics settings. |
| `LocalizationManager.swift` | Runtime language selection, localized strings, localized project/node labels, and date formatting. |

#### `Services/Runtime/`
Live project execution and preview support.

| File | Responsibility |
|---|---|
| `LivePreviewCompiler.swift` | Pure compiler that renders each Mini-App node's embedded code into its runnable preview payload. |
| `FirebasePreviewBootstrap.swift` | Handles preview HTML injection and bootstrap configuration from Mini-App Firebase settings. |

#### `Services/WorkspaceIntelligence/`
Workspace analysis, search, and layout helpers.

| File | Responsibility |
|---|---|
| `NodeLayoutOrganizer.swift` | Decoupled node positioning and spatial layout organizer. |
| `NodeSearchIndex.swift` | Text indexing and ranking provider for workspace search (used by Command Palette). |
| `ProjectAnalyzer.swift` | Inspects spatial nodes and links to make contextual recommendations. |
| `SRSReadinessEvaluator.swift` | Evaluates SRS text completeness and acceptance-check readiness. |

---

#### `Services/ProjectStore/`
State management, persistence, checkpoints, and reactive compilation for the spatial workspace project store.

| File | Responsibility |
|---|---|
| `ProjectStore.swift` | Observable project state owner. Manages `[SpatialNode]`, viewport state, undo wiring, debounced save requests, live preview refresh, and omnibox shortcut pinning. |
| `ProjectPersistenceService.swift` | Project file URLs, JSON schema decoding/encoding, schema version checks, and atomic writes. |
| `CanvasFileNaming.swift` | Nested workspace file naming (`canvas_*.json`) and legacy `project_*.json` resolution for sub-canvas navigation. |
| `CanvasWorkspaceMigration.swift` | One-time migration from project-manager filenames and root shortcut nodes to the canvas workspace model. |
| `ExportService.swift` | Generates shareable exports asynchronously on a background thread. |
| `CheckpointManager.swift` | Coordinates pre-agent mutation backup checkpoints. |
| `NodeMutationEngine.swift` | Manages standard node and layout mutations. |
| `LivePreviewOrchestrator.swift` | Orchestrates WebView live compiles. |
| `ProjectSaveController.swift` | Saves projects with debounced JSON serialization. |
| `AgentPipelineEngine.swift` | Triggers node-scoped local/remote AI agent request turns for opted-in downstream nodes. |

---

#### `Services/CoCaptain/`
Decoupled backend engines and API clients specific to the CoCaptain agentic flow.

| File | Responsibility |
|---|---|
| `LLMService.swift` | Interface for the Firebase AI Logic SDK. Manages streaming sessions with the Gemini backend. Also coordinates local on-device MLX model download and inference. |
| `TokenUsageLimiter.swift` | Local estimated-token quota tracker for free CoCaptain and AI node usage; Pro entitlements bypass the free monthly cap. |
| `CommandIntentResolver.swift` | Maps plain-language command palette and CoCaptain prompts to available app actions. |
| `ProjectContextBuilder.swift` | Logic to "harvest" the spatial graph and serialize it into a grounded prompt context for the LLM. |
| `NodePatchEngine.swift` | A precision editing engine that previews partial patches (replace/insert/append) for Mini-App SRS and Code sections. |

`ProjectStore` and `ProjectPersistenceService` also maintain checkpoint metadata and saved project snapshots. The infrastructure is used to protect work before significant AI or mutation flows; a full user-facing snapshot browser remains roadmap work.

---

### `Extensions/`
Lightweight, reusable Swift and framework extensions. No dependencies on app-specific logic.

| File | Responsibility |
|---|---|
| `Color+Hex.swift` | Hex string → `SwiftUI.Color` conversion utility. |
| `NodeRole+UI.swift` | View layer mapping for node icons and theme colors. |
| `NodeTheme+UI.swift` | Computed SwiftUI Color mapping for pure NodeTheme model. |
| `KeyboardDismisser.swift` | UIKit fallback that resigns the current first responder, for input surfaces without a `@FocusState` binding. |
| `View+KeyboardDismiss.swift` | Shared opt-in view modifiers (`dismissKeyboardOnTap`, `interactiveKeyboardDismiss`) for consistent keyboard dismissal across text-input surfaces. |

---

### `Features/`
All user-facing UI. Each subfolder is a self-contained feature module with its own views, components, and state.

---

#### `Auth/`
Identity management and account security.

| File | Responsibility |
|---|---|
| `SignInView.swift` | Multi-provider sign-in sheet with Apple, Google, and GitHub options. Supports "Save Work" account linking for anonymous users. |
| `AppleSignInCoordinator.swift` | Runs Apple ID OAuth flows and exchanges credentials with Firebase. |
| `GoogleSignInCoordinator.swift` | Runs Google Sign-in flows and exchanges credentials with Firebase. |

---

#### `Canvas/`
The spatial runtime — the heart of CAOCAP.

| File | Responsibility |
|---|---|
| `InfiniteCanvasView.swift` | The root spatial view. Composes the dotted grid, connection layer, and all nodes. Handles pan (`DragGesture`) and zoom (`MagnifyGesture`) with anchor-aware physics. |
| `ViewportState.swift` | Value type tracking the canvas `offset` and `scale`. Encapsulates all gesture math. |

**`Components/`** — Reusable building blocks of the canvas UI:

| File | Responsibility |
|---|---|
| `NodeView.swift` | Renders a single `SpatialNode` on the canvas. Mini-App nodes show the live 9:16 preview card backed by nested `MiniAppState`. |
| `NodeDetailView.swift` | Opens Mini-App nodes into a full-screen running preview with Mini-App-scoped FAB actions for SRS, Code, Firebase, Agent, Settings, and Back to Canvas. |
| `NodeFrameData.swift` | Preference-key plumbing that reports rendered node frames so connection arrows can target real node centers. |
| `ConnectionLayer.swift` | Draws Bezier-curve connections for all `connectedNodeIds` relationships. Operates in screen-space to prevent clipping. |
| `CodeEditorView.swift` | VS Code-style editor sheet for a Mini-App's embedded HTML/CSS/JS code section. Wraps `LineNumberedTextView` with a sleek dark tab bar and file extension label. |
| `LineNumberedTextView.swift` | `UIViewRepresentable` wrapping a dual-pane `UIView` (gutter + `UITextView`). Implements synchronized scrolling and regex-based syntax highlighting for single-file app code. |
| `SRSEditorView.swift` | Notion-style "Zen Mode" editor for a Mini-App's embedded SRS section. Serif font, increased line spacing, generous padding, and a branded top bar. |
| `HTMLWebView.swift` | Thin `UIViewRepresentable` wrapping `WKWebView`. Receives compiled HTML payloads and renders them. Scroll disabled for canvas embedding. |
| `DottedBackground.swift` | The infinite dotted grid. Renders efficiently using `Canvas` and adapts to the current viewport transform. |
| `FirebaseConfigNodeEditorView.swift` | Sub-view panel for setting up a Mini-App's Firebase Web config and optional Firestore default path. |

**`Providers/`** — Static node graph factories:

| File | Responsibility |
|---|---|
| `HomeProvider.swift` | Generates the default node graph for the Home workspace. |
| `ProjectTemplateProvider.swift` | Generates the default Mini-App starter node for new projects. |

---

#### `Omnibox/`
The `Cmd+K` intent-driven command palette. A floating Spotlight-style UI that surfaces project actions, navigation, and AI commands.

| File | Responsibility |
|---|---|
| `CommandPaletteView.swift` | Floating Spot-light style command palette input overlay. |
| `CommandPaletteViewModel.swift` | Holds query state, matches keywords, and executes palette action routing. |

---

#### `CoCaptain/`
The agentic AI companion. A native sheet interface for real-time collaboration.

| Folder/File | Responsibility |
|---|---|
| `Chat/` | CoCaptain sheet UI, chat timeline, bubbles, prompt composer, and view-model state. |
| `AgentContract/` | Model-output adapter, XML parser, validator, coordinator, and shared agent/review/timeline models. |
| `Review/` | Review bundle and pending edit/action cards for human approval. |
| `Analysis/` | Structural parser warnings and recommendations from the analyzer. |
| `NodeAgent/` | Embedded node chat interface for running quick agent context requests. |

---

#### `Launch/`
Launch transition and global launch-time prompts shown by the root app shell.

| File | Responsibility |
|---|---|
| `LaunchScreenView.swift` | Branded launch transition overlay presented while the app shell warms up. |
| `AppUpdatePromptView.swift` | Blocking required-update prompt shown when Remote Config says the installed app version is unsupported. |

---

#### `Overlays/`
Persistent floating HUD elements — the project header bar, zoom indicator, and action buttons that float above the canvas at all times.

| File | Responsibility |
|---|---|
| `FloatingCommandButton.swift` | Implements a **Slide-to-Select radial menu** for quick access to tools. |
| `CanvasHUDView.swift` | Displays project title and current zoom percentage. |

---

#### `SnapshotBrowser/`
Browses and restores project checkpoints from saved snapshots directory.

| File | Responsibility |
|---|---|
| `SnapshotBrowserView.swift` | Renders a timeline of available project snapshots with recovery and deletion controls. |

---

#### `Settings/`
Profile, app settings, support, legal, account, and preference screens.

| File | Responsibility |
|---|---|
| `SettingsView.swift` | Global app options, gated models configuration, and clear cache panels. |
| `ProfileView.swift` | Firebase authentication state details, account deletion, and linking. |
| `SettingsComponents.swift` | Visual sections and utility controls for configuration rows. |

---

#### `Subscription/`
The Pro monetization UI. Contains the glassmorphic purchase sheet, plan comparison, and StoreKit 2 purchase flow presentation.

| File | Responsibility |
|---|---|
| `PurchaseView.swift` | Crown features, subscription cards, and purchase action buttons. |
| `PurchaseComponents.swift` | Pricing grid layout and glassmorphic card wrappers. |

---

### `Resources/`
Asset catalogs, app icons, and localization files.

### `Preview Content/`
Assets used exclusively by Xcode Previews. Not included in production builds.

---

## Architectural Principles

1. **Unidirectional Data Flow**: `AppRouter` owns workspace state. `ProjectStore` owns node state. Views observe and never mutate state directly.
2. **No Blocking Main Thread**: Disk I/O and network requests should stay outside view bodies and main-actor interaction paths.
3. **Agentic Context Harvesting**: CoCaptain reads the *entire* spatial graph state before every prompt, ensuring grounded AI responses.
4. **Zero Core Dependencies**: Core logic (compilation, syntax highlighting) remains in pure Swift. Firebase is used exclusively for identity and AI.
5. **Type-Safe Everything**: `NodeAction`, `NodeRole`, `WorkspaceState`, and LLM/agent payloads are strict enums or structs.
