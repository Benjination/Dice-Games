import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'username_generator.dart';

/// Service for managing user roles and permissions
class UserService {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  /// Checks if the current user has moderator privileges
  /// This relies on Firebase Custom Claims set via Admin SDK
  static Future<bool> isUserModerator() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Force refresh to get latest custom claims
      final idTokenResult = await user.getIdTokenResult(true);
      return idTokenResult.claims?['moderator'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Forces a token refresh to get updated custom claims
  /// Call this after modifying user claims on the backend
  static Future<void> refreshUserToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.getIdTokenResult(true);
    }
  }

  /// Creates or updates a user document in Firestore with a unique username
  /// This should be called after any authentication (sign up, sign in, etc.)
  static Future<void> ensureUserDocument(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      // New user - create document with unique username (unlocked for customization)
      final username = await _generateUniqueUsername();
      await userDoc.set({
        'username': username,
        'usernameLocked': false, // Allow user to regenerate initially
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Existing user - check if username exists and is valid
      final data = docSnapshot.data();
      if (data?['username'] == null || 
          (data!['username'] as String).isEmpty ||
          !UsernameGenerator.isValidFormat(data['username'] as String)) {
        // Generate new unique username if missing or invalid (unlocked)
        final username = await _generateUniqueUsername();
        await userDoc.update({
          'username': username,
          'usernameLocked': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Add usernameLocked field if it doesn't exist (for existing users)
      if (data != null && !data.containsKey('usernameLocked')) {
        await userDoc.update({
          'usernameLocked': true, // Existing users keep their usernames
        });
      }
    }
  }

  /// Generates a unique username by checking against existing usernames
  /// Retries up to 10 times if collisions occur
  static Future<String> _generateUniqueUsername() async {
    for (int attempt = 0; attempt < 10; attempt++) {
      final username = UsernameGenerator.generate();
      
      // Check if username already exists
      final existingUsers = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      
      if (existingUsers.docs.isEmpty) {
        return username; // Username is unique
      }
    }
    
    // Fallback: append timestamp to ensure uniqueness
    final base = UsernameGenerator.generate();
    final timestamp = DateTime.now().millisecondsSinceEpoch % 10000;
    return '$base$timestamp';
  }

  /// Gets the username for the current user from Firestore
  static Future<String?> getCurrentUsername() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data()?['username'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Checks if the current user's username is locked
  static Future<bool> isUsernameLocked() async {
    final user = _auth.currentUser;
    if (user == null) return true;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data()?['usernameLocked'] as bool? ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Locks the current user's username permanently
  static Future<void> lockUsername() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    await _firestore.collection('users').doc(user.uid).update({
      'usernameLocked': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates the current user's username in Firestore with uniqueness check
  /// Only works if username is not locked
  /// Returns true if successful, false if username is already taken or locked
  static Future<bool> updateUsername(String newUsername) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    // Check if username is locked
    final isLocked = await isUsernameLocked();
    if (isLocked) return false;

    // Check if username is already taken by another user
    final existingUsers = await _firestore
        .collection('users')
        .where('username', isEqualTo: newUsername)
        .limit(1)
        .get();
    
    if (existingUsers.docs.isNotEmpty && 
        existingUsers.docs.first.id != user.uid) {
      return false; // Username taken by another user
    }

    await _firestore.collection('users').doc(user.uid).update({
      'username': newUsername,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    return true;
  }

  /// Gets a username for any user by their UID
  static Future<String> getUsernameByUid(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      return userDoc.data()?['username'] as String? ?? 'Unknown User';
    } catch (e) {
      return 'Unknown User';
    }
  }
}
