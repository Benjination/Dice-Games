import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing friend relationships and requests
class FriendsService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Searches for users by username (partial match, case-insensitive)
  /// Returns list of {uid, username} maps
  static Future<List<Map<String, String>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return [];

    try {
      // Search for usernames that start with the query (case-insensitive)
      final lowerQuery = query.toLowerCase();
      
      // Get all users and filter client-side (Firestore doesn't support case-insensitive search)
      final snapshot = await _firestore
          .collection('users')
          .limit(50)
          .get();

      final results = <Map<String, String>>[];
      
      for (final doc in snapshot.docs) {
        // Skip current user
        if (doc.id == currentUid) continue;
        
        final username = doc.data()['username'] as String?;
        if (username == null) continue;
        
        // Check if username contains query (case-insensitive)
        if (username.toLowerCase().contains(lowerQuery)) {
          results.add({
            'uid': doc.id,
            'username': username,
          });
        }
      }

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Sends a friend request to another user
  /// Returns true if successful, false if already friends or request exists
  static Future<bool> sendFriendRequest(String toUid, String toUsername) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      // Check if already friends
      final friendDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('friends')
          .doc(toUid)
          .get();

      if (friendDoc.exists) return false; // Already friends

      // Check if request already exists
      final existingRequest = await _firestore
          .collection('friend_requests')
          .where('fromUid', isEqualTo: currentUser.uid)
          .where('toUid', isEqualTo: toUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) return false; // Request already sent

      // Get current user's username
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final fromUsername = currentUserDoc.data()?['username'] as String? ?? 'Unknown';

      // Create friend request
      await _firestore.collection('friend_requests').add({
        'fromUid': currentUser.uid,
        'fromUsername': fromUsername,
        'toUid': toUid,
        'toUsername': toUsername,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Gets all pending friend requests for the current user (received)
  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      // Simplified query without orderBy to avoid composite index requirement
      final snapshot = await _firestore
          .collection('friend_requests')
          .where('toUid', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      final requests = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'requestId': doc.id,
          'fromUid': data['fromUid'],
          'fromUsername': data['fromUsername'],
          'createdAt': data['createdAt'],
        };
      }).toList();
      
      // Sort by createdAt on the client side
      requests.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // Descending order
      });
      
      return requests;
    } catch (e) {
      return [];
    }
  }

  /// Gets count of pending friend requests
  static Future<int> getPendingRequestCount() async {
    final requests = await getPendingRequests();
    return requests.length;
  }

  /// Accepts a friend request
  static Future<bool> acceptFriendRequest(String requestId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      // Get request data
      final requestDoc = await _firestore
          .collection('friend_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) return false;

      final requestData = requestDoc.data()!;
      final fromUid = requestData['fromUid'] as String;
      final fromUsername = requestData['fromUsername'] as String;
      final toUsername = requestData['toUsername'] as String;

      // Add to both users' friends collections
      final batch = _firestore.batch();

      // Add to current user's friends
      batch.set(
        _firestore.collection('users').doc(currentUser.uid).collection('friends').doc(fromUid),
        {
          'username': fromUsername,
          'addedAt': FieldValue.serverTimestamp(),
        },
      );

      // Add to other user's friends
      batch.set(
        _firestore.collection('users').doc(fromUid).collection('friends').doc(currentUser.uid),
        {
          'username': toUsername,
          'addedAt': FieldValue.serverTimestamp(),
        },
      );

      // Update request status
      batch.update(
        _firestore.collection('friend_requests').doc(requestId),
        {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Rejects a friend request
  static Future<bool> rejectFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Removes a friend
  static Future<bool> removeFriend(String friendUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final batch = _firestore.batch();

      // Remove from current user's friends
      batch.delete(
        _firestore.collection('users').doc(currentUser.uid).collection('friends').doc(friendUid),
      );

      // Remove from other user's friends
      batch.delete(
        _firestore.collection('users').doc(friendUid).collection('friends').doc(currentUser.uid),
      );

      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Gets all friends of the current user
  static Future<List<Map<String, dynamic>>> getFriends() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('friends')
          .orderBy('addedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'username': data['username'],
          'addedAt': data['addedAt'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Checks if a user is friends with another user
  static Future<bool> isFriend(String otherUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('friends')
          .doc(otherUid)
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Stream of friends for real-time updates
  static Stream<List<Map<String, dynamic>>> friendsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('friends')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'username': data['username'],
          'addedAt': data['addedAt'],
        };
      }).toList();
    });
  }

  /// Stream of pending requests for real-time updates
  static Stream<List<Map<String, dynamic>>> pendingRequestsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    // Simplified query to avoid composite index requirement
    // Filter by toUid and status, sort client-side
    return _firestore
        .collection('friend_requests')
        .where('toUid', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'requestId': doc.id,
          'fromUid': data['fromUid'],
          'fromUsername': data['fromUsername'],
          'createdAt': data['createdAt'],
        };
      }).toList();
      
      // Sort by createdAt on the client side
      requests.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // Descending order
      });
      
      return requests;
    });
  }
}
