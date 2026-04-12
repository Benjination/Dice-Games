# DiceGames

Universal dice game platform built with Flutter.

## Targets
- Web
- Android
- iOS
- macOS
- Windows
- Linux

## Product Direction
- Guest mode for built-in games without login
- Account mode for custom games and saved favorites
- Firebase backend for auth and cloud persistence

See [PLAN.md](PLAN.md) for the full roadmap and architecture.

## Local Setup
1. Verify your environment:
	- `flutter doctor -v`
2. Install dependencies:
	- `flutter pub get`
3. Run on your current device:
	- `flutter run`

## Current Status
- Flutter multi-platform scaffold created
- Initial home experience implemented with configurable dice roller
- Guest and auth entry points are present as placeholders

## Upcoming Work
- Add Firebase initialization and auth flow
- Implement built-in games list and gameplay screens
- Implement custom game builder and saved game persistence
