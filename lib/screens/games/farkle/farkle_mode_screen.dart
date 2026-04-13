import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../theme/dark_academia_theme.dart';
import './farkle_single_player_screen.dart';
import './farkle_invite_friends_screen.dart';
import '../../auth/login_screen.dart';

/// Screen for selecting Farkle game mode (Single-Player or Multiplayer)
class FarkleModeScreen extends StatelessWidget {
  const FarkleModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farkle'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Game title and description
                  Icon(
                    Icons.trending_up,
                    size: 80,
                    color: DarkAcademiaColors.richCognac,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Farkle',
                    style: Theme.of(context).textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Push your luck and accumulate points. Roll all 6 dice, bank scoring combinations, and try to reach 10,000 points. But watch out—roll no scoring dice and you FARKLE!',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  // Single Player button
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FarkleSinglePlayerScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person),
                    label: const Text('Single Player'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  if (user == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Login after playing to save your score!',
                        style: TextStyle(
                          fontSize: 12,
                          color: DarkAcademiaColors.cream.withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  // Multiplayer button
                  OutlinedButton.icon(
                    onPressed: () {
                      if (user == null) {
                        _showLoginPrompt(context);
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FarkleInviteFriendsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.people),
                    label: const Text('Invite Friends'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Rules summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Rules',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: DarkAcademiaColors.antiqueBrass,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _ruleItem('Single 1 = 100 points'),
                          _ruleItem('Single 5 = 50 points'),
                          _ruleItem('Three 1s = 1,000 points'),
                          _ruleItem('Three of any other = number × 100'),
                          _ruleItem('Straight (1-2-3-4-5-6) = 1,500 points'),
                          _ruleItem('Three pairs = 1,500 points'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ruleItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            Icons.arrow_right,
            size: 16,
            color: DarkAcademiaColors.cream.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: DarkAcademiaColors.cream.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLoginPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text(
          'You need to be logged in to play Farkle and save your scores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LoginScreen(),
                ),
              );
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}
