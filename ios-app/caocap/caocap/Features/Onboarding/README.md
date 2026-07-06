# Onboarding

First-run onboarding in CAOCAP is a three-phase funnel:

1. **Intro** (`Features/Intro/`) — motivational full-bleed story screens (`intro_completed_v1`).
2. **Personalization** (`PersonalizationOnboarding*.swift`) — CDL co-pilot picker + one-question-per-screen survey, saved locally and logged to Firebase Analytics (`personalization_survey_completed_v1`, survey version `v2`).
3. **Interactive tutorial** (`OnboardingCoordinator`) — opens through the Tutorial portal, then continues with gesture-driven tooltips on the live canvas (`onboarding_completed_v6`). Steps are grouped into three lessons (≤6 steps each) defined in `OnboardingLessonsManifest.swift`; each lesson has a unique accent color. The Canvas Navigation lesson starts in the Tutorial subcanvas with omnibox Go Back, then teaches pan, zoom, fit-all, omnibox fly-to, and portal entry on the root canvas. Skipped users can relaunch individual lessons from Help → **Interactive lessons**.

## Flow ownership

| Phase | Coordinator | Overlay in `ContentView` |
|-------|-------------|----------------------------|
| Intro | `IntroCoordinator` | `introOverlay` (zIndex 80) |
| Personalization | `PersonalizationOnboardingCoordinator` | `personalizationOverlay` (zIndex 75) |
| Tutorial | `OnboardingCoordinator` | `onboardingTooltipOverlay()` on canvas |

`AppSessionCoordinator` chains handoffs:

- `finishIntroFlow()` → shows personalization when needed
- `finishPersonalizationFlow()` → `onboarding.startIfNeeded()`
- `startInteractiveOnboardingIfNeeded()` — gates tutorial until intro **and** personalization are complete

The tutorial begins on the root canvas. Its first tooltip points to the stable
Tutorial portal; opening that subcanvas advances into the existing FAB, Omnibox,
CoCaptain, dismiss, long-press, and canvas navigation practice steps. The navigation lesson begins with omnibox Go Back from the Tutorial subcanvas, then continues on the root canvas with pan, pinch, fit-all, omnibox fly-to, and portal entry.

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

Hero stand-line Y uses asset geometry plus measured bottom chrome — no hardcoded bar heights.

### Data and integration

- Manifest steps live in `PersonalizationOnboardingManifest.swift` (`steps[]`: copilot picker + survey questions).
- Answers and `selectedCopilot` persist via `UserProfileStore` as JSON in `UserDefaults` (`personalization_survey_answers_v1`).
- Chat avatars read the saved copilot via `CopilotAvatarView` (`CopilotPersona` in `Models/CopilotPersona.swift`).
- Analytics events are defined in `PersonalizationSurveyAnalytics` (includes `personalization_copilot_selected`).
- Skip shows a confirmation nudge before marking the survey complete with `wasSkipped = true`.
- Users who completed survey **v1** are re-presented personalization once to capture copilot choice.

## Reset / testing

- `PersonalizationOnboardingCoordinator.reset()` clears completion and stored answers.
- Settings → **Replay Personalization** calls `AppSessionCoordinator.restartPersonalization()`.
- Settings → **Restart Onboarding** resets intro, personalization, and tutorial.
