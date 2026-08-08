# Onboarding

First-run onboarding in CAOCAP is a three-phase funnel:

1. **Intro** (`Intro/`) — motivational full-bleed story screens (`intro_completed_v1`).
2. **Personalization** (`Personalization/`) — temporary placeholder preserving the handoff to the upcoming redesigned flow.
3. **Interactive tutorial** (`Tutorial/`) — one short gesture lesson on the root canvas.

## Folder layout

```
Features/Onboarding/
├── Intro/            # Full-bleed product tour after launch
├── Shared/           # Reusable first-run chrome
├── Personalization/  # Temporary placeholder view and completion coordinator
└── Tutorial/         # Interactive canvas walkthrough coordinator, manifests, and tooltips
```

The placeholder keeps the existing completion key and session handoff so it can be replaced without changing the surrounding flow.

## Main tutorial (required first-run)

| Lesson | Steps | Outcome |
|---|---|---|
| **Open your mini-app** | 1 | Tap Hello World on root to enter fullscreen preview |

First-run completion is based on this single main lesson (`OnboardingLessonsManifest.mainLessonIDs`).

Replay remains available from Help → **Interactive lessons** and **Restart interactive tutorial**.

## Coordination notes

- `OnboardingLessonsManifest.mainLessonIDs` controls first-run completion and the Help lessons list.
- `AppSessionCoordinator` prepares workspace context per lesson and completes the open step when Hello World goes fullscreen.
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

- `PersonalizationOnboardingCoordinator.reset()` clears placeholder completion and any legacy stored answers.
- Settings → **Replay Personalization** calls `AppSessionCoordinator.restartPersonalization()`.
- Settings → **Restart Onboarding** resets intro, personalization, and tutorial.
