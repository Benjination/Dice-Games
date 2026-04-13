import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/farkle_game.dart';
import '../../../services/farkle_service.dart';
import '../../../services/user_service.dart';
import '../../../theme/dark_academia_theme.dart';
import '../../auth/login_screen.dart';
import './farkle_leaderboard_screen.dart';

/// Single-player Farkle game screen
class FarkleSinglePlayerScreen extends StatefulWidget {
  const FarkleSinglePlayerScreen({super.key});

  @override
  State<FarkleSinglePlayerScreen> createState() => _FarkleSinglePlayerScreenState();
}

class _FarkleSinglePlayerScreenState extends State<FarkleSinglePlayerScreen> {
  late FarkleGame _game;
  final _random = Random();
  bool _isRolling = false;
  String? _message;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _game = FarkleGame(
      gameId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  void _rollDice() {
    if (_game.selectedDice.isNotEmpty) {
      // Must bank or clear selection before rolling
      return;
    }

    setState(() {
      _isRolling = true;
      _message = null;
    });

    // Animate rolling
    Future.delayed(const Duration(milliseconds: 300), () {
      final newValues = List<int>.from(_game.diceValues);
      
      // Roll only available dice
      for (final index in _game.availableDice) {
        newValues[index] = _random.nextInt(6) + 1;
      }

      // Get values of rolled dice
      final rolledValues = _game.availableDice.map((i) => newValues[i]).toList();
      
      // Check if this is a farkle (no scoring dice)
      final isFarkle = !FarkleScoring.hasScoring(rolledValues);

      setState(() {
        _game = _game.copyWith(
          diceValues: newValues,
          rollsThisTurn: _game.rollsThisTurn + 1,
          isFarkle: isFarkle,
        );
        _isRolling = false;

        if (isFarkle) {
          _message = '💥 FARKLE! You lose ${_game.turnScore} points!';
          Future.delayed(const Duration(seconds: 2), _endTurn);
        } else {
          _message = 'Select scoring dice to bank';
        }
      });
    });
  }

  void _toggleDiceSelection(int index) {
    if (!_game.availableDice.contains(index)) {
      return; // Can't select banked dice
    }

    if (_game.isFarkle) {
      return; // Can't select after farkle
    }

    setState(() {
      final newSelection = List<int>.from(_game.selectedDice);
      
      if (newSelection.contains(index)) {
        newSelection.remove(index);
      } else {
        newSelection.add(index);
      }

      _game = _game.copyWith(selectedDice: newSelection);
      _message = null;
    });
  }

  void _bankSelection() {
    if (_game.selectedDice.isEmpty) {
      setState(() => _message = 'Select dice to bank first');
      return;
    }

    // Get values of selected dice
    final selectedValues = _game.selectedDice.map((i) => _game.diceValues[i]).toList();
    
    // Check if selection is valid
    if (!FarkleScoring.isValidSelection(selectedValues)) {
      setState(() => _message = 'Selected dice have no scoring value');
      return;
    }

    // Calculate score
    final score = FarkleScoring.calculateScore(selectedValues);
    
    // Remove banked dice from available
    final newAvailable = List<int>.from(_game.availableDice);
    for (final index in _game.selectedDice) {
      newAvailable.remove(index);
    }

    // Check for "hot dice" - if all dice scored, get them back
    final allDiceScored = newAvailable.isEmpty;

    setState(() {
      _game = _game.copyWith(
        turnScore: _game.turnScore + score,
        availableDice: allDiceScored ? [0, 1, 2, 3, 4, 5] : newAvailable,
        selectedDice: [],
      );
      
      if (allDiceScored) {
        _message = '🔥 HOT DICE! All dice back - keep rolling!';
      } else {
        _message = '+$score points banked';
      }
    });
  }

  void _endTurn() {
    if (_game.isFarkle) {
      // Farkle - lose turn score
      setState(() {
        _game = _game.copyWith(
          turnScore: 0,
          availableDice: [0, 1, 2, 3, 4, 5],
          selectedDice: [],
          rollsThisTurn: 0,
          isFarkle: false,
        );
        _message = 'Turn ended. Roll to start new turn.';
      });
    } else {
      // Bank the turn score
      final newTotal = _game.totalScore + _game.turnScore;
      
      setState(() {
        _game = _game.copyWith(
          totalScore: newTotal,
          turnScore: 0,
          availableDice: [0, 1, 2, 3, 4, 5],
          selectedDice: [],
          rollsThisTurn: 0,
        );
        _message = 'Score banked! Total: $newTotal';
      });

      // Check if won
      if (newTotal >= 10000) {
        _handleGameWon();
      }
    }
  }

  void _handleGameWon() async {
    setState(() {
      _gameOver = true;
      _message = '🎉 YOU WIN! Final Score: ${_game.totalScore}';
    });

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Guest user - prompt to login to save score
      if (mounted) {
        await _showGuestScoreDialog();
      }
    } else {
      // Logged in user - submit score directly
      await _submitScoreAndShowDialog(user);
    }
  }

