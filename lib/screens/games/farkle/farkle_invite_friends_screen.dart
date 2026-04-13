import 'package:flutter/material.dart';

import '../../../theme/dark_academia_theme.dart';

/// Screen for inviting friends to multiplayer Farkle game
class FarkleInviteFriendsScreen extends StatelessWidget {
  const FarkleInviteFriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Friends'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 64,
                color: DarkAcademiaColors.cream.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 24),
              Text(
                'Coming Soon!',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Multiplayer Farkle with friends is currently in development.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
