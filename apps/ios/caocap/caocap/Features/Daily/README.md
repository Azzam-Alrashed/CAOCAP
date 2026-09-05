# Daily Feature

Daily challenges reward small, real Mini-App edits with iron, gold, and diamond badges, local XP, and confetti.

## Ownership

- `GamificationStore` owns XP, daily completion state, and challenge evaluation.
- `DailyChallengeDetector` inspects compiled Mini-App HTML for challenge completion.
- `ProjectStore` calls `evaluateMiniApps` after live preview compilation.
- `AppSessionCoordinator` wires challenge-completion callbacks (confetti + haptics).
- The protected **Daily** root node renders badge previews; its sheet shows full progress.

## Challenge catalog

1. **Iron** — change the page `<title>` away from the default `My App`.
2. **Gold** — change the Mini-App `background-color` away from `#0d0d0d`.
3. **Diamond** — add an `<img>` with a non-empty `src`.

Challenges reset at local midnight and complete once per day across the device.

## Verification

- Root canvas shows the Daily node between Tutorial and Activity.
- Editing any Mini-App code on the active canvas completes matching challenges automatically.
- Badges dim when incomplete and illuminate when complete; tap for description.
- Confetti plays once per newly completed challenge.
- XP and level appear in the Daily sheet and Profile header card.
