# Onboarding

First-run onboarding in CAOCAP is a three-phase funnel:

1. **Intro** (`Features/Intro/`) — motivational full-bleed story screens (`intro_completed_v1`).
2. **Personalization** (`PersonalizationOnboarding*.swift`) — CDL co-pilot picker + one-question-per-screen survey, saved locally and logged to Firebase Analytics (`personalization_survey_completed_v1`, survey version `v2`).
3. **Interactive tutorial** (`OnboardingCoordinator`) — gesture-driven tooltips on the live canvas (`onboarding_completed_v8`). Steps are grouped into five lessons (≤9 steps each) defined in `OnboardingLessonsManifest.swift`; each lesson has a unique accent color.

## Session 1 lesson order (v8)

| Lesson | Steps | Teaches |
|--------|-------|---------|
| **Canvas basics** | 5 | Tutorial portal, pan, pinch zoom, fit-all, open command palette |
| **Omnibox navigation** | 5 | Return to root, type go back, tap Go Back, fly to node, re-enter portal |
| **Mini-App preview** | 5 | Hello World node, live preview, code edit, save, return to canvas |
| **CoCaptain chat** | 7 | Open CoCaptain, guided edit prompt, review bundle, Apply, dismiss, long-press FAB |
| **Move & organize** | 4 | Drag node, organize nodes, undo, redo |

**North star:** spatial confidence → omnibox navigation → manual show-off win → CoCaptain review/apply trust → productivity gestures.

Skipping a lesson marks **only that lesson** complete and advances to the next incomplete lesson. Users can replay individual lessons from Help → **Interactive lessons**.

Completing all lessons triggers confetti, a graduation banner (“Your first app is on the canvas”), and Firebase Analytics events (`onboarding_lesson_*`, `onboarding_step_completed`, `onboarding_cocaptain_review_*`).

## Flow ownership

| Phase | Coordinator | Overlay in `ContentView` |
|-------|-------------|--------------------------|
| Intro | `IntroCoordinator` | `introOverlay` (zIndex 80) |
| Personalization | `PersonalizationOnboardingCoordinator` | `personalizationOverlay` (zIndex 75) |
| Tutorial | `OnboardingCoordinator` | `onboardingTooltipOverlay()` on canvas |

`AppSessionCoordinator` chains handoffs:

- `finishIntroFlow()` → shows personalization when needed
- `finishPersonalizationFlow()` → `onboarding.startIfNeeded()`
- `startInteractiveOnboardingIfNeeded()` — gates tutorial until intro **and** personalization are complete
- `onTutorialCompleted` → confetti + `TutorialGraduationBanner`

The tutorial begins on the root canvas. Lesson 1 opens the Tutorial portal, then teaches viewport gestures before any omnibox or CoCaptain work. **No LLM call runs until lesson 4** (CoCaptain guided edit).

## CoCaptain guided edit (lesson 4)

- Turn purpose: `.onboardingGuidedEdit` (agentic, human-in-the-loop).
- Steps: `chatCoCaptain` → `reviewCoCaptainChange` → `applyCoCaptainChange`.
- Offline fallback: `OnboardingCoCaptainReviewFixture` when the model cannot respond.
- See `Features/CoCaptain/README.md` for turn execution details.

## Personalization (v2)

**Step 1 — Co-pilot picker:** Choose Cocaptain or CoStar on a shared moon stage (CDL heroes + dark space backdrop with selection animation).

**Steps 2–6 — Survey:** Same five questions as v1 (stable question/answer IDs for analytics).

### Scene compositor

Personalization UI uses one coordinate space via `PersonalizationSceneView`:

1. **Backdrop** — `PersonalizationSpaceBackdrop` (sky + stars only)
2. **Moon** — `PersonalizationMoonStage` (full-bleed at screen bottom)
3. **Heroes** — `PersonalizationHeroLayer` (feet aligned to `MoonStageLayout` stand line)
4. **Content** — TabView pages with step content only (no heroes inside pages)
5. **Chrome** — top bar, progress, footnote, bottom bar; height measured via `PersonalizationBottomChromeHeightKey`

### Data and integration

- Manifest steps live in `PersonalizationOnboardingManifest.swift`.
- Answers persist via `UserProfileStore` (`personalization_survey_answers_v1`).
- Analytics: `PersonalizationSurveyAnalytics` + `OnboardingAnalytics`.
- Users who completed survey **v1** are re-presented personalization once to capture copilot choice.

## Session 2 hook

Help → **What's next?** (`HelpManifest.nextSteps`) points users toward turning Hello World into a mini game. Full session-2 build flow is out of scope for v8.

## Reset / testing

- `PersonalizationOnboardingCoordinator.reset()` clears completion and stored answers.
- Settings → **Replay Personalization** calls `AppSessionCoordinator.restartPersonalization()`.
- Settings → **Restart Onboarding** resets intro, personalization, and tutorial.
- Playtest script: `docs/onboarding-first-session-playtest.md`
