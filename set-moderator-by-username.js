const admin = require('firebase-admin');

// Initialize with your service account credentials
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function findUserByUsername(username) {
  try {
    // Search Firestore users collection for matching username
    const snapshot = await db.collection('users')
      .where('username', '==', username)
      .limit(1)
      .get();
    
    if (snapshot.empty) {
      console.error(`❌ No user found with username: ${username}`);
      return null;
    }
    
    const userDoc = snapshot.docs[0];
    return userDoc.id; // This is the UID
  } catch (error) {
    console.error('❌ Error searching for user:', error.message);
    return null;
  }
}

async function setModerator(uid, isModerator = true) {
  try {
    await admin.auth().setCustomUserClaims(uid, {
      moderator: isModerator
    });
    console.log(`✅ Moderator status set to ${isModerator} for user: ${uid}`);
    
    // Get user info to confirm
    const user = await admin.auth().getUser(uid);
    console.log(`   Email: ${user.email || 'No email'}`);
    console.log(`   Display Name: ${user.displayName || 'No display name'}`);
    console.log(`   Custom Claims:`, user.customClaims);
    console.log('');
    console.log('⚠️  User must log out and log back in to see moderator privileges.');
  } catch (error) {
    console.error('❌ Error setting moderator status:', error.message);
  }
}

async function main() {
  const username = process.argv[2];
  const isModerator = process.argv[3] !== 'false';

  if (!username) {
    console.error('Usage: node set-moderator-by-username.js <username> [true|false]');
    console.error('');
    console.error('Examples:');
    console.error('  node set-moderator-by-username.js IronSword0643 true    # Make user a moderator');
    console.error('  node set-moderator-by-username.js IronSword0643 false   # Remove moderator status');
    process.exit(1);
  }

  console.log(`🔍 Looking up user: ${username}...`);
  const uid = await findUserByUsername(username);
  
  if (uid) {
    console.log(`✅ Found user with UID: ${uid}`);
    console.log('');
    await setModerator(uid, isModerator);
  }
  
  process.exit(0);
}

main();
