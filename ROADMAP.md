# Ficruty Project Roadmap

This document tracks the current product milestones for Ficruty (caocap). The near-term priority is to keep the shipped iOS app stable while deepening the spatial, agentic workflow.

---

## Phase 0: MVP — First User *(Released on the App Store)*
*Focus: The minimum viable experience that is stable, polished, and shippable.*

- [x] **Spatial Canvas**: Infinite grid with gesture-driven pan, zoom, and 30% default entry zoom.
- [x] **Project Management**: Create, persist, and navigate named projects via the Home workspace.
- [x] **Omnibox / Command Palette**: `Cmd+K` intent-driven command palette with spatial search.
- [x] **Node Linking**: Visual Bezier-curve connections between nodes (1-to-N directed graph).
- [x] **Live Preview WebView**: 9:16 `WKWebView` node with full-screen immersive sheet.
- [x] **Native Code Editors**: Syntax-highlighted unified `CodeEditorView` for the Code node + SRS Zen Mode editor.
- [x] **Live Compilation Engine**: Real-time `SRS -> Code -> WebView` rendering, debounced at 500ms, with legacy HTML/CSS/JS project support.
- [x] **Monetization (Pro)**: StoreKit 2 subscription integration.
- [x] **Firebase Integration**: Authentication (Apple, Google, GitHub) and AI Logic infrastructure.
- [x] **App Store Compliance**: Privacy Policy, Terms of Service, data usage declarations.
- [x] **App Store Release**: Ficruty is available to users through the App Store.

### Post-Launch Polish

- [x] **Onboarding Polish**: Continue refining the guided first-run experience after launch.
    - [x] **Tutorial Manifest**: Create a `tutorial.json` with pre-placed learning nodes.
    - [x] **Spatial Markers**: Implement animated focus rings to highlight UI elements during steps.
    - [x] **Gesture Gates**: Add logic that unlocks the next step only after a specific pan/zoom/tap action.
- [ ] **Post-Launch Feedback Loop**: Make user support, issue triage, and release follow-up part of the product rhythm.
- [ ] **Release Hardening**: Re-check account deletion, privacy links, subscriptions, restore purchases, onboarding reset, and first project creation after each App Store update.

---

## Phase 1: Agentic Intelligence *(Current)*
*Focus: Integrating AI deeply into the spatial workflow to enable true "Vibe Coding."*

- [x] **Firebase Auth**: Secure login and anonymous account linking for seamless cross-device persistence.
- [x] **CoCaptain UI**: A polished, floating AI sidekick panel with glassmorphic design.
- [x] **Context Engine**: Logic to "harvest" the current canvas state (nodes, connections) via `ProjectContextBuilder`.
- [x] **Project Analysis**: Auto-analysis of canvas to suggest missing code, preview, or next build steps.
- [x] **The "Apply" Flow**: A UI interaction to preview and inject AI-generated code directly into a selected node.
- [x] **Multi-turn Chat**: Persistent conversation memory with scroll position preservation.
- [x] **Streaming UI**: Token-aware text view powered by Firebase AI Logic SDK.
- [x] **Agentic Actions**: Implementation of `AppActionDispatcher` to allow the AI to control app navigation and project state.
- [x] **Code Generation**: CoCaptain generates single-file app code from a natural language SRS node.
- [ ] **Intent-to-Node**: Transform a natural language prompt directly into a fully wired node graph.
- [ ] **Agent Contract Hardening**: Keep parser, validator, dispatcher, patching, and review-bundle behavior covered by focused tests as contracts evolve.

---

## Phase 2: The Code Runtime *(Next)*
*Focus: Making the spatial canvas a true execution environment.*

- [/] **Omnibox Canvas Search**: Search-to-fly functionality.
    - [x] **Search Index**: Rank node matches by title and text content.
    - [x] **Flight Engine**: Fly the viewport to a selected node from command palette search.
    - [ ] **Focus Zoom**: Automatically adjust zoom level to fit the targeted node perfectly.
- [ ] **Spatial Debugger**: Visualize variable flow, console output, and execution state as canvas overlays.
- [ ] **Console Node**: A dedicated node type that captures `console.log` output from the WebView in real-time.
- [ ] **Project Templates**: A library of starter templates (games, landing pages, tools) selectable from the Omnibox.
- [ ] **File System Bridge**: Export projects as a standard HTML/CSS/JS file bundle or a Git repository.
- [ ] **Snapshot Browser**: Expose saved project checkpoints in the UI so users can inspect and restore prior states.

---

## Phase 3: Collaborative Ecosystem
*Focus: Bringing developers together in shared spatial environments.*

- [ ] **Real-time Collaboration**: Multi-user spatial canvases with presence indicators and shared agentic history.
- [ ] **Cloud Sync**: iCloud-backed project persistence across devices.
- [ ] **Plugin System**: Allow third-party developers to create custom node types and agent behaviors.
- [ ] **Share Sheet**: Export a project as a shareable, self-contained `.ficruty` bundle.

---

> [!NOTE]
> This roadmap is a living document. As we "vibe code" and discover new possibilities, these milestones will evolve. The phases are ordered by user impact, not technical complexity.
