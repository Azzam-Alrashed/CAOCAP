# iOS pivot: strip the mini-app product

Living plan for turning the imported iOS app into a shell that matches Explore / Build / Collaborate. This is not a product-requirements document. Do not treat leftover code as an approved feature.

**Decision:** Keep the spatial canvas, CoCaptain chat, sign-in, and the Pro **purchase screen**. Home is an empty canvas (no launch cards). Remove the mini-app stack (HTML nodes, live preview, GitHub Pages, daily XP, game demos).

**How we work**

- One phase at a time. Each phase leaves the app able to build.
- After each phase: what changed, how to try it, what is next. We stop unless you say to continue.
- Commit only when you ask.
- macOS stays independent. We do not port the desktop companion.

| Keep | Remove |
| --- | --- |
| App shell, theme, language, settings | Mini-app nodes, HTML / SRS / code editors |
| Sign-in (Firebase Auth) | Live web preview and Firebase-inside-the-webview |
| Canvas: pan, zoom, nodes, connections, save / undo | GitHub Pages publish |
| CoCaptain / CoStar chat and personas | Pac-Man, XO, mini-app tutorial canvases |
| Help / profile / app icon (trimmed) | Daily challenges, XP, gamification |
| Pro purchase screen (Settings / Profile / CoCaptain upgrade) and usage limits | Home launch cards |

Mindmaps, flowcharts, Explore, Collaborate, and agent-version publish are **new work after this plan**. They are not hidden inside the old code.

---

## Phase 1 — Quiet the home canvas

**Status:** Done

Home is an empty canvas. No launch cards. There are no users, so we did not migrate saved homes — we only changed the default.

- `RootCanvasProvider.nodes` is empty.
- Default home zoom is `0.22` so the space sketch is visible.
- Startup no longer runs the old home-layout migration (it crashed on the empty grid).
- Settings, Profile, Help, App Icon, sign-in, and CoCaptain stay reachable from the HUD, FAB / command palette, and existing sheets.
- The purchase screen stays reachable from Profile / Settings and from CoCaptain when usage hits the free-tier limit.

**You should see:** On a fresh run, Home is blank except the HUD and FAB. You can still pan and zoom. Opening CAOCAP Pro from Profile still shows the paywall. If a simulator still shows the old cards, delete the app and run again. Simulator leftovers can also skip Intro (`intro_completed_v1` outside the app container); erase the simulator if that happens.

**Not in this phase:** Deleting feature folders. Mini-app editors can still exist in code.

---

## Phase 2 — Close the mini-app workspace

**Status:** Done  
**Depends on:** Phase 1

Stop treating a node tap as “open an HTML app.”

- Tapping a leftover mini-app node inspects the card. It no longer opens preview, SRS, Code, Firebase, or Publish.
- Sub-canvas portals and settings-style action nodes still work.
- The store no longer compiles live HTML previews in the background. Editor files stay on disk until Phase 3.

**You should see:** Nodes are cards. There is no in-app web editor or publish sheet.

---

## Phase 3 — Delete publish, preview, and demo canvases

**Status:** Done  
**Depends on:** Phase 2

Deleted the unused mini-app stack and its tests.

- Removed GitHub Pages publish, live-preview compiler, mini-app editor views, and creation limits.
- Removed Pac-Man / XO / tutorial canvas providers and the unused home-layout migration that seeded them.
- Removed leftover Home IDs and `gridPosition` layout math from `RootCanvasProvider`.
- Deleted tests that only covered that stack. Remaining tests still compile.

**You should see:** Same UI as Phase 2. Those folders are gone. The iOS target still builds.

---

## Phase 4 — Delete daily challenges and XP

**Status:** Done
**Depends on:** Phase 3

Removed Daily UI and gamification services.

- Deleted the Daily sheet, badge row, Profile level card, and challenge evaluation after a save.
- Saves still record Activity history. Confetti still plays for tutorial graduation.
- Command palette, Help, and leftover `openDaily` nodes no longer open a Daily sheet. Old saved Daily actions decode as unused.
- Deleted those tests and the iron / gold / diamond badge assets.

**You should see:** No daily sheet, no level card, no challenge evaluation after a save.

---

## Phase 5 — Keep Pro; detach it from mini-app publish

**Status:** Done
**Depends on:** Phase 4

The purchase screen stays. The Home crown node is already gone from Phase 1. Old Pro unlocked GitHub Pages publish and CoCaptain usage. Publish is already gone.

- Kept `PurchaseView`, `SubscriptionManager`, and the Settings / Profile / CoCaptain upgrade paths.
- Kept CoCaptain usage limits behind Pro.
- Removed leftover “publish a mini-app” and “unlimited Mini-Apps” paywall copy. Did not add a new store or change prices. Did not put Pro back on the canvas.

**You should see:** Profile → CAOCAP Pro still opens the paywall. CoCaptain still respects the subscription. Home has no crown node. Nothing asks you to subscribe in order to publish a website.

---

## Phase 6 — First run without the mini-app tutorial

**Status:** Done
**Depends on:** Phase 5

- Intro and persona pick (CoCaptain / CoStar) stay.
- Kept the tutorial engine (coordinator, popovers, tooltip anchors, confetti). Cleared the lesson list so first-run does not start or complete a walkthrough.
- Help and Settings no longer restart those lessons. Removed the Mini-Apps Help article and trimmed leftover Hello World / demo-canvas copy.

**You should see:** New users reach Home after intro + persona. No required mini-app lesson.

---

## Phase 7 — Drop mini-app from the data model

**Status:** Done
**Depends on:** Phase 6

