import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/pig_game.dart';
import '../../../services/pig_service.dart';
import '../../../services/user_service.dart';
import '../../../theme/dark_academia_theme.dart';
import '../../auth/login_screen.dart';
import './pig_leaderboard_screen.dart';

/// Single-player Pig Dice game screen
class PigSinglePlayerScreen extends StatefulWidget {
  const PigSinglePlayerScreen({super.key});

  @override
  State<PigSinglePlayerScreen> createState() => _PigSinglePlayerScreenState();
}

class _PigSinglePlayerScreenState extends State<PigSinglePlayerScreen> {
  late PigGame _game;
  final _random = Random();
  bool _isRolling = false;
  String? _message;
  bool _gameOver = false;
  
  // Animation state
  Timer? _animationTimer;
  bool _isAnimating = false;
  int _finalDiceValue = 0;

  @override
  void initState() {
    super.initState();
    _game = PigGame(
      gameId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  void _rollDice() {
    if (_gameOver || _game.isPigOut) {
      return;
    }

    setState(() {
      _isRolling = true;
      _message = null;
    });

    // Cancel any existing animation
    _animationTimer?.cancel();
    
    // Generate final value
    _finalDiceValue = _random.nextInt(6) + 1;
    _isAnimating = true;

    // Start rapid cycling animation (50ms updates)
    _animationTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          _game = _game.copyWith(diceValue: _random.nextInt(6) + 1);
        });
      },
    );

    // Lock on final value after 1 second
    Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      
      _animationTimer?.cancel();
      _isAnimating = false;

      setState(() {
        _game = _game.copyWith(
          diceValue: _finalDiceValue,
          hasRolled: true,
        );
        _isRolling = false;
      });

      // Check if pigged out (rolled a 1)
      if (_finalDiceValue == 1) {
        setState(() {
          _game = _game.copyWith(isPigOut: true);
          _message = '🐷 PIG OUT! You rolled a 1. Turn over!';
        });
      } else {
        // Add to turn score
        final newTurnScore = _game.turnScore + _finalDiceValue;
        setState(() {
          _game = _game.copyWith(turnScore: newTurnScore);
          _message = 'Rolled a $_finalDiceValue! Roll again or Hold?';
        });
      }
    });
  }

  void _hold() {
    if (!_game.hasRolled || _game.isPigOut || _gameOver) {
      return;
    }

    // Bank the turn score
    final newTotal = _game.totalScore + _game.turnScore;
    final nextTurn = _game.currentTurn + 1;

    setState(() {
      _game = _game.copyWith(
        totalScore: newTotal,
        turnScore: 0,
        currentTurn: nextTurn,
        hasRolled: false,
        isPigOut: false,
      );
      _message = 'Score banked! Total: $newTotal';
    });

    // Check if won
    if (newTotal >= PigGame.winningScore) {
      _handleGameWon();
    }
    // Check if max turns reached
    else if (nextTurn > PigGame.maxTurns) {
      _handleGameOver();
    }
  }

  void _nextTurn() {
    if (!_game.isPigOut) {
      return;
    }

    final nextTurn = _game.currentTurn + 1;

    setState(() {
      _game = _game.copyWith(
        turnScore: 0,
        currentTurn: nextTurn,
        hasRolled: false,
        isPigOut: false,
      );
      _message = 'New turn. Roll the die!';
    });

    // Check if max turns reached
    if (nextTurn > PigGame.maxTurns) {
      _handleGameOver();
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
        await _showGuestScoreDialog(isWin: true);
      }
    } else {
      // Logged in user - submit score directly
      await _submitScoreAndShowDialog(user, isWin: true);
    }
  }

  void _handleGameOver() async {
    setState(() {
      _gameOver = true;
      _message = 'Game Over! Turn limit reached.\\nFinal Score: ${_game.totalScore}';
    });

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Guest user - prompt to login to save score
      if (mounted) {
        await _showGuestScoreDialog(isWin: false);
      }
    } else {
      // Logged in user - submit score directly
      await _submitScoreAndShowDialog(user, isWin: false);
    }
  }

  Future<void> _showGuestScoreDialog({required bool isWin}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isWin ? '🎉 Great Game!' : '⏱️ Game Over'),
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
              Navigator.of(context).pop(); // Go back to mode selection
            },
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Navigate to login with score to save
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LoginScreen(
                    pendingPigScore: _game.totalScore,
                  ),
                ),
              );
              
              // If user logged/signed up successfully, submit score
              if (result == true && mounted) {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final isWin = _game.totalScore >= PigGame.winningScore;
                  await _submitScoreAndShowDialog(user, isWin: isWin);
                }
              }
            },
            child: const Text('Login / Sign Up'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitScoreAndShowDialog(User user, {required bool isWin}) async {
    try {
      final username = await UserService.getCurrentUsername() ?? 'Anonymous';
      
      await PigService.submitScore(
        userId: user.uid,
        username: username,
        score: _game.totalScore,
      );

      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(isWin ? '🎉 Victory!' : 'Game Over'),
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
                const Text('Score saved to leaderboard!'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back to mode selection
                },
                child: const Text('Done'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const PigLeaderboardScreen(),
                    ),
                  );
                },
                child: const Text('View Leaderboard'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving score: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pig Dice'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PigLeaderboardScreen(),
                ),
              );
            },
            icon: const Icon(Icons.leaderboard),
            tooltip: 'Leaderboard',
          ),
        ],
      ),
      body: Column(
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
                    _scoreCard('Turn', _game.currentTurn, 
                      subtitle: '/ ${PigGame.maxTurns}'),
                  ],
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _game.isPigOut 
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
              child: Image.asset(
                'assets/images/dice-images/6.${_game.diceValue}.png',
                width: 150,
                height: 150,
                opacity: _isAnimating ? AlwaysStoppedAnimation(0.8) : null,
              ),
            ),
          ),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: _game.isPigOut
                ? SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: FilledButton(
                      onPressed: _gameOver ? null : _nextTurn,
                      style: FilledButton.styleFrom(
                        backgroundColor: DarkAcademiaColors.richCognac,
                      ),
                      child: const Text(
                        'Next Turn',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 60,
                          child: FilledButton(
                            onPressed: (_isRolling || _gameOver) ? null : _rollDice,
                            style: FilledButton.styleFrom(
                              backgroundColor: DarkAcademiaColors.richCognac,
                            ),
                            child: const Text(
                              'Roll',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 60,
                          child: OutlinedButton(
                            onPressed: (!_game.hasRolled || _isRolling || _gameOver) ? null : _hold,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DarkAcademiaColors.antiqueBrass,
                              side: const BorderSide(color: DarkAcademiaColors.antiqueBrass),
                            ),
                            child: const Text(
                              'Hold',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _scoreCard(String label, int value, {String? subtitle}) {
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
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: DarkAcademiaColors.antiqueBrass,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 18,
                    color: DarkAcademiaColors.cream.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
