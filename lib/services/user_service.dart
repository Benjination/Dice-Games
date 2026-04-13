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

  /// Creates or updates a user document in Firestore with a generated username
  /// This should be called after any authentication (sign up, sign in, etc.)
  static Future<void> ensureUserDocument(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      // New user - create document with generated username
      final username = UsernameGenerator.generate();
      await userDoc.set({
        'username': username,
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
        // Generate new username if missing or invalid
        final username = UsernameGenerator.generate();
        await userDoc.update({
          'username': username,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
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

  /// Updates the current user's username in Firestore
  static Future<void> updateUsername(String newUsername) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    await _firestore.collection('users').doc(user.uid).update({
      'username': newUsername,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
