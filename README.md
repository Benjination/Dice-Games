# DiceGames

Universal dice game platform built with Flutter and Firebase. Create custom dice games, save them, and share with others.

Website temporary: https://benjination.github.io/Dice-Games/

## 🎲 Features

### Dice Roulette Game
- **Configurable dice**: 1-10 dice, each with customizable labels (A-Z) and sides (d4, d6, d8, d10, d12, d20)
- **Bias modes**: 
  - Fair Dice (standard distribution)
  - Mean Dice (biased toward high values)
  - Nice Dice (biased toward low values)
- **Dynamic rules**: Add general rules and per-face rules during gameplay
- **Individual or batch rolling**: Tap individual dice or roll all at once

### User Features
- **Firebase Authentication**: Email/password, Google sign-in, Phone (SMS)
- **Save games**: Save your dice configurations privately
- **Publish games**: Submit games for moderation to share publicly
- **Profanity filter**: Optional content filtering (enabled by default)
- **My Games**: View and replay all your saved games

### Coming Soon
- Farkle
- Pig Dice
- Dice Poker
- Moderation system for published games
- Public game library

---

## 🎨 Design

**Dark Academia Theme**: Navy blue, forest green, charcoal, antique brass accents, cream text.

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.41+ 
- Dart 3.11+
- Firebase project (for auth and Firestore)

### Local Development
```bash
# Clone the repository
git clone https://github.com/[username]/DiceGames.git
cd DiceGames

# Install dependencies
flutter pub get

# Run on Chrome (web)
flutter run -d chrome

# Run on your device
flutter run
```

### Build for Production
```bash
# Web
flutter build web --release

# Android
flutter build apk --release

# iOS
flutter build ios --release

# Desktop
flutter build macos --release
flutter build windows --release
flutter build linux --release
```

---

## 🌐 Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions.

**Quick Deploy to Firebase Hosting:**
```bash
flutter build web --release
firebase deploy --only hosting
```

---

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase configuration
├── models/
│   ├── dice_config.dart        # Dice configuration model
│   └── saved_game.dart         # Saved game model
├── screens/
│   ├── landing_page.dart       # Home screen
│   ├── auth/
│   │   └── login_screen.dart   # Authentication
│   ├── games/
│   │   ├── dice_pool_config_screen.dart    # Dice setup
│   │   ├── dice_pool_screen.dart           # Gameplay
│   │   └── my_games_screen.dart            # Saved games list
│   └── settings/
│       └── settings_screen.dart             # App settings
├── services/
│   ├── game_service.dart       # Firestore game operations
│   ├── profanity_filter.dart   # Content filtering
│   └── settings_service.dart   # User preferences
└── theme/
    └── dark_academia_theme.dart # App styling
```

---

## 🔧 Configuration

### Firebase Setup
1. Create a Firebase project at https://console.firebase.google.com/
2. Enable Authentication (Email, Google, Phone)
3. Enable Firestore Database
4. Run `flutterfire configure` to generate firebase_options.dart
5. Update Firestore security rules (see [DEPLOYMENT.md](DEPLOYMENT.md))

### Environment Variables
No environment variables needed - Firebase configuration is in `lib/firebase_options.dart`

---

## 🧪 Testing

```bash
# Run tests
flutter test

# Run with coverage
flutter test --coverage
```

---

## 📝 License

This project is licensed under the MIT License.

---

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- Dark Academia aesthetic inspiration

---

## 📞 Contact

Questions or suggestions? Open an issue on GitHub!
