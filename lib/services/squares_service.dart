import 'dart:async';
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
    
    // Check if this is a shared game being edited
    if (game.isShared) {
      // Shared games can only be saved privately to the user's shared_squares collection
      // They cannot be made public
      if (game.isPublic) {
        throw Exception('Cannot publish shared games - create your own copy first');
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('shared_squares')
          .doc(game.gameId)
          .set(data);
      return;
    }
    
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

    final data = game.toFirestore();
    
    // Check if this is a shared game
    if (game.isShared) {
      // Shared games can only be updated in the user's shared_squares collection
      // They cannot be made public
      if (game.isPublic) {
        throw Exception('Cannot publish shared games - create your own copy first');
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('shared_squares')
          .doc(game.gameId)
          .set(data);
      return;
    }

    // For owned games, verify user is the creator
    if (user.uid != game.creatorUid) throw Exception('Unauthorized');
    
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

    // Check main collections (owned games)
    final gameDoc = await _gamesCollection.doc(gameId).get();
    final pendingDoc = await _pendingGamesCollection.doc(gameId).get();

    if (gameDoc.exists) {
      final game = SquaresGame.fromFirestore(gameDoc.id, gameDoc.data() as Map<String, dynamic>);
      if (game.creatorUid != user.uid) throw Exception('Unauthorized');
      await _gamesCollection.doc(gameId).delete();
      return;
    } else if (pendingDoc.exists) {
      final game = SquaresGame.fromFirestore(pendingDoc.id, pendingDoc.data() as Map<String, dynamic>);
      if (game.creatorUid != user.uid) throw Exception('Unauthorized');
      await _pendingGamesCollection.doc(gameId).delete();
      return;
    }

    // Check shared_squares collection (shared games)
    final sharedDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shared_squares')
        .doc(gameId)
        .get();

    if (sharedDoc.exists) {
      await sharedDoc.reference.delete();
      return;
    }

    throw Exception('Game not found');
  }

  /// Check if a friend already has a game with this name
  static Future<bool> checkNameConflict(String friendUid, String gameName) async {
    // Check owned games
    final ownedGames = await _gamesCollection
        .where('creatorUid', isEqualTo: friendUid)
        .where('name', isEqualTo: gameName)
        .limit(1)
        .get();

    if (ownedGames.docs.isNotEmpty) return true;

    // Check shared games
    final sharedGames = await FirebaseFirestore.instance
        .collection('users')
        .doc(friendUid)
        .collection('shared_squares')
        .where('name', isEqualTo: gameName)
        .limit(1)
        .get();

    return sharedGames.docs.isNotEmpty;
  }

  /// Generate a unique numbered name if there's a conflict
  static Future<String> _generateNumberedName(String friendUid, String baseName) async {
    int counter = 1;
    String newName = '$baseName ($counter)';

    while (await checkNameConflict(friendUid, newName)) {
      counter++;
      newName = '$baseName ($counter)';
    }

    return newName;
  }

  /// Share a Squares game with a friend
  static Future<void> shareSquaresGameWithFriend(
    String gameId,
    String friendUid, {
    String? conflictAction,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Must be authenticated');

    // Try to get the game from user's shared collection first
    final sharedDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shared_squares')
        .doc(gameId)
        .get();

    Map<String, dynamic>? gameData;

    if (sharedDoc.exists) {
      // User has this as a shared game
      gameData = Map<String, dynamic>.from(sharedDoc.data() as Map<String, dynamic>);
    } else {
      // Try main collection (user-owned game)
      final gameDoc = await _gamesCollection.doc(gameId).get();
      
      if (!gameDoc.exists) {
        throw Exception('Game not found');
      }
      
      gameData = Map<String, dynamic>.from(gameDoc.data() as Map<String, dynamic>);
      
      // Verify user is the creator for owned games
      if (gameData['creatorUid'] != user.uid) {
        throw Exception('Game not found in your collection');
      }
    }

    // Handle name conflicts
    if (conflictAction == 'replace') {
      // Delete existing game(s) with same name
      final existingGames = await FirebaseFirestore.instance
          .collection('users')
          .doc(friendUid)
          .collection('shared_squares')
          .where('name', isEqualTo: gameData['name'])
          .get();

      for (var doc in existingGames.docs) {
        await doc.reference.delete();
      }
    } else if (conflictAction == 'keep_both') {
      // Generate numbered name
      gameData['name'] = await _generateNumberedName(friendUid, gameData['name'] as String);
    }

    // Create a shared copy for the friend
    gameData['sharedBy'] = user.uid;

    // Save to friend's shared_squares collection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(friendUid)
        .collection('shared_squares')
        .doc(gameId)
        .set(gameData);
  }

  /// Get current user's games (both owned and shared)
  static Stream<List<SquaresGame>> getMyGames() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    // Stream of owned games
    final ownedGamesStream = _gamesCollection
        .where('creatorUid', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => SquaresGame.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
              .toList();
        });

    // Stream of shared games
    final sharedGamesStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shared_squares')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => SquaresGame.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
              .toList();
        });

    // Combine both streams using async* generator
    return _combineGameStreams(ownedGamesStream, sharedGamesStream);
  }

  /// Helper to combine owned and shared game streams
  static Stream<List<SquaresGame>> _combineGameStreams(
    Stream<List<SquaresGame>> owned,
    Stream<List<SquaresGame>> shared,
  ) {
    final controller = StreamController<List<SquaresGame>>();
    List<SquaresGame> ownedGames = [];
    List<SquaresGame> sharedGames = [];

    void emitCombined() {
      controller.add([...ownedGames, ...sharedGames]);
    }

    owned.listen((games) {
      ownedGames = games;
      emitCombined();
    });

    shared.listen((games) {
      sharedGames = games;
      emitCombined();
    });

    return controller.stream;
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

  /// Load all pending games (moderators only)
  static Future<List<SquaresGame>> loadPendingGames() async {
    final snapshot = await _pendingGamesCollection.get();
    return snapshot.docs
        .map((doc) => SquaresGame.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
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
