# Make It Remember

Make It Remember is the first learning mission for the Azzamification pivot.

## Mission Summary

The user starts with a tiny runnable Mini-App that has a button. The mission is to make the button remember how many times it has been tapped.

The learning concept is state.

The user-facing language should avoid leading with jargon. Start with the desire:

> Make this button remember how many times it was tapped.

Then reveal the concept:

> In software, the app's memory is called state.

## User Goal

The user should finish with a Mini-App that:

- shows a button or tappable control
- updates a visible count when tapped
- keeps the count in a named value while the app is running
- makes the connection between "remembering" and "state" clear

## Product Loop

1. Run the starter Mini-App and see the button.
2. Read the mission prompt on the canvas or in the Mini-App workspace.
3. Open CoCaptain or the Code tool.
4. Change the Mini-App so it tracks taps.
5. Preview the result.
6. Receive a short explanation from CoCaptain:
   - what changed
   - where the remembered value lives
   - why the screen updates after each tap
7. Mark the mission complete only after the user has seen the working preview.

## Use Existing Infrastructure

This mission should be built on the current CAOCAP foundation:

- Mini-App node for the runnable app
- SRS section for the intent of the mission
- Code section for HTML, CSS, and JavaScript
- Live preview for immediate feedback
- CoCaptain for guided help and explanation
- Review bundles for any AI-proposed code edits

Do not introduce a separate course engine for the first version. The first version should prove that the existing canvas and Mini-App model can carry learning.

## Acceptance Criteria

- A creative builder can understand the mission without knowing the word "state."
- The mission can be completed with one small code change.
- The live preview clearly shows whether the mission worked.
- CoCaptain explains state after the user has a reason to care.
- AI-generated changes remain human-reviewed before being applied.
- The mission feels like building a real tiny app, not filling out a worksheet.

## Open Implementation Notes

The first implementation can be as light as a mission template plus adjusted starter content. A fuller version can later add mission progress, completion state, and a mission picker.

Do not build a full curriculum until this first loop feels worth repeating.