There are no users, so we did not migrate saved mini-app homes. New saves do not write HTML / SRS.

- Creating a node now makes an ordinary card (`.standard`), not a Mini-App.
- Saves omit the `miniApp` payload. Leftover `miniApp` nodes decode as ordinary cards; extra fields are ignored.
- In-memory Mini-App helpers stay for CoCaptain until Phase 8. Save / undo / viewport still work.

**You should see:** Create a node, quit, reopen: position and title remain. No HTML / SRS fields.

---

## Phase 8 — CoCaptain chats; it does not edit HTML

**Status:** Done
**Depends on:** Phase 7

CoCaptain still talks. It no longer offers HTML or SRS patches.

- Kept conversation UI, personas, and the sign-in-aware session.
- Parser, tools, prompts, and review staging drop `node_edit` / `propose_node_edit` HTML and SRS proposals.
- Leftover HTML-edit review items conflict instead of applying.
- Canvas actions such as create / move a node can still go through review.
- Deleted or updated tests that only covered HTML patch / review.

**You should see:** CoCaptain talks. It does not offer “apply this HTML change.”

---

## Phase 9 — Docs match the leftover app

**Status:** Done
**Depends on:** Phase 8

- Updated iOS setup notes, canvas / session / CoCaptain READMEs, and the SRS current-state iOS row.
- Did not add companion or mini-app requirements. Explore / Build / Collaborate stay planned.

**You should see:** README and `apps/ios/README.md` describe a canvas + CoCaptain + sign-in shell, not a mini-app studio.

---

## Phase 10 — Delete leftover Mini-App types and SRS

**Status:** Done
**Depends on:** Phase 9

Phase 8 left Mini-App / SRS types in memory so old reviews could decode. There are no users. This phase removes that leftover.

- Drop `NodeType.miniApp` and `NodeRole.miniApp`. Leftover files with `type: "miniApp"` still open as ordinary cards.
- Delete the unused SRS scaffold / readiness evaluator, Hello World HTML template, and Firebase preview helper.
- Cards no longer have a Mini-App size or role. CoCaptain leftover HTML-patch types stay only so old review JSON can decode; they still do not apply HTML.

**You should see:** Same leftover app. Create a card, quit, reopen. No Mini-App type, no Hello World HTML, no SRS helper.

---

## Phase 11 — Delete leftover Mini-App tutorial steps and HTML-patch types

**Status:** Done
**Depends on:** Phase 10

The tutorial engine stays. Mini-App preview lessons and unused CoCaptain HTML-patch types go.

- Remove empty Mini-App preview / code-editor tutorial steps and tooltip anchors.
- Remove the unused omnibox Mini-App preview tools.
- Delete `NodePatchEngine`, `NodeEditToolsFeature`, HTML-patch types, and the leftover patch-match picker. Clarifying questions and canvas-action review stay.
- Leftover HTML-edit review items, if any, fail decode and are skipped. Extra JSON keys on remaining review items are ignored.

**You should see:** Same leftover app. CoCaptain still talks and can request canvas actions. No Mini-App preview lesson. No HTML-patch types.

---

## Phase 12 — Rewire the FAB; delete leftover command palette

**Status:** Done
**Depends on:** Phase 11

iOS leftover cleanup: rewire the FAB and delete the command palette. This is not Build mindmaps, Explore, or Collaborate.

- FAB tap and ⌘J: if no listed sheet is open, open CoCaptain / CoStar chat as a SwiftUI sheet at large. If any listed sheet is already open, close them all.
- Listed sheets: chat, Settings, Profile, Help, sign-in, Pro, usage, checkpoints, share, Activity, app icon, copilot picker.
- HUD, voice / video call, launch, intro, and confetti are overlays, not sheets. They stay.
- On iPad, chat is a sheet like iPhone. Remove the inspector-column presentation.
- Long-press FAB still opens the radial menu (Chat / Voice / Video). Drag still moves the FAB. Long-press never skips the menu.
- The Chat bubble opens chat at medium. If a listed sheet is already up, the chat sheet replaces it.
- Tutorial steps that need chat open the sheet at large. Delete palette-only tutorial steps and tooltip anchors. Keep tapFAB (open chat), longPressFAB (radial menu), and CoCaptain-sheet steps.
- Delete the command palette / OmniBox UI. No replacement launcher. Delete `Features/Omnibox/`, palette tests, and palette-only search (for example `NodeSearchIndex` if only the palette uses it).
- Delete pin / "Add to canvas" shortcut cards, leftover summon / shortcut canvas cards, app action `showActionsList`, the OmniBox Help article, and the "Omnibox shortcuts" block.
- Keep `AppActionDispatcher` and `CommandIntentResolver` so CoCaptain can still request actions from chat (open Settings, create a card, go back, organize).
- Keep Voice / Video on the radial menu. Keep undo / redo keyboard shortcuts. Remove ⌘K (it opened the palette).
- Settings, Profile, Help, and Pro may have no dedicated button after this. That is accepted for now.

**You should see:** FAB tap or ⌘J opens chat at large, or closes listed sheets if one is already open. Long-press still shows Chat / Voice / Video. No command palette. No ⌘K. iPad chat is a sheet. CoCaptain can still request actions from chat.

---

## After this plan

This leftover strip ends at Phase 12. Only then do we add new product behavior, starting with Build: mindmap nodes and connections on the canvas we kept.

## Checks after every phase

1. iOS simulator build (see `AGENTS.md`).
2. Run the tests that still exist.
3. In the simulator: launch, Home (no crown node), Settings, sign-in sheet, Profile → CAOCAP Pro (paywall), CoCaptain.
4. `git diff --check`.
