# Onboarding

First-run onboarding in CAOCAP is a three-phase funnel:

1. **Intro** (`Intro/`) — motivational full-bleed story screens (`intro_completed_v1`).
2. **Personalization** (`Personalization/`) — temporary placeholder preserving the handoff to the upcoming redesigned flow.
3. **Interactive tutorial** (`Tutorial/`) — one gesture lesson on the root canvas.

## Folder layout

```
Features/Onboarding/
├── Intro/            # Full-bleed product tour after launch
├── Shared/           # Reusable first-run chrome
├── Personalization/  # Temporary placeholder view and completion coordinator
└── Tutorial/         # Interactive canvas walkthrough coordinator, manifests, and tooltips
```

## Main tutorial (required first-run)

| Lesson | Steps | Outcome |
|---|---|---|
| **Open your mini-app** | 1 (`openPortal`) | Tap Hello World on root to enter fullscreen preview |

First-run completion is based on this single main lesson (`OnboardingLessonsManifest.mainLessonIDs`).

Replay remains available from Help → **Interactive lessons** and **Restart interactive tutorial**.

## Coordination notes

- `OnboardingLessonsManifest.mainLessonIDs` controls first-run completion and the Help lessons list.
- `AppSessionCoordinator` prepares the root workspace and completes the open step when Hello World goes fullscreen.
- Confetti / graduation banner render in the top chrome window (`GlobalFloatingChromeController`).
- `onTutorialCompleted` still drives the celebration moment.

## Analytics

Interactive tutorial events:

- `onboarding_lesson_started`
- `onboarding_lesson_completed`
- `onboarding_lesson_skipped`
- `onboarding_step_completed` (`step_id` is the stable step name string, e.g. `openPortal`)

## Reset / testing

- `PersonalizationOnboardingCoordinator.reset()` clears placeholder completion and any legacy stored answers.
- Settings → **Replay Personalization** calls `AppSessionCoordinator.restartPersonalization()`.
- Settings → **Restart Onboarding** resets intro, personalization, and tutorial.
