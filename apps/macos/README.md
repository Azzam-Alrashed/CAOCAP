# CAOCAP for macOS

SwiftUI app targeting macOS 26.5 or later. Requires full Xcode with a compatible macOS SDK.

## Setup

1. Open [caocap.xcodeproj](caocap/caocap.xcodeproj) in Xcode.
2. Select the `caocap` scheme and the **My Mac** destination.
3. Run with **Product → Run** or `Command-R`.

No Firebase or other service configuration is required for the current shell.

## What is implemented

- A single **CAOCAP** window (placeholder Hello World content).
- The CoCaptain porthole **app icon** and the cube-and-orbit **menu-bar** status item.
- A floating **CoCaptain** companion above other apps. Drag to move. Click to focus the existing window, or reopen it if it was closed. The menu bar can show or hide the companion.

Wake/tuck and companion position persist locally. Reduced Motion turns off the idle bob.

## What is not implemented

Explore, Build, and Collaborate are planned and not present on Mac. There is no canvas, CoCaptain chat, Firebase session, or agent-driven companion status. The Ready bubble is a placeholder.

The idle sprite in `caocap/Assets.xcassets/CoCaptainIdle.imageset` was knocked out from CDL art for a transparent desktop pet. Do not edit files under `assets/brand/` when changing app assets.

There is no test target. After Mac UI changes, run the app and check wake/tuck, drag, and window focus.
