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

**Status:** Not started  
**Depends on:** Phase 7

- Keep conversation UI, personas, and sign-in-aware session.
- Remove SRS / code patch proposals and review flows that only existed for mini-apps.
- Canvas actions such as create / move a node can stay if they still compile.

**You should see:** CoCaptain talks. It does not offer “apply this HTML change.”

---

## Phase 9 — Docs match the leftover app

**Status:** Not started  
**Depends on:** Phase 8

- Update iOS setup notes, canvas / session READMEs, and the SRS current-state row.
- Do not add companion or mini-app requirements. Keep Explore / Build / Collaborate marked planned.

**You should see:** README and `apps/ios/README.md` describe a canvas + CoCaptain + sign-in shell, not a mini-app studio.

---

## After this plan

Only then do we add new product behavior, starting with Build: mindmap nodes and connections on the canvas we kept.

## Checks after every phase

1. iOS simulator build (see `AGENTS.md`).
2. Run the tests that still exist.
3. In the simulator: launch, Home (no crown node), Settings, sign-in sheet, Profile → CAOCAP Pro (paywall), CoCaptain.
4. `git diff --check`.
