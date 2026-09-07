# iOS Home and navigation redesign

Status: agreed foundation implemented. Wizard content, acquisition, communities, and mind map / flowchart behavior remain TBD.

## Agreed experience

- Navigation uses the native iOS bottom tab bar (SwiftUI `TabView`) on both iPhone and iPad: Explore, Home, Communities, with Home selected on launch.
- Tabs display icons only; accessibility labels retain the Explore, Home, and Communities names.
- Home is an agent library, displayed as a grid of avatars and names, with a Create agent button.
- CoCaptain and CoStar are included by default and can be removed. When no agents remain, Home prompts users to create or explore agents.
- Tapping an agent opens its own full-screen Workspace. Top and bottom navigation bars are hidden; a native glass back button floats at the top-leading corner of the canvas and returns to Home.
- The Workspace contains the agent's canvas and FAB for chat and capabilities. The intended mind map and flowchart appearance and behavior are TBD.
- Create agent opens a wizard. Its steps and content are TBD.
- Explore is for discovering and acquiring agents and joining their communities, independently or together. Acquired agents will appear on Home.
- Communities is the name of the collaboration tab: community participation and building agents together.
- The avatar at the top-right of Home opens Profile; Settings is accessible from Profile.

## Implementation sequence

1. Add a local agent library with stable identities and Workspace filenames. Seed CoCaptain and CoStar only when no library has been saved; preserve intentional empty libraries on relaunch. Remove from Home through a card menu, without deleting Workspace files or conversation history.
2. Introduce the native three-tab shell and Home grid, including profile entry, Create agent entry, and the empty state. Explore and Communities receive honest unfinished destinations, without fabricated listings or membership actions.
3. Open the existing canvas inside an agent-specific full-screen Workspace with an explicit Back to Home button. Keep existing canvas editing as the temporary surface; do not implement mind map or flowchart semantics. Bind canvas, chat history, draft, undo history, and FAB persona to the selected agent. Reset shared model history on re-entry and replay only the selected agent's transcript. Hide the FAB outside Workspaces and end an active call when leaving.
4. Wire Profile to the existing Settings screen. Add a dismissible wizard destination that clearly states setup is not available yet; do not invent questions or create incomplete agents.
5. Validate with an iOS simulator build, focused library/session tests, and simulator UI checks for navigation, Workspace isolation, chat, profile/settings, wizard dismissal, removal, empty state, and relaunch persistence. Update iOS documentation with implemented and pending capabilities.

## Open decisions and deferred behavior

- Wizard steps, validation, and agent creation data.
- Explore layout, agent detail journey (suggested but not yet agreed), acquisition semantics, access rights, and backend.
- Communities layout, membership, joint editing, and its relationship to individual Workspaces.
- Mind map and flowchart design, editing permissions, and execution.
- Cloud sync, remote Mac tasks, and CAOCAP-owned macOS access.

These remain design work. Placeholder destinations establish navigation only and must not imply these capabilities work.

## Acceptance checks

- Fresh library shows both default agents; Home is the initial tab.
- Grid supports smaller screens, larger text, and accessible button labels.
- Each agent opens a distinct saved canvas and conversation context, with the correct agent avatar/name and no bottom tabs.
- Back restores Home and removes FAB/call hit targets. Chat drafts and canvas content survive switching agents.
- Create opens the unfinished wizard; Cancel returns without adding an agent.
- Removing both defaults shows Create and Explore actions and remains empty on relaunch.
- Profile and Settings are reachable without canvas cards.
- Explore and Communities are reachable and visibly unfinished; no fake acquisition, creation, or community backend is presented.

## Validation results

- iOS simulator build passed with Xcode 26.6, SDK 26.5, and signing disabled.
- 26 focused unit tests passed: library defaults/removal/restoration, agent routing, saved canvas separation, draft and undo separation, delayed chat presentation, shared model context reset/replay, and conversation archive persistence.
- Both iPhone UI tests passed: the complete Home journey and maximum accessibility text layout.
- The iPad Pro 11-inch accessibility layout and navigation check passed, including native bottom tabs in portrait and landscape, tab switching, Workspace entry/return, and wizard dismissal.
- Visual inspection confirmed the normal Home grid, full-screen Workspace, empty Home, and large-text layouts on iPhone and iPad.
- Fixed an existing nested tooltip overlay that duplicated the root UI; the reusable tooltip infrastructure remains.
- Documentation links and `git diff --check` pass.

Validation covers local UI and state. Live Firebase responses, authentication, voice/video services, and remote Mac execution were not verified; the unsigned simulator reports Firebase keychain entitlement errors. No acquisition, community backend, or functional wizard is claimed.
