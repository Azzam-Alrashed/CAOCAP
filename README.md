# CAOCAP

**Find your direction. Build your skills. Turn knowledge into income.**

CAOCAP is an AI digital career mentor that helps complete beginners explore skills, choose a direction, build practical experience, demonstrate their abilities, and prepare for paid opportunities.

> Explore skills → try guided tasks → choose a direction → build projects → create a portfolio → pursue paid opportunities

## Project status

CAOCAP is at the initial scaffolding stage. The repository does not yet contain the AI digital career mentorship or learning experience described in the product documentation.

| Area | Status |
| --- | --- |
| iOS | Basic SwiftUI starter application with imported asset catalog |
| macOS | Basic SwiftUI starter application |
| Android | Directory scaffold only |
| Windows | Directory scaffold only |
| Linux | Directory scaffold only |
| Landing page | Directory scaffold only |
| Web application | Directory scaffold only |

## Repository structure

```text
.
├── apps/
│   ├── ios/                 # iOS SwiftUI project and app assets
│   ├── macos/               # macOS SwiftUI project
│   ├── android/             # Planned Android client
│   ├── windows/             # Planned Windows client
│   ├── linux/               # Planned Linux client
│   └── web/                 # Planned web client
├── websites/
│   └── landing/             # Planned public website
├── assets/
│   └── brand/               # Imported artwork and icon variants
├── docs/
│   ├── research/            # Imported UX research and audits
│   ├── product-vision.md
│   ├── SRS.md
│   └── imported-assets.md
├── AGENTS.md                # Repository guidance for coding agents
├── README.md
└── .gitignore
```

## Getting started

The runnable applications currently require macOS and an Xcode version compatible with the projects' configured SDKs.

### iOS

1. Open [the iOS project](apps/ios/caocap/caocap.xcodeproj) in Xcode.
2. Select the `caocap` scheme and an iOS simulator or compatible device.
3. Run the project with **Product → Run** or `Command-R`.

### macOS

1. Open [the macOS project](apps/macos/caocap/caocap.xcodeproj) in Xcode.
2. Select the `caocap` scheme and the **My Mac** destination.
3. Run the project with **Product → Run** or `Command-R`.

Both projects currently display the default SwiftUI starter view.

## Technology

Technology currently present in the repository:

- Swift
- SwiftUI
- Xcode projects for iOS and macOS

Technology choices for the other clients and shared services have not been made.

## Documentation

- [Product vision](docs/product-vision.md) explains why CAOCAP exists and the experience it intends to create.
- [Software Requirements Specification](docs/SRS.md) defines the envisioned system requirements and records unresolved decisions.
- [Brand asset index](assets/brand/README.md) locates artwork, mascot references, and icon variants.
- [Research index](docs/research/README.md) links to the imported UX reports and audits.
- [Imported assets](docs/imported-assets.md) records their source, original paths, and license.
- [Agent guidance](AGENTS.md) describes repository conventions and validation commands.

## Roadmap

The product direction includes guided skill exploration, AI digital career mentorship and feedback, practical projects, progress tracking, portfolio building, paid-opportunity preparation, and additional platform clients. These capabilities are planned and are not yet implemented.

See the [Software Requirements Specification](docs/SRS.md) for the requirements baseline and open decisions.