  Future<void> _showGuestScoreDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Great Game!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Final Score: ${_game.totalScore}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: DarkAcademiaColors.antiqueBrass,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Login or create an account to save your score to the leaderboard!',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const FarkleLeaderboardScreen(),
                ),
              );
            },
            child: const Text('View Leaderboard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetGame();
            },
            child: const Text('Play Again'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Navigate to login with score to save
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LoginScreen(
                    pendingFarkleScore: _game.totalScore,
                  ),
                ),
              );
              
              // If user logged/signed up successfully, submit score
              if (result == true && mounted) {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await _submitScoreAndShowDialog(user);
                }
              }
            },
            child: const Text('Login / Sign Up'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitScoreAndShowDialog(User user) async {
    try {
      final username = await UserService.getCurrentUsername() ?? 'Anonymous';
      await FarkleService.submitScore(
        userId: user.uid,
        username: username,
        score: _game.totalScore,
      );

      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🎉 Victory!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Final Score: ${_game.totalScore}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                const Text('Your score has been submitted to the leaderboard!'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const FarkleLeaderboardScreen(),
                    ),
                  );
                },
                child: const Text('View Leaderboard'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetGame();
                },
                child: const Text('Play Again'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting score: $e')),
        );
      }
    }
  }

  void _resetGame() {
    setState(() {
      _game = FarkleGame(
        gameId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      _message = null;
      _gameOver = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farkle'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FarkleLeaderboardScreen(),
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
            // Score display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: DarkAcademiaColors.navyBlue,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _scoreCard('Total Score', _game.totalScore),
                      _scoreCard('Turn Score', _game.turnScore),
                    ],
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _game.isFarkle 
                            ? Colors.red.withValues(alpha: 0.3)
                            : DarkAcademiaColors.richCognac.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _message!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Dice display
            Expanded(
              child: Center(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: List.generate(6, (index) {
                    final isAvailable = _game.availableDice.contains(index);
                    final isSelected = _game.selectedDice.contains(index);
                    
                    return GestureDetector(
                      onTap: () => _toggleDiceSelection(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? DarkAcademiaColors.richCognac
                              : isAvailable
                                  ? DarkAcademiaColors.charcoalGray
                                  : DarkAcademiaColors.navyBlue,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? DarkAcademiaColors.antiqueBrass
                                : DarkAcademiaColors.cream.withValues(alpha: 0.3),
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            isAvailable ? '${_game.diceValues[index]}' : '✓',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: isAvailable
                                  ? DarkAcademiaColors.cream
                                  : DarkAcademiaColors.cream.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            
            // Control buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: (_isRolling || _gameOver || _game.selectedDice.isNotEmpty) 
                        ? null 
                        : _rollDice,
                    icon: const Icon(Icons.casino),
                    label: Text(_game.rollsThisTurn == 0 ? 'Start Turn' : 'Roll Dice'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_gameOver || _game.selectedDice.isEmpty) 
                              ? null 
                              : _bankSelection,
                          icon: const Icon(Icons.savings),
                          label: const Text('Bank'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_gameOver || _game.turnScore == 0 || _game.isFarkle) 
                              ? null 
                              : _endTurn,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('End Turn'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreCard(String label, int value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: DarkAcademiaColors.cream.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: DarkAcademiaColors.antiqueBrass,
          ),
        ),
      ],
    );
  }
}
