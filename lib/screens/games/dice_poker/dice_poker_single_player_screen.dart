import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/dice_poker_game.dart';
import '../../../services/dice_poker_service.dart';
import '../../../services/user_service.dart';
import '../../../theme/dark_academia_theme.dart';
import '../../auth/login_screen.dart';
import './dice_poker_leaderboard_screen.dart';

/// Single-player Dice Poker game screen
class DicePokerSinglePlayerScreen extends StatefulWidget {
  const DicePokerSinglePlayerScreen({super.key});

  @override
  State<DicePokerSinglePlayerScreen> createState() => _DicePokerSinglePlayerScreenState();
}

class _DicePokerSinglePlayerScreenState extends State<DicePokerSinglePlayerScreen> {
  late DicePokerGame _game;
  final _random = Random();
  bool _isRolling = false;
  String? _message;
  bool _gameOver = false;

  // Animation state
  Timer? _animationTimer;
  Set<int> _animatingDice = {};
  List<int> _finalDiceValues = List.filled(5, 0);

  @override
  void initState() {
    super.initState();
    _game = DicePokerGame(
      gameId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  void _showRules() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Dice Poker Rules',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Goal:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text('• Play 5 rounds and score as many points as possible'),
              const Text('• Make the best poker hands with 5 dice'),
              const SizedBox(height: 16),
              const Text(
                'How to Play:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text('• Roll all dice at the start of each round'),
              const Text('• Tap dice to lock/unlock them'),
              const Text('• Re-roll unlocked dice (3 rolls per round)'),
              const Text('• Finish round to lock in your hand and score'),
              const SizedBox(height: 16),
              const Text(
                'Scoring:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text('• Five of a Kind = 1,000 points'),
              const Text('• Four of a Kind = 500 points'),
              const Text('• Full House = 300 points'),
              const Text('• Straight (1-2-3-4-5 or 2-3-4-5-6) = 250 points'),
              const Text('• Three of a Kind = 200 points'),
              const Text('• Two Pair = 150 points'),
              const Text('• One Pair = 100 points'),
              const Text('• High Card = 50 points'),
              const SizedBox(height: 16),
              const Text(
                'Strategy:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text('• Lock good dice, re-roll bad ones'),
              const Text('• Sometimes settle early to avoid risk'),
              const Text('• Higher hands = more points!'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _rollDice() {
    if (_isRolling || _game.rollsLeft == 0) return;

    setState(() {
      _isRolling = true;
      _message = null;
    });

    // Cancel any existing animation
    _animationTimer?.cancel();

    // Prepare final values for unlocked dice
    final newValues = List<int>.from(_game.diceValues);
    final unlockedDice = <int>[];

    for (int i = 0; i < 5; i++) {
      if (!_game.lockedDice.contains(i)) {
        unlockedDice.add(i);
        _finalDiceValues[i] = _random.nextInt(6) + 1;
        newValues[i] = _finalDiceValues[i];
        _animatingDice.add(i);
      }
    }

    // Start rapid cycling animation (50ms updates)
    _animationTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          final tempValues = List<int>.from(_game.diceValues);
          for (final index in _animatingDice) {
            tempValues[index] = _random.nextInt(6) + 1;
          }
          _game = _game.copyWith(diceValues: tempValues);
        });
      },
    );

    // Schedule cascade locking of dice (1.0s, 1.15s, 1.30s, etc.)
    for (int i = 0; i < unlockedDice.length; i++) {
      final dieIndex = unlockedDice[i];
      final lockDelay = Duration(milliseconds: 1000 + (i * 150));

      Timer(lockDelay, () {
        if (!mounted) return;

        setState(() {
          _animatingDice.remove(dieIndex);
          final tempValues = List<int>.from(_game.diceValues);
          tempValues[dieIndex] = _finalDiceValues[dieIndex];
          _game = _game.copyWith(diceValues: tempValues);
        });

        // If this was the last die, finalize the roll
        if (_animatingDice.isEmpty) {
          _animationTimer?.cancel();
          setState(() {
            _game = _game.copyWith(
              diceValues: newValues,
              rollsLeft: _game.rollsLeft - 1,
            );
            _isRolling = false;

            // Evaluate and show current hand
            final evaluation = _game.evaluateHand();
            if (evaluation.handType != HandType.none) {
              _message = '${evaluation.handType.displayName} - ${evaluation.score} pts';
            }
          });
        }
      });
    }
  }

  void _toggleDiceLock(int index) {
    if (_isRolling || _game.diceValues[index] == 0) return;

    setState(() {
      final newLockedDice = Set<int>.from(_game.lockedDice);
      if (newLockedDice.contains(index)) {
        newLockedDice.remove(index);
      } else {
        newLockedDice.add(index);
      }
      _game = _game.copyWith(lockedDice: newLockedDice);
    });
  }

  void _finishRound() {
    if (_game.diceValues.any((v) => v == 0)) {
      setState(() {
        _message = 'You must roll at least once!';
      });
      return;
    }

    final evaluation = _game.evaluateHand();
    final roundResult = RoundResult(
      round: _game.currentRound,
      handType: evaluation.handType,
      score: evaluation.score,
      diceValues: List.from(_game.diceValues),
    );

    final newRoundResults = List<RoundResult>.from(_game.roundResults)..add(roundResult);
    final newTotalScore = _game.totalScore + evaluation.score;

    if (_game.currentRound >= DicePokerGame.maxRounds) {
      // Game over
      setState(() {
        _game = _game.copyWith(
          totalScore: newTotalScore,
          roundResults: newRoundResults,
          isGameOver: true,
        );
        _gameOver = true;
      });
      _handleGameOver();
    } else {
      // Next round
      setState(() {
        _game = _game.copyWith(
          diceValues: List.filled(5, 0),
          lockedDice: {},
          currentRound: _game.currentRound + 1,
          rollsLeft: DicePokerGame.maxRollsPerRound,
          totalScore: newTotalScore,
          roundResults: newRoundResults,
        );
        _message = 'Round ${_game.currentRound} - Roll to start!';
      });
    }
  }

  Future<void> _handleGameOver() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Guest user - show auth prompt
      if (!mounted) return;
      final shouldAuth = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Game Over!'),
          content: Text(
            'Final Score: ${_game.totalScore} points\n\n'
            'Sign up or log in to save your score to the leaderboard!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign Up / Log In'),
            ),
          ],
        ),
      );

      if (shouldAuth == true && mounted) {
        // Navigate to login
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
        );

        // If user logged/signed up successfully, submit score
        if (result == true && mounted) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await _saveScore();
          }
        }
      }
    } else {
      // Logged-in user - save score
      await _saveScore();
    }
  }

  Future<void> _saveScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final username = await UserService.getCurrentUsername() ?? 'Anonymous';
      final score = DicePokerScore(
        username: username,
        score: _game.totalScore,
        timestamp: DateTime.now(),
        userId: user.uid,
        rounds: _game.roundResults,
      );

      await DicePokerService.submitScore(score);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Score Saved!'),
          content: Text('Final Score: ${_game.totalScore} points'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const DicePokerLeaderboardScreen(),
                  ),
                );
              },
              child: const Text('View Leaderboard'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Restart game
                setState(() {
                  _game = DicePokerGame(
                    gameId: DateTime.now().millisecondsSinceEpoch.toString(),
                  );
                  _gameOver = false;
                  _message = null;
                });
              },
              child: const Text('Play Again'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving score: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final evaluation = _game.evaluateHand();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dice Poker'),
        actions: [
          IconButton(
            onPressed: _showRules,
            icon: const Icon(Icons.info_outline),
            tooltip: 'Rules',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DicePokerLeaderboardScreen(),
                ),
              );
            },
            icon: const Icon(Icons.leaderboard),
            tooltip: 'Leaderboard',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Score and round info
            Container(
              padding: const EdgeInsets.all(16),
              color: DarkAcademiaColors.navyBlue.withValues(alpha: 0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoCard('Total Score', _game.totalScore.toString()),
                  _buildInfoCard('Round', '${_game.currentRound}/${DicePokerGame.maxRounds}'),
                  _buildInfoCard('Rolls Left', _game.rollsLeft.toString()),
                ],
              ),
            ),

            // Current hand
            if (evaluation.handType != HandType.none)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                color: DarkAcademiaColors.deepForestGreen.withValues(alpha: 0.2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.casino,
                      color: DarkAcademiaColors.antiqueBrass,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      evaluation.handType.displayName,
                      style: const TextStyle(
                        color: DarkAcademiaColors.antiqueBrass,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${evaluation.score} pts',
                      style: const TextStyle(
                        color: DarkAcademiaColors.cream,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Dice display
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: List.generate(5, (index) {
                          final isLocked = _game.lockedDice.contains(index);
                          final dieValue = _game.diceValues[index];
                          return _buildDie(index, dieValue, isLocked);
                        }),
                      ),
                      const SizedBox(height: 24),

                      // Message
                      if (_message != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: DarkAcademiaColors.navyBlue.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _message!,
                            style: const TextStyle(
                              color: DarkAcademiaColors.cream,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isRolling || _game.rollsLeft == 0 || _gameOver)
                                  ? null
                                  : _rollDice,
                              icon: const Icon(Icons.casino),
                              label: Text(_game.rollsLeft == 3 ? 'Start Rolling' : 'Roll Again'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: DarkAcademiaColors.deepForestGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isRolling ||
                                      _game.diceValues.any((v) => v == 0) ||
                                      _gameOver)
                                  ? null
                                  : _finishRound,
                              icon: const Icon(Icons.check_circle),
                              label: Text(_game.currentRound == DicePokerGame.maxRounds
                                  ? 'Finish Game'
                                  : 'Finish Round'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: DarkAcademiaColors.antiqueBrass,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Round history
                      if (_game.roundResults.isNotEmpty) ...[
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          'Round History',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: DarkAcademiaColors.antiqueBrass,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        ..._game.roundResults.map((result) => _buildRoundHistoryCard(result)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: DarkAcademiaColors.cream,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: DarkAcademiaColors.antiqueBrass,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDie(int index, int value, bool isLocked) {
    return GestureDetector(
      onTap: () => _toggleDiceLock(index),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isLocked
              ? DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.3)
              : DarkAcademiaColors.charcoalGray.withValues(alpha: 0.5),
          border: Border.all(
            color: isLocked ? DarkAcademiaColors.antiqueBrass : DarkAcademiaColors.cream,
            width: isLocked ? 3 : 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: value > 0
            ? Image.asset(
                'assets/images/dice-images/6.$value.png',
                fit: BoxFit.contain,
              )
            : const Icon(
                Icons.help_outline,
                color: DarkAcademiaColors.cream,
                size: 32,
              ),
      ),
    );
  }

  Widget _buildRoundHistoryCard(RoundResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: DarkAcademiaColors.charcoalGray.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DarkAcademiaColors.deepForestGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  '${result.round}',
                  style: const TextStyle(
                    color: DarkAcademiaColors.cream,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.handType.displayName,
                    style: const TextStyle(
                      color: DarkAcademiaColors.cream,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.diceValues.join(' - '),
                    style: TextStyle(
                      color: DarkAcademiaColors.cream.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '+${result.score}',
              style: const TextStyle(
                color: DarkAcademiaColors.antiqueBrass,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
