# Help Feature

In-app help center for getting-started guides. The tutorial engine still exists; the lesson catalogue is empty.

## Ownership

- `HelpManifest` owns static section content (tutorials and articles).
- `HelpView` renders the sheet; navigation side effects are passed in as closures from `AppSessionCoordinator`.
- `HelpArticleView` renders long-form guide pages pushed from the help list.
- Entry points: leftover canvas Help nodes (`NodeAction.openHelp`) and CoCaptain requesting `AppActionID.help`.

## Editing Guidance

- Add tutorial rows or articles in `HelpManifest.swift`.
- Add matching keys to `Localizable.xcstrings` for English and Arabic.
- Wire new tutorial actions through `HelpView` callbacks and coordinator helpers in `AppSessionCoordinator`.
