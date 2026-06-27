# Onboarding

First-run onboarding in CAOCAP is a three-phase funnel:

1. **Intro** (`Features/Intro/`) — motivational full-bleed story screens (`intro_completed_v1`).
2. **Personalization** (`PersonalizationOnboarding*.swift`) — one-question-per-screen survey saved locally and logged to Firebase Analytics (`personalization_survey_completed_v1`).
3. **Interactive tutorial** (`OnboardingCoordinator`) — gesture-driven tooltips on the live canvas (`onboarding_completed_v2`).

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

## Personalization survey

- Questions live in `PersonalizationOnboardingManifest.swift` (stable question/answer IDs for analytics).
- Answers persist via `UserProfileStore` as JSON in `UserDefaults` (`personalization_survey_answers_v1`).
- Analytics events are defined in `PersonalizationSurveyAnalytics` and sent through `AnalyticsService`.
- Skip shows a confirmation nudge before marking the survey complete with `wasSkipped = true`.

## Reset / testing

- `PersonalizationOnboardingCoordinator.reset()` clears completion and stored answers.
- Settings currently exposes tutorial reset only; personalization reset can be wired similarly when needed.
