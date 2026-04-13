/// Model for Pig Dice game state and scoring
class PigGame {
  static const int maxTurns = 20; // Turn limit to prevent infinite games
  static const int winningScore = 100; // Score needed to win
  
  final String gameId;
  final int diceValue; // Current die value (1-6)
  final int turnScore; // Score accumulated this turn (not yet banked)
  final int totalScore; // Total banked score
  final int currentTurn; // Current turn number (1-20)
  final bool isPigOut; // Whether the last roll was a 1
  final bool hasRolled; // Whether player has rolled this turn

  const PigGame({
    required this.gameId,
    this.diceValue = 1,
    this.turnScore = 0,
    this.totalScore = 0,
    this.currentTurn = 1,
    this.isPigOut = false,
    this.hasRolled = false,
  });

  PigGame copyWith({
    String? gameId,
    int? diceValue,
    int? turnScore,
    int? totalScore,
    int? currentTurn,
    bool? isPigOut,
    bool? hasRolled,
  }) {
    return PigGame(
      gameId: gameId ?? this.gameId,
      diceValue: diceValue ?? this.diceValue,
      turnScore: turnScore ?? this.turnScore,
      totalScore: totalScore ?? this.totalScore,
      currentTurn: currentTurn ?? this.currentTurn,
      isPigOut: isPigOut ?? this.isPigOut,
      hasRolled: hasRolled ?? this.hasRolled,
    );
  }
}

/// Leaderboard score entry for Pig Dice
class PigScore {
  final String username;
  final int score;
  final DateTime timestamp;
  final String userId;

  const PigScore({
    required this.username,
    required this.score,
    required this.timestamp,
    required this.userId,
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'score': score,
    'timestamp': timestamp.toIso8601String(),
    'userId': userId,
  };

  factory PigScore.fromJson(Map<String, dynamic> json) => PigScore(
    username: json['username'] as String,
    score: json['score'] as int,
    timestamp: DateTime.parse(json['timestamp'] as String),
    userId: json['userId'] as String,
  );
}
