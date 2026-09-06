# Onboarding

First-run onboarding in CAOCAP is a two-phase funnel:

1. **Intro** (`Intro/`) — motivational full-bleed story screens (`intro_completed_v1`).
2. **Personalization** (`Personalization/`) — CoCaptain / CoStar (and related) persona pick.

The interactive tutorial **engine** stays in `Tutorial/` (coordinator, popovers, tooltip anchors, confetti). There is currently **no lesson catalogue** — first-run does not start or complete a tutorial.

## Folder layout

```
Features/Onboarding/
├── Intro/            # Full-bleed product tour after launch
├── Shared/           # Reusable first-run chrome
├── Personalization/  # Persona pick and completion coordinator
└── Tutorial/         # Walkthrough engine without a current curriculum
```

## Reset / testing

- `PersonalizationOnboardingCoordinator.reset()` clears placeholder completion and any legacy stored answers.
- Settings → **Replay Personalization** calls `AppSessionCoordinator.restartPersonalization()`.
- Settings → **Restart Onboarding** resets intro and personalization.
