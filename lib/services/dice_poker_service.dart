import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dice_poker_game.dart';

/// Service for Dice Poker leaderboard operations
class DicePokerService {
  static final _firestore = FirebaseFirestore.instance;
  static const _collection = 'dice_poker_leaderboard';

  /// Submit a score to the leaderboard
  static Future<void> submitScore(DicePokerScore score) async {
    await _firestore.collection(_collection).add(score.toJson());
  }

  /// Get top scores from the leaderboard
  static Future<List<DicePokerScore>> getTopScores({int limit = 15}) async {
    final querySnapshot = await _firestore
        .collection(_collection)
        .orderBy('score', descending: true)
        .orderBy('timestamp', descending: false) // Earlier scores rank higher in ties
        .limit(limit)
        .get();

    return querySnapshot.docs
        .map((doc) => DicePokerScore.fromFirestore(doc))
        .toList();
  }

  /// Get a user's best score
  static Future<DicePokerScore?> getUserBestScore(String userId) async {
    final querySnapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('score', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;
    return DicePokerScore.fromFirestore(querySnapshot.docs.first);
  }

  /// Get a user's rank on the leaderboard
  static Future<int?> getUserRank(String userId) async {
    final userBestScore = await getUserBestScore(userId);
    if (userBestScore == null) return null;

    // Count scores better than this user's best score
    final betterScoresQuery = await _firestore
        .collection(_collection)
        .where('score', isGreaterThan: userBestScore.score)
        .get();

    // Count scores equal to this user's but with earlier timestamp
    final tiedScoresQuery = await _firestore
        .collection(_collection)
        .where('score', isEqualTo: userBestScore.score)
        .where('timestamp', isLessThan: Timestamp.fromDate(userBestScore.timestamp))
        .get();

    return betterScoresQuery.docs.length + tiedScoresQuery.docs.length + 1;
  }

  /// Get total number of scores submitted
  static Future<int> getTotalScoresCount() async {
    final querySnapshot = await _firestore.collection(_collection).get();
    return querySnapshot.docs.length;
  }
}
