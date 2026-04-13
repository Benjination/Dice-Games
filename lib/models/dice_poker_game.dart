import 'package:cloud_firestore/cloud_firestore.dart';

/// Dice Poker game model for single-player mode
class DicePokerGame {
  final String gameId;
  final List<int> diceValues; // 5 dice, values 1-6
  final Set<int> lockedDice; // Indices of dice locked by player
  final int currentRound; // 1-5
  final int rollsLeft; // 0-3 per round
  final int totalScore; // Accumulated score across rounds
  final List<RoundResult> roundResults; // History of completed rounds
  final bool isGameOver;

  DicePokerGame({
    required this.gameId,
    List<int>? diceValues,
    Set<int>? lockedDice,
    this.currentRound = 1,
    this.rollsLeft = 3,
    this.totalScore = 0,
    List<RoundResult>? roundResults,
    this.isGameOver = false,
  })  : diceValues = diceValues ?? List.filled(5, 0),
        lockedDice = lockedDice ?? {},
        roundResults = roundResults ?? [];

  // Game constants
  static const int maxRounds = 5;
  static const int maxRollsPerRound = 3;

  DicePokerGame copyWith({
    List<int>? diceValues,
    Set<int>? lockedDice,
    int? currentRound,
    int? rollsLeft,
    int? totalScore,
    List<RoundResult>? roundResults,
    bool? isGameOver,
  }) {
    return DicePokerGame(
      gameId: gameId,
      diceValues: diceValues ?? List.from(this.diceValues),
      lockedDice: lockedDice ?? Set.from(this.lockedDice),
      currentRound: currentRound ?? this.currentRound,
      rollsLeft: rollsLeft ?? this.rollsLeft,
      totalScore: totalScore ?? this.totalScore,
      roundResults: roundResults ?? List.from(this.roundResults),
      isGameOver: isGameOver ?? this.isGameOver,
    );
  }

  /// Evaluate the current hand and return the hand type and score
  HandEvaluation evaluateHand() {
    if (diceValues.any((v) => v == 0)) {
      return HandEvaluation(HandType.none, 0);
    }

    final counts = <int, int>{};
    for (final value in diceValues) {
      counts[value] = (counts[value] ?? 0) + 1;
    }

    final sortedCounts = counts.values.toList()..sort((a, b) => b.compareTo(a));
    final sortedValues = diceValues.toList()..sort();

    // Five of a Kind
    if (sortedCounts.first == 5) {
      return HandEvaluation(HandType.fiveOfAKind, 1000);
    }

    // Four of a Kind
    if (sortedCounts.first == 4) {
      return HandEvaluation(HandType.fourOfAKind, 500);
    }

    // Full House (3 + 2)
    if (sortedCounts.length == 2 && sortedCounts.first == 3) {
      return HandEvaluation(HandType.fullHouse, 300);
    }

    // Straight (1-2-3-4-5 or 2-3-4-5-6)
    if (_isStraight(sortedValues)) {
      return HandEvaluation(HandType.straight, 250);
    }

    // Three of a Kind
    if (sortedCounts.first == 3) {
      return HandEvaluation(HandType.threeOfAKind, 200);
    }

    // Two Pair
    if (sortedCounts.length == 3 && sortedCounts.take(2).where((c) => c == 2).length == 2) {
      return HandEvaluation(HandType.twoPair, 150);
    }

    // One Pair
    if (sortedCounts.first == 2) {
      return HandEvaluation(HandType.onePair, 100);
    }

    // High Card (nothing)
    return HandEvaluation(HandType.highCard, 50);
  }

  bool _isStraight(List<int> sorted) {
    // Check for 1-2-3-4-5
    if (sorted[0] == 1 && sorted[1] == 2 && sorted[2] == 3 && sorted[3] == 4 && sorted[4] == 5) {
      return true;
    }
    // Check for 2-3-4-5-6
    if (sorted[0] == 2 && sorted[1] == 3 && sorted[2] == 4 && sorted[3] == 5 && sorted[4] == 6) {
      return true;
    }
    return false;
  }
}

/// Types of poker hands
enum HandType {
  none,
  highCard,
  onePair,
  twoPair,
  threeOfAKind,
  straight,
  fullHouse,
  fourOfAKind,
  fiveOfAKind,
}

extension HandTypeExtension on HandType {
  String get displayName {
    switch (this) {
      case HandType.none:
        return 'No Hand';
      case HandType.highCard:
        return 'High Card';
      case HandType.onePair:
        return 'One Pair';
      case HandType.twoPair:
        return 'Two Pair';
      case HandType.threeOfAKind:
        return 'Three of a Kind';
      case HandType.straight:
        return 'Straight';
      case HandType.fullHouse:
        return 'Full House';
      case HandType.fourOfAKind:
        return 'Four of a Kind';
      case HandType.fiveOfAKind:
        return 'Five of a Kind';
    }
  }
}

/// Result of evaluating a hand
class HandEvaluation {
  final HandType handType;
  final int score;

  HandEvaluation(this.handType, this.score);
}

/// Result of a completed round
class RoundResult {
  final int round;
  final HandType handType;
  final int score;
  final List<int> diceValues;

  RoundResult({
    required this.round,
    required this.handType,
    required this.score,
    required this.diceValues,
  });

  Map<String, dynamic> toJson() => {
        'round': round,
        'handType': handType.name,
        'score': score,
        'diceValues': diceValues,
      };

  factory RoundResult.fromJson(Map<String, dynamic> json) => RoundResult(
        round: json['round'] as int,
        handType: HandType.values.firstWhere((e) => e.name == json['handType']),
        score: json['score'] as int,
        diceValues: List<int>.from(json['diceValues'] as List),
      );
}

/// Leaderboard score entry for Dice Poker
class DicePokerScore {
  final String username;
  final int score;
  final DateTime timestamp;
  final String userId;
  final List<RoundResult> rounds;

  DicePokerScore({
    required this.username,
    required this.score,
    required this.timestamp,
    required this.userId,
    required this.rounds,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'score': score,
        'timestamp': Timestamp.fromDate(timestamp),
        'userId': userId,
        'rounds': rounds.map((r) => r.toJson()).toList(),
      };

  factory DicePokerScore.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DicePokerScore(
      username: data['username'] as String,
      score: data['score'] as int,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      userId: data['userId'] as String,
      rounds: (data['rounds'] as List)
          .map((r) => RoundResult.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}
