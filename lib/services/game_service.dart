import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/saved_game.dart';
import '../models/dice_config.dart';
import 'profanity_filter.dart';
import 'settings_service.dart';

/// Service for managing game saves in Firestore
class GameService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Saves a game privately for the current user
  /// Private games are NOT filtered - users can write whatever they want
  static Future<String> saveGame({
    required String name,
    required String generalRules,
    required List<DiceConfig> diceConfigs,
    String? gameId, // If updating existing game
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // No profanity filter for private games - save as-is
    final docId = gameId ?? _firestore.collection('users').doc().id;
    
    final game = SavedGame(
      id: docId,
      name: name,
      generalRules: generalRules,
      dice: diceConfigs,
      isPublic: false,
      creatorUid: user.uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save to user's private games collection
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('games')
        .doc(docId)
        .set(game.toJson());

    return docId;
  }

  /// Publishes a game (saves and submits for moderation)
  /// Public games ARE filtered based on user's profanity filter setting
  static Future<String> publishGame({
    required String name,
    required String generalRules,
    required List<DiceConfig> diceConfigs,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Get profanity filter setting
    final filterEnabled = await SettingsService.getProfanityFilterEnabled();

    // Apply profanity filter
    final filteredName = ProfanityFilter.filter(name, enabled: filterEnabled);
    final filteredRules = ProfanityFilter.filter(
      generalRules,
      enabled: filterEnabled,
    );

    // Filter face rules
    final filteredDiceConfigs = diceConfigs.map((config) {
      final filteredFaceRules = config.faceRules?.map(
        (face, rule) => MapEntry(
          face,
          ProfanityFilter.filter(rule, enabled: filterEnabled),
        ),
      );
      return DiceConfig(
        label: config.label,
        sides: config.sides,
        faceRules: filteredFaceRules,
      );
    }).toList();

    final gameId = _firestore.collection('pendingGames').doc().id;
    
    final game = SavedGame(
      id: gameId,
      name: filteredName,
      generalRules: filteredRules,
      dice: filteredDiceConfigs,
      isPublic: true,
      creatorUid: user.uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save to pending moderation collection
    await _firestore
        .collection('pendingGames')
        .doc(gameId)
        .set(game.toJson());

    // Also save to user's private games
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('games')
        .doc(gameId)
        .set(game.toJson());

    return gameId;
  }

  /// Loads all games for the current user
  static Future<List<SavedGame>> loadUserGames() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('games')
        .orderBy('updatedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => SavedGame.fromJson(doc.data()))
        .toList();
  }

  /// Loads a specific game by ID
  static Future<SavedGame?> loadGame(String gameId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('games')
        .doc(gameId)
        .get();

    if (!doc.exists) return null;
    return SavedGame.fromJson(doc.data()!);
  }

  /// Finds a game by name for the current user
  static Future<SavedGame?> findGameByName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('games')
        .where('name', isEqualTo: name)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return SavedGame.fromJson(snapshot.docs.first.data());
  }

  /// Deletes a game
  static Future<void> deleteGame(String gameId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('games')
        .doc(gameId)
        .delete();
  }

  /// Loads all approved public games from the community
  static Future<List<SavedGame>> loadPublicGames({int limit = 50}) async {
    final snapshot = await _firestore
        .collection('publicGames')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => SavedGame.fromJson(doc.data()))
        .toList();
  }

  /// Copies a public game to the current user's library
  /// Creates a new instance so the user has their own copy
  static Future<String> copyPublicGameToLibrary(SavedGame game) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Check if user already has a game with this name
    final existing = await findGameByName(game.name);
    String gameName = game.name;
    
    // If name exists, append " (Copy)" or " (Copy N)"
    if (existing != null) {
      int copyNumber = 1;
      while (await findGameByName('$gameName (Copy${copyNumber > 1 ? ' $copyNumber' : ''})') != null) {
        copyNumber++;
      }
      gameName = '$gameName (Copy${copyNumber > 1 ? ' $copyNumber' : ''})';
    }

    // Create a new document ID for this user's copy
    final newDocId = _firestore.collection('users').doc().id;
    
    final copiedGame = SavedGame(
      id: newDocId,
      name: gameName,
      generalRules: game.generalRules,
      dice: game.dice,
      isPublic: false, // User's copy is private by default
      creatorUid: user.uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save to user's private games collection
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('games')
        .doc(newDocId)
        .set(copiedGame.toJson());

    return newDocId;
  }

  // =========================================================================
  // MODERATOR METHODS
  // =========================================================================

  /// Loads all pending games awaiting moderation (moderator only)
  static Future<List<SavedGame>> loadPendingGames({int limit = 50}) async {
    final snapshot = await _firestore
        .collection('pendingGames')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => SavedGame.fromJson(doc.data()))
        .toList();
  }

  /// Approves a pending game and moves it to public games (moderator only)
  static Future<void> approveGame(String gameId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Get the pending game
    final pendingDoc = await _firestore
        .collection('pendingGames')
        .doc(gameId)
        .get();

    if (!pendingDoc.exists) {
      throw Exception('Game not found in pending queue');
    }

    final gameData = pendingDoc.data()!;
    
    // Move to publicGames collection
    await _firestore
        .collection('publicGames')
        .doc(gameId)
        .set({
      ...gameData,
      'approvedAt': DateTime.now().toIso8601String(),
      'approvedBy': user.uid,
    });

    // Remove from pending
    await _firestore
        .collection('pendingGames')
        .doc(gameId)
        .delete();
  }

  /// Rejects a pending game and optionally provides a reason (moderator only)
  static Future<void> rejectGame(String gameId, {String? reason}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Get the pending game
    final pendingDoc = await _firestore
        .collection('pendingGames')
        .doc(gameId)
        .get();

    if (!pendingDoc.exists) {
      throw Exception('Game not found in pending queue');
    }

    final gameData = pendingDoc.data()!;
    
    // Move to rejectedGames collection for record-keeping
    await _firestore
        .collection('rejectedGames')
        .doc(gameId)
        .set({
      ...gameData,
      'rejectedAt': DateTime.now().toIso8601String(),
      'rejectedBy': user.uid,
      if (reason != null) 'rejectionReason': reason,
    });

    // Remove from pending
    await _firestore
        .collection('pendingGames')
        .doc(gameId)
        .delete();
  }

  // =========================================================================
  // GAME SHARING METHODS
  // =========================================================================

  /// Shares a game with a friend
  /// If the game is public, it goes to their publicGames (saved by user)
  /// If the game is private, it goes to their private games
  /// In either case, the receiver cannot publish it (creator only)
  /// Check if a friend already has a game with this name
  static Future<bool> checkNameConflict(String friendUid, String gameName) async {
    final games = await _firestore
        .collection('users')
        .doc(friendUid)
        .collection('games')
        .where('name', isEqualTo: gameName)
        .limit(1)
        .get();

    return games.docs.isNotEmpty;
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

  static Future<void> shareGameWithFriend(
    String gameId,
    String friendUid, {
    String? conflictAction,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Get the game from creator's collection
    final gameDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('games')
        .doc(gameId)
        .get();

    if (!gameDoc.exists) {
      throw Exception('Game not found');
    }

    final gameData = Map<String, dynamic>.from(gameDoc.data()!);
    final now = DateTime.now().toIso8601String();

    // Handle name conflicts
    if (conflictAction == 'replace') {
      // Delete existing game(s) with same name
      final existingGames = await _firestore
          .collection('users')
          .doc(friendUid)
          .collection('games')
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
    final newDocId = _firestore.collection('users').doc().id;

    // Add sharedBy field to track who shared it
    gameData['id'] = newDocId;
    gameData['sharedBy'] = user.uid;
    gameData['sharedAt'] = now;
    gameData['updatedAt'] = now;

    // Save to friend's games collection
    await _firestore
        .collection('users')
        .doc(friendUid)
        .collection('games')
        .doc(newDocId)
        .set(gameData);
  }

  /// Gets all games shared with the current user
  static Future<List<SavedGame>> loadSharedGames() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('games')
        .where('sharedBy', isNotEqualTo: null)
        .orderBy('sharedBy')
        .orderBy('updatedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => SavedGame.fromJson(doc.data()))
        .toList();
  }
}
