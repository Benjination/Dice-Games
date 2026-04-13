const admin = require('firebase-admin');

// Initialize with your service account credentials
// Download from Firebase Console > Project Settings > Service Accounts
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function setModerator(uid, isModerator = true) {
  try {
    await admin.auth().setCustomUserClaims(uid, {
      moderator: isModerator
    });
    console.log(`✅ Moderator status set to ${isModerator} for user: ${uid}`);
    
    // Get user info to confirm
    const user = await admin.auth().getUser(uid);
    console.log(`   User: ${user.email || user.displayName || 'Unknown'}`);
    console.log(`   Custom Claims:`, user.customClaims);
  } catch (error) {
    console.error('❌ Error setting moderator status:', error.message);
  }
}

// Get user ID from command line arguments
const uid = process.argv[2];
const isModerator = process.argv[3] !== 'false';

if (!uid) {
  console.error('Usage: node set-moderator.js <user-id> [true|false]');
  console.error('');
  console.error('Examples:');
  console.error('  node set-moderator.js abc123xyz true    # Make user a moderator');
  console.error('  node set-moderator.js abc123xyz false   # Remove moderator status');
  process.exit(1);
}

setModerator(uid, isModerator).then(() => process.exit(0));
