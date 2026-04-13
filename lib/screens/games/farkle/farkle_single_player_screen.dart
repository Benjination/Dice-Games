import 'dart:math';
import 'dart:async';
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
  
  // Animation state
  Timer? _animationTimer;
  Set<int> _animatingDice = {};
  List<int> _finalDiceValues = List.filled(6, 0);

  @override
  void initState() {
    super.initState();
    _game = FarkleGame(
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
          'Farkle Rules',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scoring:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text('• Single 1 = 100 points'),
              const Text('• Single 5 = 50 points'),
              const Text('• Three 1s = 1,000 points'),
              const Text('• Three 2s = 200 points'),
              const Text('• Three 3s = 300 points'),
              const Text('• Three 4s = 400 points'),
              const Text('• Three 5s = 500 points'),
              const Text('• Three 6s = 600 points'),
              const Text('• Four of a kind = 2× three of a kind'),
              const Text('• Five of a kind = 3× three of a kind'),
              const Text('• Six of a kind = 4× three of a kind'),
              const Text('• Straight (1-2-3-4-5-6) = 1,500 points'),
              const Text('• Three pairs = 1,500 points'),
              const SizedBox(height: 16),
              const Text(
                'Rules:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text('• Roll dice, select scoring dice, then:'),
              const Text('  - Roll again with remaining dice'),
              const Text('  - Bank your score and end turn'),
              const Text('• Hot dice: If all 6 dice score, roll all again!'),
              const Text('• Farkle: No scoring dice = lose turn score'),
              const SizedBox(height: 16),
              const Text(
                'Win:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text('• First to 10,000 points wins'),
              const Text('• Maximum 20 turns'),
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
    if (_game.selectedDice.isNotEmpty) {
      // Must bank or clear selection before rolling
      return;
    }

    setState(() {
      _isRolling = true;
      _message = null;
    });

    // Cancel any existing animation
    _animationTimer?.cancel();
    
    // Prepare final values for dice being rolled
    final newValues = List<int>.from(_game.diceValues);
    final rollingIndices = _game.availableDice.toList();
    
    // Generate final values for each die being rolled
    for (final index in rollingIndices) {
      _finalDiceValues[index] = _random.nextInt(6) + 1;
      newValues[index] = _finalDiceValues[index];
      _animatingDice.add(index);
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
          // Update animating dice with random values for visual effect
          for (final index in _animatingDice) {
            final tempValues = List<int>.from(_game.diceValues);
            tempValues[index] = _random.nextInt(6) + 1;
            _game = _game.copyWith(diceValues: tempValues);
          }
        });
      },
    );

    // Schedule cascade locking of dice (1.0s, 1.2s, 1.4s, etc.)
    for (int i = 0; i < rollingIndices.length; i++) {
      final dieIndex = rollingIndices[i];
      final lockDelay = Duration(milliseconds: 1000 + (i * 200));
      
      Timer(lockDelay, () {
        if (!mounted) return;
        
        setState(() {
          final tempValues = List<int>.from(_game.diceValues);
          tempValues[dieIndex] = _finalDiceValues[dieIndex];
          _game = _game.copyWith(diceValues: tempValues);
          _animatingDice.remove(dieIndex);
          
          // When all dice have locked, check for farkle
          if (_animatingDice.isEmpty) {
            _animationTimer?.cancel();
            _animationTimer = null;
            _isRolling = false;
            
            // Get values of rolled dice
            final rolledValues = rollingIndices.map((i) => _game.diceValues[i]).toList();
            
            // Check if this is a farkle (no scoring dice)
            final isFarkle = !FarkleScoring.hasScoring(rolledValues);
            
            _game = _game.copyWith(
              rollsThisTurn: _game.rollsThisTurn + 1,
              isFarkle: isFarkle,
            );

            if (isFarkle) {
              _message = '💥 FARKLE! You lose ${_game.turnScore} points!';
              Future.delayed(const Duration(seconds: 2), _endTurn);
            } else {
              _message = 'Select scoring dice to bank';
            }
          }
        });
      });
    }
  }

  void _toggleDiceSelection(int index) {
    if (!_game.availableDice.contains(index)) {
      return; // Can't select banked dice
    }

    if (_game.isFarkle) {
      return; // Can't select after farkle
    }

    if (_game.rollsThisTurn == 0) {
      return; // Can't select dice before rolling
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
    final nextTurn = _game.currentTurn + 1;
    
    if (_game.isFarkle) {
      // Farkle - lose turn score
      setState(() {
        _game = _game.copyWith(
          turnScore: 0,
          availableDice: [0, 1, 2, 3, 4, 5],
          selectedDice: [],
          rollsThisTurn: 0,
          currentTurn: nextTurn,
          isFarkle: false,
        );
        _message = 'Turn ended. Roll to start new turn.';
      });
      
      // Check if max turns reached
      if (nextTurn > FarkleGame.maxTurns) {
        _handleGameOver();
      }
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
          currentTurn: nextTurn,
        );
        _message = 'Score banked! Total: $newTotal';
      });

      // Check if won
      if (newTotal >= 10000) {
        _handleGameWon();
      }
      // Check if max turns reached
      else if (nextTurn > FarkleGame.maxTurns) {
        _handleGameOver();
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
      _message = 'Game Over! Turn limit reached.\nFinal Score: ${_game.totalScore}';
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
                  // Determine if it was a win (score >= 10,000)
                  final isWin = _game.totalScore >= 10000;
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
    _animationTimer?.cancel();
    setState(() {
      _game = FarkleGame(
        gameId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      _message = null;
      _gameOver = false;
      _animatingDice.clear();
      _finalDiceValues = List.filled(6, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farkle'),
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
                      _scoreCard('Turn', _game.currentTurn, 
                        subtitle: '/ ${FarkleGame.maxTurns}'),
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
                    final diceValue = _game.diceValues[index];
                    final canSelect = isAvailable && _game.rollsThisTurn > 0 && !_game.isFarkle;
                    
                    return GestureDetector(
                      onTap: canSelect ? () => _toggleDiceSelection(index) : null,
                      child: AnimatedOpacity(
                        opacity: canSelect ? 1.0 : 0.3,
                        duration: const Duration(milliseconds: 200),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? DarkAcademiaColors.richCognac.withValues(alpha: 0.3)
                                : canSelect
                                    ? Colors.transparent
                                    : DarkAcademiaColors.charcoalGray.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? DarkAcademiaColors.antiqueBrass
                                  : canSelect
                                      ? DarkAcademiaColors.cream.withValues(alpha: 0.3)
                                      : DarkAcademiaColors.cream.withValues(alpha: 0.1),
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Image.asset(
                                  'assets/images/dice-images/6.$diceValue.png',
                                  fit: BoxFit.contain,
                                  color: canSelect ? null : Colors.grey,
                                  colorBlendMode: canSelect ? null : BlendMode.saturation,
                                ),
                              ),
                              if (!isAvailable)
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: DarkAcademiaColors.charcoalGray.withValues(alpha: 0.8),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_circle,
                                      size: 32,
                                      color: DarkAcademiaColors.antiqueBrass,
                                    ),
                                  ),
                                ),
                            ],
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
