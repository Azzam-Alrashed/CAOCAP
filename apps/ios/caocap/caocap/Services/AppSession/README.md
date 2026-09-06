# App Session

Owns root-level session orchestration for the leftover canvas + CoCaptain + sign-in shell: workspace routing hooks, global sheet flags, and `AppActionDispatcher` registration. Home is an empty canvas. Explore, Build, and Collaborate are planned and are not wired here.

## Ownership

- `AppSessionCoordinator` is the single session owner created by `ContentView`.
- `AppRouter` (in `Navigation/`) still owns workspace navigation and `ProjectStore` instances.
- `AppActionDispatcher` (in `Services/AppActions/`) still owns action definitions; the coordinator registers handlers that mutate session/UI state.
- `App/Shell/` contains SwiftUI modifiers and helpers that bind to the coordinator without adding business rules.
- The Activity node sets `showingActivity`; `AppSheetsModifier` presents the
  feature-owned expanded activity sheet.

## Editing Guidance

- Add new global sheets or presentation flags to `AppSessionCoordinator`, then wire them in `App/Shell/AppSheetsModifier.swift`.
- Add new app-level actions by registering handlers in `AppSessionCoordinator.configureActions()` and exposing them through the dispatcher.
- Keep feature-specific UI in `Features/*`; keep cross-cutting session wiring here.
- When onboarding or CoCaptain presentation rules grow, prefer extracting focused helpers over expanding the coordinator indefinitely.
- First-run handoffs: `finishIntroFlow()` → persona pick; `finishPersonalizationFlow()` → Home. The tutorial engine still exists, but the lesson catalogue is empty so first-run does not start a walkthrough.

## Related Tests

- `caocapTests/AppSession/AppSessionCoordinatorTests.swift`
