# Repository guidance

## Project context

CAOCAP is a platform where people discover, build, and publish AI agents together. Its core experiences are Explore, Build, and Collaborate.

Read `README.md`, `docs/product-vision.md`, and the relevant sections of `docs/SRS.md` before implementing product behavior. Requirements describe planned capabilities and should not be treated as evidence of implemented functionality.

For iOS setup and service configuration, see `apps/ios/README.md`. For the macOS shell, see `apps/macos/README.md`.

## Structure and conventions

- `apps/ios/` and `apps/macos/` contain independent SwiftUI Xcode projects. Keep their internal `caocap/` paths intact when moving project folders.
- Other directories under `apps/` and `websites/landing/` are placeholders; no frameworks or shared services have been selected for them.
- Use lowercase names for new organizational directories. Preserve imported filenames and Xcode resource names.
- Keep app images, colors, and icons in the existing `Assets.xcassets` catalogs. Keep audio, localization, and other app resources in their existing resource folders. Shared brand artwork belongs in `assets/brand/`; research belongs in `docs/research/`.
- Consult the brand asset manifest (`assets/brand/cdl-v2/MANIFEST.md`) and research index (`docs/research/README.md`) before reusing imported material. Preserve source attribution and license notices in imported files.
- Update README links and documented paths when moving files. Keep planned and implemented functionality distinct in documentation.
- Follow the existing Swift and SwiftUI style. Add dependencies and shared abstractions only when a concrete feature needs them.

## Validation

Run commands from the repository root. Builds require full Xcode with SDKs supporting the projects' configured deployment targets; Command Line Tools alone are insufficient.

If the active developer directory points to Command Line Tools, prefix Xcode commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

```sh
# iOS simulator build without device signing
xcodebuild -project apps/ios/caocap/caocap.xcodeproj -scheme caocap -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/caocap-ios-build CODE_SIGNING_ALLOWED=NO build

# macOS build without signing
xcodebuild -project apps/macos/caocap/caocap.xcodeproj -scheme caocap -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/caocap-macos-build CODE_SIGNING_ALLOWED=NO build

git diff --check
```

The iOS project includes `caocapTests` and `caocapUITests`; macOS has no test target. For macOS UI changes, run the app on **My Mac** and check wake/tuck, CoCaptain/CoStar switch, drag, tap-to-toggle Agent chat, prompt entry and draft retention, and that the chat's Open CAOCAP button focuses the existing hub window. See `apps/macos/README.md` for the chat checks.

- For app changes, build the affected platform, run relevant tests, and check the changed flow when a simulator or device is available.
- For documentation and folder moves, verify links, project-relative paths, and asset references.
- Report validation results and any limitations accurately.
