import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing user roles and permissions
class UserService {
  static final _auth = FirebaseAuth.instance;

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
}
