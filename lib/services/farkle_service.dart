import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/farkle_game.dart';

/// Service for managing Farkle leaderboard scores
class FarkleService {
  static final _firestore = FirebaseFirestore.instance;

  /// Submit a score to the Farkle leaderboard
  static Future<void> submitScore({
    required String userId,
    required String username,
    required int score,
  }) async {
    final scoreEntry = FarkleScore(
      username: username,
      score: score,
      timestamp: DateTime.now(),
      userId: userId,
    );

    await _firestore
        .collection('farkle_leaderboard')
        .add(scoreEntry.toJson());
  }

  /// Get top N scores from the leaderboard
  /// For ties, most recent score appears first
  static Future<List<FarkleScore>> getTopScores({int limit = 15}) async {
    final snapshot = await _firestore
        .collection('farkle_leaderboard')
        .orderBy('score', descending: true)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => FarkleScore.fromJson(doc.data()))
        .toList();
  }

  /// Get user's personal best score
  static Future<FarkleScore?> getUserBestScore(String userId) async {
    final snapshot = await _firestore
        .collection('farkle_leaderboard')
        .where('userId', isEqualTo: userId)
        .orderBy('score', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return FarkleScore.fromJson(snapshot.docs.first.data());
  }

  /// Get user's rank on the leaderboard (1-based)
  /// Returns null if user has no scores
  static Future<int?> getUserRank(String userId) async {
    final userBest = await getUserBestScore(userId);
    if (userBest == null) return null;

    // Count how many scores are better
    final betterScoresQuery = await _firestore
        .collection('farkle_leaderboard')
        .where('score', isGreaterThan: userBest.score)
        .get();

    // Also count scores equal but with earlier timestamp
    final equalScoresQuery = await _firestore
        .collection('farkle_leaderboard')
        .where('score', isEqualTo: userBest.score)
        .where('timestamp', isGreaterThan: userBest.timestamp.toIso8601String())
        .get();

    return betterScoresQuery.docs.length + equalScoresQuery.docs.length + 1;
  }

  /// Get total number of scores in leaderboard
  static Future<int> getTotalScoresCount() async {
    final snapshot = await _firestore
        .collection('farkle_leaderboard')
        .count()
        .get();

    return snapshot.count ?? 0;
  }
}
