/// Model for Farkle game state and scoring
class FarkleGame {
  final String gameId;
  final List<int> availableDice; // Indices of dice not yet banked (0-5)
  final List<int> selectedDice; // Indices of dice selected this roll
  final List<int> diceValues; // Current values of all 6 dice
  final int turnScore; // Score accumulated this turn (not yet banked)
  final int totalScore; // Total banked score
  final int rollsThisTurn; // Number of rolls taken this turn
  final bool isFarkle; // Whether the last roll was a farkle

  const FarkleGame({
    required this.gameId,
    this.availableDice = const [0, 1, 2, 3, 4, 5],
    this.selectedDice = const [],
    this.diceValues = const [1, 1, 1, 1, 1, 1],
    this.turnScore = 0,
    this.totalScore = 0,
    this.rollsThisTurn = 0,
    this.isFarkle = false,
  });

  FarkleGame copyWith({
    String? gameId,
    List<int>? availableDice,
    List<int>? selectedDice,
    List<int>? diceValues,
    int? turnScore,
    int? totalScore,
    int? rollsThisTurn,
    bool? isFarkle,
  }) {
    return FarkleGame(
      gameId: gameId ?? this.gameId,
      availableDice: availableDice ?? this.availableDice,
      selectedDice: selectedDice ?? this.selectedDice,
      diceValues: diceValues ?? this.diceValues,
      turnScore: turnScore ?? this.turnScore,
      totalScore: totalScore ?? this.totalScore,
      rollsThisTurn: rollsThisTurn ?? this.rollsThisTurn,
      isFarkle: isFarkle ?? this.isFarkle,
    );
  }
}

/// Scoring logic for Farkle
class FarkleScoring {
  /// Calculate score for selected dice
  static int calculateScore(List<int> diceValues) {
    if (diceValues.isEmpty) return 0;

    // Count occurrences of each face value (1-6)
    final counts = List<int>.filled(7, 0); // Index 0 unused, 1-6 for die faces
    for (final value in diceValues) {
      if (value >= 1 && value <= 6) {
        counts[value]++;
      }
    }

    int score = 0;

    // Check for straight (1-2-3-4-5-6)
    if (diceValues.length == 6 && 
        counts.sublist(1).every((count) => count == 1)) {
      return 1500;
    }

    // Check for three pairs
    if (diceValues.length == 6) {
      final pairs = counts.sublist(1).where((count) => count == 2).length;
      if (pairs == 3) {
        return 1500;
      }
    }

    // Score multiples (3+ of a kind)
    for (int face = 1; face <= 6; face++) {
      final count = counts[face];
      if (count >= 3) {
        // Base score for three of a kind
        int baseScore = face == 1 ? 1000 : face * 100;
        
        // Multiply for 4, 5, or 6 of a kind
        if (count == 4) {
          score += baseScore * 2;
        } else if (count == 5) {
          score += baseScore * 3;
        } else if (count == 6) {
          score += baseScore * 4;
        } else {
          score += baseScore;
        }
        
        // Mark these as scored
        counts[face] = 0;
      }
    }

    // Score remaining 1s and 5s (not part of multiples)
    score += counts[1] * 100; // Each 1 = 100 points
    score += counts[5] * 50;  // Each 5 = 50 points

    return score;
  }

  /// Check if any scoring combinations exist in the given dice
  static bool hasScoring(List<int> diceValues) {
    return calculateScore(diceValues) > 0;
  }

  /// Check if the selected dice contain valid scoring combinations
  static bool isValidSelection(List<int> selectedValues) {
    if (selectedValues.isEmpty) return false;
    return hasScoring(selectedValues);
  }

  /// Get all valid scoring combinations from a roll
  static List<ScoringCombo> getScoringCombos(List<int> diceValues) {
    final combos = <ScoringCombo>[];
    
    final counts = List<int>.filled(7, 0);
    for (final value in diceValues) {
      if (value >= 1 && value <= 6) {
        counts[value]++;
      }
    }

    // Check for straight
    if (diceValues.length == 6 && 
        counts.sublist(1).every((count) => count == 1)) {
      combos.add(ScoringCombo('Straight (1-2-3-4-5-6)', 1500));
    }

    // Check for three pairs
    if (diceValues.length == 6) {
      final pairs = counts.sublist(1).where((count) => count == 2).length;
      if (pairs == 3) {
        combos.add(ScoringCombo('Three Pairs', 1500));
      }
    }

    // Multiples
    for (int face = 1; face <= 6; face++) {
      final count = counts[face];
      if (count >= 3) {
        int baseScore = face == 1 ? 1000 : face * 100;
        String label;
        int score;
        
        if (count == 6) {
          label = 'Six ${face}s';
          score = baseScore * 4;
        } else if (count == 5) {
          label = 'Five ${face}s';
          score = baseScore * 3;
        } else if (count == 4) {
          label = 'Four ${face}s';
          score = baseScore * 2;
        } else {
          label = 'Three ${face}s';
          score = baseScore;
        }
        combos.add(ScoringCombo(label, score));
      }
    }

    // Individual 1s and 5s
    if (counts[1] > 0 && counts[1] < 3) {
      combos.add(ScoringCombo('${counts[1]} × 1', counts[1] * 100));
    }
    if (counts[5] > 0 && counts[5] < 3) {
      combos.add(ScoringCombo('${counts[5]} × 5', counts[5] * 50));
    }

    return combos;
  }
}

/// Represents a scoring combination found in dice
class ScoringCombo {
  final String label;
  final int score;

  const ScoringCombo(this.label, this.score);
}

/// Leaderboard entry
class FarkleScore {
  final String username;
  final int score;
  final DateTime timestamp;
  final String userId;

  const FarkleScore({
    required this.username,
    required this.score,
    required this.timestamp,
    required this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'score': score,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
    };
  }

  factory FarkleScore.fromJson(Map<String, dynamic> json) {
    return FarkleScore(
      username: json['username'] as String,
      score: json['score'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String,
    );
  }
}
