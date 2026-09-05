# Repository guidance

## Project context

CAOCAP is an AI digital career mentor at the scaffolding stage. Read `README.md`, `docs/product-vision.md`, and the relevant sections of `docs/SRS.md` before implementing product behavior. Requirements describe planned capabilities; only the iOS and macOS starter apps currently run.

## Structure and conventions

- `apps/ios/` and `apps/macos/` contain independent SwiftUI Xcode projects. Keep their internal `caocap/` paths intact when moving project folders.
- Other directories under `apps/` and `websites/landing/` are placeholders; no frameworks or shared services have been selected for them.
- Use lowercase names for new organizational directories. Preserve imported filenames and Xcode resource names.
- Keep runtime Apple assets inside the app's `Assets.xcassets`. Shared brand artwork belongs in `assets/brand/`; research belongs in `docs/research/`.
- Consult the asset and research indexes before reusing imported material. Preserve source attribution and the license recorded in `docs/imported-assets.md`.
- Update README links and documented paths when moving files. Keep planned and implemented functionality distinct in documentation.
- Follow the existing Swift and SwiftUI style. Add dependencies and shared abstractions only when a concrete feature needs them.

## Validation

Run commands from the repository root. Builds require full Xcode with SDKs supporting the projects' configured deployment targets; Command Line Tools alone are insufficient.

```sh
# iOS simulator build without device signing
xcodebuild -project apps/ios/caocap/caocap.xcodeproj -scheme caocap -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/caocap-ios-build CODE_SIGNING_ALLOWED=NO build

# macOS build without signing
xcodebuild -project apps/macos/caocap/caocap.xcodeproj -scheme caocap -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/caocap-macos-build CODE_SIGNING_ALLOWED=NO build

git diff --check
```

There are currently no test targets. For app changes, build the affected platform and check the changed flow when a simulator or device is available. For documentation and folder moves, verify links, project-relative paths, and asset references. Report validation limitations accurately.
