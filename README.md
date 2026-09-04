# CAOCAP

**Find your direction. Build your skills. Turn knowledge into income.**

CAOCAP is an early-stage AI mentor designed to help complete beginners explore digital skills, practise through guided projects, and prepare for paid opportunities.

> Explore skills → try guided tasks → choose a direction → build projects → create a portfolio → pursue paid opportunities

## Project status

CAOCAP is at the initial scaffolding stage. The repository does not yet contain the AI mentorship or learning experience described in the product documentation.

| Area | Status |
| --- | --- |
| iOS | Basic SwiftUI starter application |
| macOS | Basic SwiftUI starter application |
| Android | Directory scaffold only |
| Windows | Directory scaffold only |
| Linux | Directory scaffold only |
| Landing page | Directory scaffold only |
| Web application | Directory scaffold only |

## Repository structure

```text
.
├── Android/                 # Planned Android client
├── iOS/                     # iOS SwiftUI project
├── Linux/                   # Planned Linux client
├── MacOS/                   # macOS SwiftUI project
├── Website/
│   ├── LandingPage/         # Planned public website
│   └── WebApp/              # Planned web client
├── Windows/                 # Planned Windows client
└── docs/                    # Product and requirements documentation
```

## Getting started

The runnable applications currently require macOS and an Xcode version compatible with the projects' configured SDKs.

### iOS

1. Open `iOS/caocap/caocap.xcodeproj` in Xcode.
2. Select the `caocap` scheme and an iOS simulator or compatible device.
3. Run the project with **Product → Run** or `Command-R`.

### macOS

1. Open `MacOS/caocap/caocap.xcodeproj` in Xcode.
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

## Roadmap

The product direction includes guided skill exploration, AI mentorship and feedback, practical projects, progress tracking, portfolio building, paid-opportunity preparation, and additional platform clients. These capabilities are planned and are not yet implemented.

See the [Software Requirements Specification](docs/SRS.md) for the requirements baseline and open decisions.
