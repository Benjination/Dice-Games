import 'package:flutter/material.dart';
import '../../theme/dark_academia_theme.dart';
import '../../services/user_service.dart';
import '../../services/friends_service.dart';
import './auth/login_screen.dart';
import './games/dice_pool_config_screen.dart';
import './games/my_games_screen.dart';
import './games/browse_public_games_screen.dart';
import './games/farkle/farkle_mode_screen.dart';
import './games/pig/pig_mode_screen.dart';
import './games/dice_poker/dice_poker_mode_screen.dart';
import './games/squares/squares_play_screen.dart';
import '../models/squares_game.dart';

import './moderator/moderator_screen.dart';
import './settings/settings_screen.dart';
import './social/friends_screen.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roll Tavern'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: FilledButton.tonal(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                child: const Text('Sign In'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Hero section
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      DarkAcademiaColors.navyBlue,
                      DarkAcademiaColors.deepForestGreen,
                    ],
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 40 : 80,
                  horizontal: 20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Roll with Purpose',
                          style: Theme.of(context).textTheme.displayLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Classic dice games reimagined. Play now as a guest, or sign in to save your favorites and create custom games.',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const GameListScreen(guest: true),
                                  ),
                                );
                              },
                              child: const Text('Play as Guest'),
                            ),
                            const SizedBox(width: 16),
                            FilledButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: const Text('Create Account'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Games preview section
              Padding(
                padding: EdgeInsets.all(isMobile ? 20 : 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Featured Games',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 24),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: isMobile ? 1 : 2,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          children: [
                            _gameCard(
                              context: context,
                              title: 'Farkle',
                              description:
                                  'Push your luck and accumulate points. But watch out—roll a 1 and lose your turn\'s score!',
                              icon: Icons.trending_up,
                            ),
                            _gameCard(
                              context: context,
                              title: 'Pig Dice',
                              description:
                                  'A simpler push-your-luck classic. Roll the die, keep rolling or bank your points.',
                              icon: Icons.casino,
                            ),
                            _gameCard(
                              context: context,
                              title: 'Dice Poker',
                              description:
                                  'Roll five dice and aim for poker hands: pairs, three of a kind, straights, and more.',
                              icon: Icons.grid_3x3,
                            ),
                            _gameCard(
                              context: context,
                              title: 'Custom Games',
                              description:
                                  'Sign in to design and save your own unique dice games with custom rules.',
                              icon: Icons.edit,
                              soon: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Call to action
              Container(
                width: double.infinity,
                color: DarkAcademiaColors.charcoalGray,
                padding: EdgeInsets.all(isMobile ? 30 : 60),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      children: [
                        Text(
                          'Ready to play?',
                          style: Theme.of(context).textTheme.displayMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const GameListScreen(guest: true),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 32,
                            ),
                            child: Text('Start Playing Now'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    bool soon = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: DarkAcademiaColors.richCognac,
                ),
                if (soon)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: DarkAcademiaColors.richCognac,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Coming Soon',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: DarkAcademiaColors.darkText,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class GameListScreen extends StatefulWidget {
  const GameListScreen({super.key, required this.guest});

  final bool guest;

  @override
  State<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends State<GameListScreen> {
  bool _isModerator = false;
  bool _isCheckingModerator = true;
  int _pendingRequestCount = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.guest) {
      _checkModeratorStatus();
      _loadPendingCount();
    } else {
      _isCheckingModerator = false;
    }
  }

  Future<void> _checkModeratorStatus() async {
    try {
      final isMod = await UserService.isUserModerator();
      if (mounted) {
        setState(() {
          _isModerator = isMod;
          _isCheckingModerator = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isModerator = false;
          _isCheckingModerator = false;
        });
      }
    }
  }

  Future<void> _loadPendingCount() async {
    try {
      final count = await FriendsService.getPendingRequestCount();
      if (mounted) {
        setState(() {
          _pendingRequestCount = count;
        });
      }
    } catch (e) {
      // If error loading count, just default to 0
      if (mounted) {
        setState(() {
          _pendingRequestCount = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.guest ? 'Games' : 'Game Library'),
        actions: [
          // Community Games icon - available to all users
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BrowsePublicGamesScreen(),
                ),
              );
            },
            icon: const Icon(Icons.public),
            tooltip: 'Community Games',
          ),
          if (!widget.guest) ...[
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MyGamesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.bookmark),
              tooltip: 'My Games',
            ),
            IconButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FriendsScreen(),
                  ),
                );
                // Reload count when returning from Friends screen
                _loadPendingCount();
              },
              icon: Badge(
                isLabelVisible: _pendingRequestCount > 0,
                label: Text('$_pendingRequestCount'),
                child: const Icon(Icons.people),
              ),
              tooltip: 'Friends',
            ),
            if (_isModerator && !_isCheckingModerator)
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ModeratorScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.admin_panel_settings),
                tooltip: 'Approve Games',
              ),
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!widget.guest) ...[
              Card(
                color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.1),
                child: ListTile(
                  leading: const Icon(
                    Icons.bookmark,
                    color: DarkAcademiaColors.antiqueBrass,
                  ),
                  title: const Text(
                    'My Saved Games',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: DarkAcademiaColors.antiqueBrass,
                    ),
                  ),
                  subtitle: const Text('View and play your saved games'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MyGamesScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Community Games - available to all users (logged in or guest)
            Card(
              color: DarkAcademiaColors.deepForestGreen.withValues(alpha: 0.15),
              child: ListTile(
                leading: const Icon(
                  Icons.public,
                  color: DarkAcademiaColors.antiqueBrass,
                ),
                title: const Text(
                  'Community Games',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: DarkAcademiaColors.antiqueBrass,
                  ),
                ),
                subtitle: Text(widget.guest 
                    ? 'Browse public games from other players'
                    : 'Browse and save public games from other players'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BrowsePublicGamesScreen(),
                    ),
                  );
                },
              ),
            ),
            if (!widget.guest) ...[
              if (_isModerator && !_isCheckingModerator) ...[
                const SizedBox(height: 12),
                Card(
                  color: DarkAcademiaColors.richCognac.withValues(alpha: 0.15),
                  child: ListTile(
                    leading: const Icon(
                      Icons.admin_panel_settings,
                      color: DarkAcademiaColors.antiqueBrass,
                    ),
                    title: const Text(
                      'Approve Games',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: DarkAcademiaColors.antiqueBrass,
                      ),
                    ),
                    subtitle: const Text('Review and approve pending public games'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ModeratorScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Available Games',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
            ],
            _GameEntry(
              title: 'Dice Roulette',
              subtitle: 'Roll any set of labelled dice — d4 through d20 — '
                  'individually or all at once. Toggle Mean Dice to bias '
                  'rolls toward higher values.',
              icon: Icons.casino,
              onPlay: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DicePoolConfigScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _GameEntry(
              title: 'Farkle',
              subtitle: 'Push your luck and accumulate points. Roll a 1 and '
                  'lose your turn\'s score!',
              icon: Icons.trending_up,
              onPlay: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FarkleModeScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _GameEntry(
              title: 'Pig Dice',
              subtitle: 'A simpler push-your-luck classic. Roll, keep rolling, '
                  'or bank your points.',
              icon: Icons.pets,
              onPlay: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PigModeScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _GameEntry(
              title: 'Dice Poker',
              subtitle: 'Roll five dice and aim for poker hands: pairs, '
                  'three of a kind, straights, and more.',
              icon: Icons.grid_3x3,
              onPlay: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DicePokerModeScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _GameEntry(
              title: 'Squares',
              subtitle: 'Create custom grid games with dice rolls. '
                  'Perfect for workouts, date nights, or any activity!',
              icon: Icons.grid_on,
              onPlay: () {
                // Create a new blank Squares game
                final newGame = SquaresGame(
                  gameId: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: 'New Squares Game',
                  description: 'Custom grid game',
                  category: 'Custom',
                  xDieSides: 6,
                  yDieSides: 6,
                  zDieSides: null, // 2D mode by default
                  creatorUid: '',
                  creatorUsername: '',
                  createdAt: DateTime.now(),
                );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SquaresPlayScreen(game: newGame),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GameEntry extends StatelessWidget {
  const _GameEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onPlay,
    this.comingSoon = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onPlay;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: DarkAcademiaColors.navyBlue,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.4),
                ),
              ),
              child: Icon(
                icon,
                color: DarkAcademiaColors.antiqueBrass,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Text + action
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (comingSoon) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: DarkAcademiaColors.richCognac
                                .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: DarkAcademiaColors.richCognac
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Text(
                            'Soon',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: DarkAcademiaColors.richCognac,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (!comingSoon && onPlay != null) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: onPlay,
                      child: const Text('Play'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
