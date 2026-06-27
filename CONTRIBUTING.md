# Contributing to CAOCAP

First off, thank you for considering contributing to CAOCAP! It's people like you that make software development better for everyone.

## Our Philosophy

We follow the "Forgotten Future" of programming—gesture-based, spatial, and agentic. We prioritize **Developer Experience (DX)** above all else. If you're here, you're likely here to push boundaries.

## Technical Standards

To keep the codebase maintainable and performant, we adhere to the following standards:

### 1. Modern SwiftUI
- **State Management**: Use the `@Observable` macro (iOS 17+) for all view state. Avoid legacy `@StateObject` or `@Published` unless necessary for backward compatibility or specific framework requirements.
- **Views**: Keep views small and modular. Prefer `ViewModifier` or specialized subviews over massive `body` properties.
- **Concurrency**: Use Swift Structured Concurrency (`async/await`, `Task`). Avoid `@MainActor` blocking for disk I/O or heavy computations.

### 2. Folder Structure
Maintain the domain-driven, feature-based structure:
- `Models/`: Pure data.
- `Services/`: Business logic and infrastructure.
- `Features/`: UI and feature-specific logic.
- `Navigation/`: Routing logic.

### 3. State-Aware Actions
- Avoid "stringly-typed" logic. Use enums (like `NodeAction`) for navigation, routing, and intent.

## Git Workflow

1. **Branching**: Create a feature branch for every change: `feature/your-feature-name` or `fix/your-bug-fix`.
2. **Commits**: Write descriptive commit messages. Use prefixes like `Feat:`, `Fix:`, `Refactor:`, or `Chore:`.
3. **Pull Requests**:
   - Describe what changed and *why*.
   - Include screenshots or videos for UI changes.
   - Ensure the project builds successfully before submitting.

## Mini-App Publish (local development)

Publishing Mini-Apps to Vercel requires API credentials that are not committed to the repo.

1. Copy `ios-app/caocap/caocap/Resources/Config/Secrets.plist.example` to `Secrets.plist` in the same folder.
2. Create a [GitHub OAuth App](https://github.com/settings/developers) with authorization callback URL `caocap://`.
3. Add `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET` to `Secrets.plist` (never put real keys in `Secrets.plist.example`).
4. Add a [Vercel API token](https://vercel.com/account/settings/tokens) as `VERCEL_API_TOKEN`.
5. Ensure the Vercel account is linked to GitHub so deployments can pull user repositories.
6. Rebuild the app so `Secrets.plist` is copied into the app bundle.

`Secrets.plist` is gitignored. Do not commit real tokens.

## The "Vibe Coding" Way

CAOCAP is built in high-bandwidth development sessions. We value:
- **Clean Documentation**: Update `STRUCTURE.md` and `README.md` if your changes alter the app's architecture.
- **Vision First**: If a change doesn't align with the project's long-term mission, let's discuss it in an issue first.

---

**Let's build the future together.**
