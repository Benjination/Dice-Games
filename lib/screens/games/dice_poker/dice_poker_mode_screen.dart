import 'package:flutter/material.dart';

import '../../../theme/dark_academia_theme.dart';
import './dice_poker_single_player_screen.dart';
import './dice_poker_leaderboard_screen.dart';

/// Dice Poker mode selection screen
class DicePokerModeScreen extends StatelessWidget {
  const DicePokerModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dice Poker'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Game description
                Card(
                  color: DarkAcademiaColors.navyBlue.withValues(alpha: 0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.casino,
                          size: 64,
                          color: DarkAcademiaColors.antiqueBrass,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Dice Poker',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: DarkAcademiaColors.cream,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Roll 5 dice to make poker hands! You get 3 rolls per round. Lock the dice you want to keep and re-roll the rest. Play 5 rounds and accumulate the highest score!',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: DarkAcademiaColors.cream.withValues(alpha: 0.9),
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: DarkAcademiaColors.deepForestGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hand Rankings:',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: DarkAcademiaColors.antiqueBrass,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              _buildHandRanking('Five of a Kind', '1,000 pts'),
                              _buildHandRanking('Four of a Kind', '500 pts'),
                              _buildHandRanking('Full House', '300 pts'),
                              _buildHandRanking('Straight', '250 pts'),
                              _buildHandRanking('Three of a Kind', '200 pts'),
                              _buildHandRanking('Two Pair', '150 pts'),
                              _buildHandRanking('One Pair', '100 pts'),
                              _buildHandRanking('High Card', '50 pts'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Single Player button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DicePokerSinglePlayerScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person),
                  label: const Text('Single Player'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: DarkAcademiaColors.deepForestGreen,
                  ),
                ),
                const SizedBox(height: 16),

                // Multiplayer button (disabled for now)
                ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.group),
                  label: const Text('Invite Friends (Coming Soon)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 32),

                // View Leaderboard button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DicePokerLeaderboardScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.leaderboard),
                  label: const Text('View Leaderboard'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: DarkAcademiaColors.antiqueBrass),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandRanking(String handName, String points) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            handName,
            style: const TextStyle(
              color: DarkAcademiaColors.cream,
              fontSize: 13,
            ),
          ),
          Text(
            points,
            style: const TextStyle(
              color: DarkAcademiaColors.antiqueBrass,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
