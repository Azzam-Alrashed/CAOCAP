# First-session onboarding playtest (10 minutes)

Use this script with a curious non-developer. Do not coach unless they are blocked for more than 60 seconds.

## Setup

1. Settings → **Restart Onboarding**.
2. Complete intro + personalization without skipping.
3. Start interactive tutorial from root canvas.

## Main tutorial checks (3 lessons)

| # | Moment | Pass? | Notes |
|---|---|---|---|
| 1 | Completes classic Lesson 1 flow (Tutorial entry + FAB + CoCaptain welcome + dismiss + long-press) | | |
| 2 | Uses `go back` in omnibox and returns to root | | |
| 3 | Searches for Pac-Man or XO and flies to it | | |
| 4 | Opens selected game portal | | |
| 5 | Asks CoCaptain to rename the title, taps Apply All, sees confetti, then returns to the main canvas | | |
| 6 | Sees review card and taps Apply | | |
| 7 | Opens Help from command palette | | |
| 8 | Can point to Guides/docs/tutorial continuation in Help | | |
| 9 | Main tutorial completes without requiring optional lessons | | |

## Optional replay checks

| # | Moment | Pass? | Notes |
|---|---|---|---|
| A | Mini-App Preview lesson can be launched from Help | | |
| B | Move & Organize lesson can be launched from Help | | |
| C | Completing main tutorial does not auto-complete optional lessons | | |

## Debrief questions

1. How do you navigate between canvases?
2. How do you ask CoCaptain for a small change and keep control?
3. Where would you go for more tutorials next?

## Analytics spot-check (optional)

- `onboarding_lesson_started` / `completed` / `skipped`
- `onboarding_step_completed`
- `onboarding_cocaptain_review_shown`
- `onboarding_cocaptain_review_applied` or `onboarding_cocaptain_review_fallback`
