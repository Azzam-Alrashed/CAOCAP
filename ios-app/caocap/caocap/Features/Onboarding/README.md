# Onboarding

First-run onboarding in CAOCAP is a three-phase funnel:

1. **Intro** (`Intro/`) — motivational full-bleed story screens (`intro_completed_v1`).
2. **Personalization** (`Personalization/`) — CDL co-pilot picker + one-question-per-screen survey.
3. **Interactive tutorial** (`Tutorial/`) — short **main tutorial** (3 required lessons) plus optional advanced lessons for replay.

## Folder layout

```
Features/Onboarding/
├── Intro/            # Full-bleed product tour after launch
├── Shared/           # Chrome shared by Intro + Personalization (top bar, back, CTA, glass, language)
├── Personalization/  # Co-pilot picker + survey scene, coordinator, and manifests
└── Tutorial/         # Interactive canvas walkthrough coordinator, manifests, and tooltips
```

`Shared/` is used by both `Intro/` and `Personalization/` for the shared top bar, back button, and primary CTA.

## Main tutorial (required first-run)

| Lesson | Steps | Outcome |
|---|---|---|
| **Canvas basics** | 7 | Keep the classic first lesson flow (Tutorial entry + FAB + CoCaptain welcome + dismiss + long-press) |
| **Game discovery** | 8 | Learn `go back`, find Pac-Man/XO, open a game canvas, request one small CoCaptain edit, review/apply |
| **Help & Docs** | 2 | Open Help and discover where to continue tutorials/docs |

First-run completion is now based on these three lessons only.

## Optional lessons (replay)

The following remain available from Help → **Interactive lessons**:

- **Mini-App Preview** (`coCaptainChat` lesson ID) — Hello World preview/code loop
- **Move & Organize** (`moveAndOrganize`) — pan/zoom/fit, drag, organize, undo/redo

Skipping still marks only the active lesson complete.

## Coordination notes

- `OnboardingLessonsManifest.mainLessonIDs` controls first-run completion.
- `OnboardingLessonsManifest.optionalLessonIDs` stays replay-only.
- `AppSessionCoordinator` prepares workspace context per lesson and handles onboarding completion events from command palette, CoCaptain review/apply, and Help guides.
- `onTutorialCompleted` still drives confetti/graduation moment.

## Analytics

Interactive tutorial events continue through `OnboardingAnalytics`:

- `onboarding_lesson_started`
- `onboarding_lesson_completed`
- `onboarding_lesson_skipped`
- `onboarding_step_completed`
- `onboarding_cocaptain_review_shown`
- `onboarding_cocaptain_review_applied`
- `onboarding_cocaptain_review_fallback`

## Reset / testing

- `PersonalizationOnboardingCoordinator.reset()` clears completion and stored answers.
- Settings → **Replay Personalization** calls `AppSessionCoordinator.restartPersonalization()`.
- Settings → **Restart Onboarding** resets intro, personalization, and tutorial.
- Playtest script: `docs/onboarding-first-session-playtest.md`
