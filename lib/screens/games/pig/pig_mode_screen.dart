import 'package:flutter/material.dart';

import '../../../theme/dark_academia_theme.dart';
import './pig_single_player_screen.dart';
import './pig_leaderboard_screen.dart';

/// Mode selection screen for Pig Dice game
class PigModeScreen extends StatelessWidget {
  const PigModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pig Dice'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Game description
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: DarkAcademiaColors.navyBlue,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DarkAcademiaColors.antiqueBrass,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '🎲 Pig Dice',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: DarkAcademiaColors.antiqueBrass,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Roll the die and accumulate points!\n\n'
                      '• Roll to add to your turn score\n'
                      '• Hold to bank your points\n'
                      '• Roll a 1 and you PIG OUT!\n'
                      '• First to 100 points wins\n'
                      '• 20 turn limit',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Single Player button
              SizedBox(
                width: 250,
                height: 60,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PigSinglePlayerScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person, size: 28),
                  label: const Text(
                    'Single Player',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: DarkAcademiaColors.richCognac,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Invite Friends button (disabled for now)
              SizedBox(
                width: 250,
                height: 60,
                child: FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.people, size: 28),
                  label: const Text(
                    'Invite Friends',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Leaderboard button
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PigLeaderboardScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.leaderboard),
                label: const Text('View Leaderboard'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DarkAcademiaColors.antiqueBrass,
                  side: const BorderSide(color: DarkAcademiaColors.antiqueBrass),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
