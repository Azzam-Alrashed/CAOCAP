# First-session onboarding playtest (10 minutes)

Use this script with a **curious non-developer** on a physical device or simulator. Do not coach unless they are stuck for more than 60 seconds.

## Setup

1. Settings → **Restart Onboarding** (or fresh install).
2. Complete intro + personalization without skipping (note total time).
3. Start the interactive tutorial on the root canvas.

## Observe (tick when seen)

| # | Moment | Pass? | Notes |
|---|--------|-------|-------|
| 1 | Opens Tutorial portal without confusion | | |
| 2 | Pans, pinches, and double-taps to fit-all confidently | | |
| 3 | Opens command palette from FAB | | |
| 4 | Types “go back”, taps Go Back row, returns to root | | |
| 5 | Searches/flys to Tutorial, re-enters subcanvas | | |
| 6 | Opens Hello World, interacts with live preview | | |
| 7 | Edits code, saves, sees visible change in preview | | |
| 8 | Opens CoCaptain, sends guided prompt (or quick prompt) | | |
| 9 | Sees review card; understands they must tap Apply | | |
| 10 | Preview updates after Apply | | |
| 11 | Completes organize/undo lesson | | |
| 12 | Sees graduation confetti + “Your first app is on the canvas” | | |

## Debrief questions

1. In one sentence, what is the canvas?
2. How do you get back to the previous canvas?
3. What is the difference between editing code yourself and using CoCaptain?
4. What would you try next without help?

## Success criteria (north star)

Participant can articulate:

- Moving around the canvas (pan/zoom/fit, portals)
- Using the omnibox to navigate
- Making a manual edit and seeing it live
- Reviewing and applying a CoCaptain suggestion themselves

## Friction log

| Step ID | Issue | Severity (1–3) |
|---------|-------|----------------|
| | | |

## Analytics spot-check (optional)

Confirm Firebase DebugView shows:

- `onboarding_lesson_started` / `completed` per lesson
- `onboarding_step_completed` with `step_id`
- `onboarding_cocaptain_review_shown` and `onboarding_cocaptain_review_applied` (or `failed_fallback` if offline)

## Out of scope for session 1

- Mini game build
- Portfolio / export
- Auth or subscription flows
- Root demo canvases (Pac-Man, XO) unless participant explores voluntarily
