# DiceGames Universal Plan

## Vision
Build a single Flutter codebase for dice games that runs on:
- Web
- Android
- iOS (iPhone/iPad)
- macOS
- Windows
- Linux
- Future XR/Meta path via plugin adapters and/or companion app strategy

## Platform Expansion Strategy
### Current Feasibility
- Steam: Yes, practical from Flutter desktop builds (Windows/macOS/Linux) with Steamworks integration via native bridge/plugin work.
- PlayStation/Xbox/Nintendo: Not practical as direct Flutter targets today in a typical public workflow.

### Why Consoles Are Different
- Console development requires approved developer accounts and NDAs.
- Platform SDKs are restricted and not publicly distributable.
- Certification requirements (TRCs/XRs/Lotcheck) add platform-specific behavior and compliance constraints.
- Flutter does not currently offer first-party, mainstream console deployment support.

### Recommended Universal-Acceptance Architecture
1. Keep shared game rules and dice logic in portable, engine-agnostic modules (pure Dart domain now).
2. Keep backend contracts stable (Firebase schemas/API boundaries) so multiple clients can share accounts and saves.
3. Ship Flutter for web/mobile/desktop first, including Steam on desktop.
4. Add a console client later using an engine with strong console support (commonly Unity or Unreal), reusing backend and gameplay rules/specs.

### Decision Gate
- Gate A (now): Flutter for web/mobile/desktop/Steam.
- Gate B (after traction): Evaluate console ports with a dedicated console-capable client while preserving backend and game design parity.

## Product Modes
1. Guest mode (no account)
- Play common built-in games
- No cloud save required

2. Account mode (required)
- Create custom games
- Save favorite games
- Sync profile and saved games with Firebase

## Platform-First Engineering Rules
1. Keep game logic pure Dart (no UI dependencies).
2. Keep random roll engine in a reusable domain layer.
3. Use a repository pattern for data access (Firebase today, swappable tomorrow).
4. Use responsive layouts that adapt for phone/tablet/desktop/web.
5. Avoid platform-specific code unless isolated behind interfaces.
6. Build accessibility and localization hooks early.

## Proposed Flutter Architecture
- lib/app: app shell, routing, themes
- lib/features/auth: sign-in/sign-up/profile
- lib/features/games: built-in games, game detail, play UI
- lib/features/custom_games: builder/editor and publish/save flow
- lib/core/domain: entities, use-cases, dice engine
- lib/core/data: repositories, Firebase implementations
- lib/core/platform: adapters for platform-specific capabilities
- test: unit and widget tests

## Dice Randomness Strategy (Time-Seeded)
- On roll request, combine:
  - high-precision timestamp (microseconds)
  - user/session entropy
  - optional device entropy source
- Hash combined entropy to produce a deterministic seed for that event.
- Use a seeded RNG to generate each die result.
- Record seed + results for replay/audit in account mode.

Note: Time-only randomness can be predictable. Mixing additional entropy increases fairness and robustness.

## Firebase Scope (You will create)
- Auth: Email/Password, Google, Apple (as needed)
- Firestore:
  - users/{uid}
  - users/{uid}/savedGames/{gameId}
  - publicGames/{gameId}
- Optional:
  - Cloud Functions for server-side validation
  - Analytics and crash reporting

## Milestones
1. Foundation
- Install Flutter SDK and create app skeleton
- Add state management and routing
- Add theme system and responsive scaffolding

2. Core Dice Engine
- Implement RNG service and dice roll domain model
- Unit test distribution and deterministic replay behavior

3. Guest Experience
- Build home page and built-in games
- Implement game play flow with polished roll animation

4. Auth + Persistence
- Add Firebase auth flow
- Add saved favorites and custom game persistence

5. Custom Game Builder
- Rules editor for dice count, modifiers, win conditions
- Save, load, duplicate, and publish options

6. Cross-Platform Hardening
- Validate mobile, desktop, and web layouts
- Performance tuning and offline behavior
- Prepare app store metadata/build settings

## Definition of Done (v1)
- Guest users can play at least 3 built-in games
- Authenticated users can create and save custom games
- Cross-platform build verified on web + Android + iOS + desktop target(s)
- Basic tests pass in CI

## Immediate Next Steps
1. Install Flutter and verify with `flutter doctor`.
2. Scaffold project in this folder:
   - `flutter create .`
3. Add foundational dependencies:
   - state management
   - routing
   - Firebase core/auth/firestore
4. Build the first vertical slice:
   - home screen
   - configurable dice roller
   - guest game card list

## Tracking
We will update this file as the source of truth at each milestone.

## Progress Snapshot (2026-04-12)
- Completed
  - Flutter SDK installed and verified
  - Multi-platform scaffold generated in this workspace
  - Initial home screen implemented with configurable dice roller
  - Guest and sign-in entry points added as placeholders
  - Firebase SDK packages added and web config integrated
  - Baseline static analysis and tests passing
- Next
  - Connect Firebase (after you create project config)
  - Add built-in games list and first playable game screen
  - Add auth screens and route guards for account-only features