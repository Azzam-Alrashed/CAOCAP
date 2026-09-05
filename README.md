# CAOCAP

**Find your direction. Build your skills. Turn knowledge into income.**

CAOCAP is a computer-use AI agent for learners who want to develop digital skills, mainly coding, and use those skills to earn income.

The intended experience brings the agent into the learner's computer workflow to guide practice, demonstrate tasks, and help build practical projects. Learning and developing the user's own ability are central to the agent's work.

> Learn with the agent → practise in real tools → build projects → demonstrate skills → pursue paid opportunities

## Project status

CAOCAP is at the initial scaffolding stage. The repository does not yet implement the computer-use agent or learning experience described in the product documentation.

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
│   └── SRS.md
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
- [Brand assets](assets/brand/) contains artwork, mascot references, and icon variants.
- [Research index](docs/research/README.md) links to the imported UX reports and audits.
- [Agent guidance](AGENTS.md) describes repository conventions and validation commands.

## Roadmap

The product direction centers on a computer-use AI agent that helps learners develop digital skills, with coding as the primary focus. Planned capabilities include guided practice in real tools, demonstrations and contextual feedback, practical projects, progress tracking, portfolio building, and preparation for paid opportunities. These capabilities are not yet implemented.

See the [Software Requirements Specification](docs/SRS.md) for the requirements baseline and open decisions.
