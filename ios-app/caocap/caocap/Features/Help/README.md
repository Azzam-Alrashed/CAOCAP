# Help Feature

In-app help center for tutorials, Omnibox shortcut reference, and getting-started guides.

## Ownership

- `HelpManifest` owns static section content (tutorials, shortcuts, articles).
- `HelpView` renders the sheet; navigation side effects are passed in as closures from `AppSessionCoordinator`.
- `HelpArticleView` renders long-form guide pages pushed from the help list.
- Entry points: Omnibox `AppActionID.help` and the root canvas Help node (`NodeAction.openHelp`).

## Editing Guidance

- Add tutorial rows, shortcut examples, or articles in `HelpManifest.swift`.
- Add matching keys to `Localizable.xcstrings` for English and Arabic.
- Wire new tutorial actions through `HelpView` callbacks and coordinator helpers in `AppSessionCoordinator`.
