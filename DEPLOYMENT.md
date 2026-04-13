# Deployment Guide for Roll Tavern

## Prerequisites
- GitHub account
- Firebase project configured (dice-games-6a9ab)
- Flutter SDK installed locally

## Option 1: Firebase Hosting (Recommended)

Firebase Hosting is ideal for Flutter web apps with Firebase integration.

### Setup
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase Hosting in your project
firebase init hosting
```

When prompted:
- What do you want to use as your public directory? → **build/web**
- Configure as a single-page app? → **Yes**
- Set up automatic builds and deploys with GitHub? → **No** (or Yes if you want CI/CD)

### Deploy
```bash
# Build the Flutter web app
flutter build web --release

# Deploy to Firebase
firebase deploy --only hosting
```

Your app will be live at: `https://dice-games-6a9ab.web.app`

### Update
```bash
# Rebuild and redeploy
flutter build web --release
firebase deploy --only hosting
```

---

## Option 2: GitHub Pages

GitHub Pages is free but requires some additional configuration.

### Setup

1. **Create `.github/workflows/deploy.yml`:**
```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Build web
        run: flutter build web --release --base-href "/Roll Tavern/"
      
      - name: Deploy
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./build/web
```

2. **Enable GitHub Pages:**
   - Go to your repo → Settings → Pages
   - Source: Deploy from a branch
   - Branch: gh-pages / (root)
   - Save

3. **Push to GitHub:**
```bash
git add .
git commit -m "Add deployment workflow"
git push origin main
```

Your app will be live at: `https://[username].github.io/Roll Tavern/`

### Important Notes for GitHub Pages:
- Update `web/index.html` base href to `/Roll Tavern/`
- Firebase auth redirect URLs need to include your GitHub Pages domain
- Update Firebase Console → Authentication → Authorized domains

---

## Pre-Deployment Checklist

- [ ] All tests passing
- [ ] No compilation errors (`flutter build web` succeeds)
- [ ] Firebase configuration is correct
- [ ] Assets are properly included
- [ ] Authentication providers are configured in Firebase Console
- [ ] Profanity filter word list is appropriate for your audience
- [ ] README is updated
- [ ] .gitignore excludes sensitive files

---

## Firebase Authentication Setup

After deploying, add your domain to Firebase authorized domains:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (dice-games-6a9ab)
3. Authentication → Settings → Authorized domains
4. Add:
   - `dice-games-6a9ab.web.app` (if using Firebase Hosting)
   - `[username].github.io` (if using GitHub Pages)
   - `localhost` (for development)

---

## Testing Production Build Locally

Before deploying, test the production build:

```bash
# Build for web
flutter build web --release

# Serve locally (requires Python or a local server)
cd build/web
python3 -m http.server 8000

# OR use Firebase local hosting
firebase serve --only hosting
```

Open http://localhost:8000 in your browser.

---

## Troubleshooting

### Build fails with compilation errors
```bash
flutter clean
flutter pub get
flutter build web --verbose
```

### Authentication not working
- Check Firebase Console → Authentication → Authorized domains
- Verify firebase_options.dart has correct configuration
- Check browser console for errors

### Assets not loading
- Verify `pubspec.yaml` has all assets declared
- Run `flutter clean` and rebuild
- Check browser network tab for 404 errors

### Firestore permission denied
- Update Firestore security rules in Firebase Console
- Example rules:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/games/{gameId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /pendingGames/{gameId} {
      allow create: if request.auth != null;
      allow read: if request.auth != null;
    }
  }
}
```
