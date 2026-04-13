# Moderator Setup Guide

This guide explains how to set up moderator accounts for your DiceGames application.

## Overview

DiceGames uses **Firebase Custom Claims** to implement role-based access control for moderators. Custom Claims are custom attributes stored in a user's authentication token that determine their permissions.

## Why Firebase Custom Claims?

- **Secure**: Claims cannot be modified by the client
- **Scalable**: No additional database queries needed
- **Standard**: Industry-standard approach for role-based access control
- **Efficient**: Claims are included in the user's JWT token

## Setting Up Moderators

Firebase Custom Claims can only be set using the **Firebase Admin SDK**, which runs in a trusted server environment (not in the Flutter app). 

⚠️ **Security Note**: Admin scripts should NEVER be committed to a public repository. Keep them in a separate private location or use Firebase Cloud Functions.

You have two main options:

### Option 1: Using Firebase Cloud Functions (Recommended)

Create a Firebase Cloud Function that sets the moderator claim:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// HTTP function to set moderator status
// Security: Add proper authentication/authorization before deploying to production
exports.setModerator = functions.https.onCall(async (data, context) => {
  // Only allow admins to set moderator status
  // You can check if the caller is already a moderator or super-admin
  const callerUid = context.auth.uid;
  
  // Add your authentication logic here
  // For example, check if caller has admin privileges
  
  const targetUid = data.uid;
  const isModerator = data.moderator;

  try {
    await admin.auth().setCustomUserClaims(targetUid, {
      moderator: isModerator
    });
    
    return { 
      success: true, 
      message: `Moderator status set to ${isModerator} for user ${targetUid}` 
    };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

**Deploy the function:**
```bash
firebase deploy --only functions
```

**Call from your app or admin panel:**
```dart
// Example usage (add proper UI for this)
final callable = FirebaseFunctions.instance.httpsCallable('setModerator');
await callable.call({
  'uid': 'user-id-to-promote',
  'moderator': true,
});
```

### Option 2: Using Firebase Admin SDK Script (Node.js)

Create a Node.js script to set moderator claims:

**1. Install Firebase Admin SDK:**
```bash
npm install firebase-admin
```

**2. Create `set-moderator.js` script:**
```javascript
const admin = require('firebase-admin');

// Initialize with your service account credentials
// Download from Firebase Console > Project Settings > Service Accounts
const serviceAccount = require('./path-to-your-serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function setModerator(uid, isModerator = true) {
  try {
    await admin.auth().setCustomUserClaims(uid, {
      moderator: isModerator
    });
    console.log(`✅ Moderator status set to ${isModerator} for user: ${uid}`);
  } catch (error) {
    console.error('❌ Error setting moderator status:', error);
  }
}

// Get user ID from command line arguments
const uid = process.argv[2];
const isModerator = process.argv[3] !== 'false';

if (!uid) {
  console.error('Usage: node set-moderator.js <user-id> [true|false]');
  process.exit(1);
}

setModerator(uid, isModerator).then(() => process.exit(0));
```

**3. Run the script:**
```bash
# Promote user to moderator
node set-moderator.js "user-uid-here" true

# Revoke moderator status
node set-moderator.js "user-uid-here" false
```

### Option 3: Using Firebase CLI Extensions

Firebase provides pre-built extensions that can help with role management. Consider using the **Set User Claims** extension for a UI-based approach.

## Getting User IDs

To find a user's UID:

1. **Firebase Console:**
   - Go to Firebase Console > Authentication > Users
   - Find the user and copy their UID

2. **In Your App:**
   - Add a debug/admin screen that displays the current user's UID:
   ```dart
   final uid = FirebaseAuth.instance.currentUser?.uid;
   print('Current User UID: $uid');
   ```

## Token Refresh

After setting custom claims, users must refresh their authentication token to see the changes:

1. **Automatic (on next login):** Claims are refreshed when the user logs in again
2. **Manual refresh (in the app):**
   ```dart
   await UserService.refreshUserToken();
   ```

The app automatically forces a token refresh when checking moderator status, so users should see their new permissions immediately.

## Testing Moderator Features

1. **Set yourself as a moderator** using one of the methods above
2. **Log out and log back in** to your DiceGames app (or the app will auto-refresh the token)
3. **Check for the "Approve Games" option:**
   - In the AppBar (admin panel settings icon)
   - In the Game Library list (Approve Games card)
4. **Test the approval workflow:**
   - Create a public game
   - It should appear in the pending games list
   - Approve or reject it as a moderator

## Security Considerations

- **Never expose Admin SDK credentials** in your Flutter app code
- **Implement proper authorization** in Cloud Functions before allowing claim changes
- **Use role hierarchy** (e.g., super-admin can set moderators)
- **Log all moderator actions** for audit trails
- **Consider rate limiting** for moderation actions

## Production Recommendations

1. **Create an admin panel** (web app) for managing moderators
2. **Set up approval workflows** before granting moderator status
3. **Implement moderator activity logging** using Firestore
4. **Add monitoring and alerts** for moderation actions
5. **Document your moderation policies** and guidelines

## Troubleshooting

### "You do not have moderator privileges" error

**Possible causes:**
- Custom claims not set correctly
- Token not refreshed after setting claims
- User logged in before claims were set

**Solutions:**
1. Check if claims are set: Run the Admin SDK script with debug logging
2. Force token refresh: Log out and log back in
3. Verify user ID matches the UID in Firebase Authentication

### Moderator option not showing

**Possible causes:**
- Token hasn't been refreshed
- App is still checking moderator status (shows after network request completes)
- User is in guest mode

**Solutions:**
1. Wait a few seconds for the status check to complete
2. Ensure user is logged in (not guest)
3. Check console logs for errors

### Unable to approve/reject games

**Possible causes:**
- Network connectivity issues
- Firestore security rules blocking operations
- Game already moved to another collection

**Solutions:**
1. Check internet connection
2. Verify Firestore rules allow moderators to write to publicGames/rejectedGames
3. Refresh the pending games list

## Firestore Security Rules

Update your Firestore rules to allow moderators to manage game collections:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is moderator
    function isModerator() {
      return request.auth != null && 
             request.auth.token.moderator == true;
    }
    
    // Pending games - moderators can read/delete
    match /pendingGames/{gameId} {
      allow read: if isModerator();
      allow write: if request.auth != null; // Users can submit
      allow delete: if isModerator(); // Moderators can delete
    }
    
    // Public games - moderators can write, everyone can read
    match /publicGames/{gameId} {
      allow read: if true; // Anyone can read
      allow write: if isModerator(); // Only moderators can approve
    }
    
    // Rejected games - only moderators can access
    match /rejectedGames/{gameId} {
      allow read, write: if isModerator();
    }
  }
}
```

## Next Steps

1. Set up your first moderator account
2. Test the moderation workflow
3. Create internal documentation for your moderation team
4. Consider adding additional moderation features:
   - Moderator comments/notes on games
   - Moderation history/audit log
   - Bulk approval/rejection
   - Moderator dashboard with statistics

---

For questions or issues, refer to the [Firebase Custom Claims documentation](https://firebase.google.com/docs/auth/admin/custom-claims).
