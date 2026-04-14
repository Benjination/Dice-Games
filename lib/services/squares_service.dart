import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/squares_game.dart';

/// Service for managing Squares games in Firestore
class SquaresService {
  static final _firestore = FirebaseFirestore.instance;
  
  // Collection references
  static CollectionReference get _gamesCollection => 
      _firestore.collection('squares_games');
  static CollectionReference get _pendingGamesCollection => 
      _firestore.collection('pending_squares_games');

  /// Save a game (private or submission for public approval)
  static Future<void> saveGame(SquaresGame game) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Must be authenticated to save games');

    final data = game.toFirestore();
    
    if (game.isPublic) {
      // Public games go to pending for moderation
      await _pendingGamesCollection.doc(game.gameId).set(data);
    } else {
      // Private games go directly to main collection
      await _gamesCollection.doc(game.gameId).set(data);
    }
  }

  /// Update an existing game
  static Future<void> updateGame(SquaresGame game) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Must be authenticated to update games');
    if (user.uid != game.creatorUid) throw Exception('Unauthorized');

    final data = game.toFirestore();
    
    if (game.isPublic) {
      // If changing to public, move to pending
      await _gamesCollection.doc(game.gameId).delete();
      await _pendingGamesCollection.doc(game.gameId).set(data);
    } else {
      // If private or already approved, update in main collection
      await _gamesCollection.doc(game.gameId).set(data);
    }
  }

  /// Delete a game (creator only)
  static Future<void> deleteGame(String gameId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Must be authenticated');

    // Check both collections
    final gameDoc = await _gamesCollection.doc(gameId).get();
    final pendingDoc = await _pendingGamesCollection.doc(gameId).get();

    if (gameDoc.exists) {
      final game = SquaresGame.fromFirestore(gameDoc.id, gameDoc.data() as Map<String, dynamic>);
      if (game.creatorUid != user.uid) throw Exception('Unauthorized');
      await _gamesCollection.doc(gameId).delete();
    } else if (pendingDoc.exists) {
      final game = SquaresGame.fromFirestore(pendingDoc.id, pendingDoc.data() as Map<String, dynamic>);
      if (game.creatorUid != user.uid) throw Exception('Unauthorized');
      await _pendingGamesCollection.doc(gameId).delete();
    }
  }

  /// Get current user's games (both private and approved public)
  static Stream<List<SquaresGame>> getMyGames() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return _gamesCollection
        .where('creatorUid', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => SquaresGame.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
              .toList();
        });
  }

  /// Get current user's pending submissions
  static Stream<List<SquaresGame>> getMyPendingGames() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return _pendingGamesCollection
        .where('creatorUid', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => SquaresGame.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
              .toList();
        });
  }

  /// Get all public approved games
  static Stream<List<SquaresGame>> getPublicGames({String? category}) {
    Query query = _gamesCollection.where('isPublic', isEqualTo: true);
    
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => SquaresGame.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  /// Get a single game by ID
  static Future<SquaresGame?> getGame(String gameId) async {
    // Check main collection first
    final doc = await _gamesCollection.doc(gameId).get();
    if (doc.exists) {
      return SquaresGame.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
    }

    // Check pending collection
    final pendingDoc = await _pendingGamesCollection.doc(gameId).get();
    if (pendingDoc.exists) {
      return SquaresGame.fromFirestore(pendingDoc.id, pendingDoc.data() as Map<String, dynamic>);
    }

    return null;
  }

  // === MODERATOR FUNCTIONS ===

  /// Get all pending games (moderators only)
  static Stream<List<SquaresGame>> getPendingGames() {
    return _pendingGamesCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => SquaresGame.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  /// Approve a pending game (moderators only)
  static Future<void> approveGame(String gameId, {String? updatedCategory}) async {
    final pendingDoc = await _pendingGamesCollection.doc(gameId).get();
    if (!pendingDoc.exists) throw Exception('Game not found in pending');

    final game = SquaresGame.fromFirestore(pendingDoc.id, pendingDoc.data() as Map<String, dynamic>);
    
    // Update category if moderator changed it
    final finalGame = updatedCategory != null 
        ? game.copyWith(category: updatedCategory)
        : game;

    // Move to main collection
    await _gamesCollection.doc(gameId).set(finalGame.toFirestore());
    
    // Remove from pending
    await _pendingGamesCollection.doc(gameId).delete();
  }

  /// Reject a pending game (moderators only)
  static Future<void> rejectGame(String gameId) async {
    await _pendingGamesCollection.doc(gameId).delete();
  }

  /// Get unique categories from all public games
  static Future<List<String>> getCategories() async {
    final snapshot = await _gamesCollection
        .where('isPublic', isEqualTo: true)
        .get();
    
    final categories = <String>{};
    for (final doc in snapshot.docs) {
      final game = SquaresGame.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
      categories.add(game.category);
    }
    
    return categories.toList()..sort();
  }
}
