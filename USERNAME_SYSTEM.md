# Username System Documentation

## Overview
The app now properly stores and displays human-readable usernames in Firestore, separate from Firebase Authentication UIDs.

## Understanding UIDs vs Usernames

### Firebase UID (Not Controllable)
- **What it is**: Auto-generated unique identifier by Firebase Authentication
- **Format**: Random string like `xK9mP2nQ7rS3...`
- **Purpose**: Internal authentication and security
- **Can we change it?**: **NO** - Firebase generates this automatically and it cannot be modified
- **Where it's used**: Internal database references, authentication tokens

### Username (Controllable)
- **What it is**: Human-readable display name stored in Firestore
- **Format**: `AdjectiveNoun####` (e.g., `QuickFox1234`)
- **Purpose**: User-facing display in the UI
- **Can we change it?**: **YES** - Users can regenerate at any time
- **Where it's stored**: Firestore at `users/{uid}/username`

## How It Works

### Firestore Structure
```
users/
  {uid}/  ← Firebase UID (auto-generated)
    username: "QuickFox1234"  ← Human-readable username
    email: "user@example.com"
    createdAt: timestamp
    updatedAt: timestamp
```

### Username Generation
1. **Format**: Adjective + Noun + 4 digits
2. **Examples**: 
   - `BraveEagle7392`
   - `SilentWolf4281`
   - `QuickFox1234`
3. **Total Combinations**: 52.5 million unique usernames

### When Usernames Are Created
Usernames are automatically generated in these scenarios:

1. **New Account Creation**
   - Email/password signup
   - Google sign-in (first time)
   - Phone authentication (first time)

2. **Existing Users Without Usernames**
   - When app loads (if user is already signed in)
   - When opening Settings screen
   - When signing in with existing account

3. **Manual Regeneration**
   - Users can click the refresh icon in Settings
   - Generates a new random username

## Code Changes Made

### 1. Enhanced UserService (`lib/services/user_service.dart`)
```dart
// Creates/updates user document with username
static Future<void> ensureUserDocument(User user)

// Gets current user's username
static Future<String?> getCurrentUsername()

// Updates username in Firestore
static Future<void> updateUsername(String newUsername)

// Gets any user's username by UID
static Future<String> getUsernameByUid(String uid)
```

### 2. Updated Authentication Flows (`lib/screens/auth/login_screen.dart`)
- Email/password signup → calls `ensureUserDocument()`
- Email/password sign-in → calls `ensureUserDocument()`
- Google sign-in → calls `ensureUserDocument()`
- Phone authentication → calls `ensureUserDocument()`

### 3. Updated Settings Screen (`lib/screens/settings/settings_screen.dart`)
- Displays username from Firestore (not Firebase Auth)
- Regenerate button updates Firestore
- Shows "Loading..." while fetching username

### 4. Updated Main App (`lib/main.dart`)
- Auth state changes trigger `ensureUserDocument()`
- Ensures all signed-in users have usernames
- Handles migration for existing users

## For Existing Users

### Migration Process
When an existing user (created before this update) signs in:
1. App checks if user document exists in Firestore
2. If no document or missing username → generates one automatically
3. User sees their new username in Settings
4. User can regenerate if they want a different one

### Firestore Security Rules Needed
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      // Users can read their own document
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Users can update only their own username
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Testing the Fix

### Test Cases
1. ✅ **New User Signup**
   - Create account → check Settings → username should be visible
   
2. ✅ **Existing User Sign-In**
   - Sign in with existing account → username auto-generated
   
3. ✅ **Username Regeneration**
   - Settings → tap refresh icon → new username appears
   
4. ✅ **Multiple Devices**
   - Sign in on Device A → regenerate username
   - Sign in on Device B → same username appears

### Verification Steps
1. Open browser console → Firebase tab
2. Check Firestore → `users` collection
3. Find your UID → verify `username` field exists
4. Should see format: `AdjectiveNoun####`

## Common Issues & Solutions

### Issue: Username still showing as UID
**Cause**: Cached data or old Firebase Auth displayName
**Solution**: 
1. Sign out completely
2. Clear browser cache
3. Sign in again
4. Check Settings screen

### Issue: Username not updating after regeneration
**Cause**: State not refreshing
**Solution**: Already fixed - Settings screen uses `setState()` to refresh

### Issue: Different username on different devices
**Cause**: Not using Firestore (using Firebase Auth displayName)
**Solution**: Already fixed - Now using Firestore as single source of truth

## Future Enhancements

### Possible Additions
- [ ] Custom usernames (user can choose their own)
- [ ] Username uniqueness checking
- [ ] Username history/changelog
- [ ] Display usernames in game creator fields
- [ ] Search users by username

### Current Limitations
- Usernames are randomly generated only
- No uniqueness guarantee (52.5M combos makes collisions rare)
- No profanity filtering on usernames (only on game content)
