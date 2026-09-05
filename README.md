# CAOCAP

**Explore. Build. Collaborate.**

CAOCAP is a platform where people discover, build, and publish AI agents together.

Users will be able to explore agents built by the community, create their own, and collaborate on shared projects. To build agents, they will use mindmaps to organize context and knowledge, and flowcharts to define logic and conditional flows. They can test and improve agents together, then publish them for others to use. The building experience will feel playful and responsive, helping users see their agents come to life.

> Explore agents → build or join a project → collaborate and test → publish → improve together

## Project status

CAOCAP is transitioning to a collaborative AI agent platform. Agent discovery, building, collaboration, and publishing are planned and not yet implemented.

| Area | Status |
| --- | --- |
| iOS | Imported OSS-CAOCAP-v9 SwiftUI app with onboarding, authentication, canvas, CoCaptain, and tests; service configuration required |
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
│   └── SRS.md
├── AGENTS.md                # Repository guidance for coding agents
├── README.md
└── .gitignore
```

## Getting started

The runnable applications currently require macOS and an Xcode version compatible with the projects' configured SDKs.

### iOS

1. Open [the iOS project](apps/ios/caocap/caocap.xcodeproj) in Xcode.
2. Follow the [iOS setup notes](apps/ios/README.md), including Firebase configuration and package resolution.
3. Select the `caocap` scheme and an iOS 26 or later simulator or compatible device.
4. Run the project with **Product → Run** or `Command-R`.

### macOS

1. Open [the macOS project](apps/macos/caocap/caocap.xcodeproj) in Xcode.
2. Select the `caocap` scheme and the **My Mac** destination.
3. Run the project with **Product → Run** or `Command-R`.

The macOS project currently displays the default SwiftUI starter view.

## Technology

Technology currently present in the repository:

- Swift
- SwiftUI
- Xcode projects for iOS and macOS

Technology choices for the other clients and shared services have not been made.

## Documentation

- [Product vision](docs/product-vision.md) explains why CAOCAP exists and the experience it intends to create.
- [Software Requirements Specification](docs/SRS.md) defines the envisioned system requirements and records unresolved decisions.
- [Brand assets](assets/brand/) contains artwork, mascot references, and icon variants.
- [Research index](docs/research/README.md) links to the imported UX reports and audits.
- [Agent guidance](AGENTS.md) describes repository conventions and validation commands.

## Roadmap

The roadmap focuses on three core experiences: Explore, Build, and Collaborate. Planned capabilities include discovering and trying agents, creating and testing agents, collaborating on shared projects, and publishing agents for others to use. These capabilities are not yet implemented.

Development will start with iOS and macOS, followed by the other platforms.

See the [Software Requirements Specification](docs/SRS.md) for the requirements baseline and open decisions.
