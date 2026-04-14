import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/saved_game.dart';
import '../../models/squares_game.dart';
import '../../services/game_service.dart';
import '../../services/squares_service.dart';
import '../../services/user_service.dart';
import '../../theme/dark_academia_theme.dart';
import 'dice_pool_screen.dart';
import 'squares/squares_play_screen.dart';

/// Screen for browsing and saving public games from the community
class BrowsePublicGamesScreen extends StatefulWidget {
  const BrowsePublicGamesScreen({super.key});

  @override
  State<BrowsePublicGamesScreen> createState() => _BrowsePublicGamesScreenState();
}

class _BrowsePublicGamesScreenState extends State<BrowsePublicGamesScreen> {
  List<SavedGame>? _diceGames;
  List<SquaresGame>? _squaresGames;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPublicGames();
  }

  Future<void> _loadPublicGames() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final diceGames = await GameService.loadPublicGames();
      final squaresGames = await SquaresService.getPublicGames().first;
      if (mounted) {
        setState(() {
          _diceGames = diceGames;
          _squaresGames = squaresGames;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveGameToLibrary(SavedGame game) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save games')),
        );
      }
      return;
    }

    try {
      await GameService.copyPublicGameToLibrary(game);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Game "${game.name}" saved to your library!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving game: $e')),
        );
      }
    }
  }DiceGame(SavedGame game) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DicePoolScreen(
          configs: game.dice,
          gameName: game.name,
          generalRules: game.generalRules,
        ),
      ),
    );
  }

  Future<void> _previewSquaresGame(SquaresGame game) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SquaresPlayScreen(game: game  gameName: game.name,
          generalRules: game.generalRules,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Games'),
        actions: [
          IconButton(
            onPressed: _loadPublicGames,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: DarkAcademiaColors.cream.withValues(alpha: 0.4),
                (_diceGames == null && _squaresGames == null) ||
                (_diceGames!.isEmpty && _squaresGames!.isEmpty)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.public_off,
                            size: 64,
                            color: DarkAcademiaColors.cream.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No public games available yet',
                            style: TextStyle(
                              color: DarkAcademiaColors.cream.withValues(alpha: 0.6),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: (_diceGames?.length ?? 0) + (_squaresGames?.length ?? 0),
                      itemBuilder: (context, index) {
                        // Show Dice Pool games first, then Squares games
                        if (index < (_diceGames?.length ?? 0)) {
                          // Dice Pool game
                          final game = _diceGames![index];
                          return _buildDiceGameCard(game);
                        } else {
                          // Squares game
                          final squaresIndex = index - (_diceGames?.length ?? 0);
                          final game = _squaresGames![squaresIndex];
                          return _buildSquaresGameCard(game);
                        }
                      },
                    ),
    );
  }

  Widget _buildDiceGameCard(SavedGame game) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: DarkAcademiaColors.antiqueBrass,
          child: const Icon(Icons.casino, color: DarkAcademiaColors.navyBlue),
        ),
        title: Text(
          game.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String>(
              future: game.creatorUid != null
                  ? UserService.getUsernameByUid(game.creatorUid!)
                  : Future.value('Unknown'),
              builder: (context, snapshot) {
                final creatorName = snapshot.data ?? 'Loading...';
                return Text(
                  'Dice Roulette • By $creatorName • ${game.dice.length} dice',
                  style: TextStyle(
                    color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                );
              },
            ),
            if (game.generalRules?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  game.generalRules!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: DarkAcademiaColors.cream.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Preview',
              onPressed: () => _previewDiceGame(game),
            ),
            IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: 'Save to Library',
              onPressed: () => _saveGameToLibrary(game),
            ),
          ],
        ),
        onTap: () => _previewDiceGame(game),
      ),
    );
  }

  Widget _buildSquaresGameCard(SquaresGame game) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: DarkAcademiaColors.cream,
          child: const Icon(Icons.grid_4x4, color: DarkAcademiaColors.navyBlue),
        ),
        title: Text(
          game.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String>(
              future: UserService.getUsernameByUid(game.creatorUid),
              builder: (context, snapshot) {
                final creatorName = snapshot.data ?? 'Loading...';
                return Text(
                  'Squares • By $creatorName • ${game.is3DMode ? "3D " : ""}${game.xDieSides}×${game.yDieSides}${game.is3DMode ? "×${game.zDieSides}" : ""}',
                  style: TextStyle(
                    color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                );
              },
            ),
            if (game.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  game.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: DarkAcademiaColors.cream.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.play_arrow),
          tooltip: 'Play',
          onPressed: () => _previewSquaresGame(game),
        ),
        onTap: () => _previewSquaresGame(game),
      ),
    );
  }                            icon: const Icon(Icons.save_alt),
                                  tooltip: 'Save to Library',
                                  onPressed: () => _saveGameToLibrary(game),
                                ),
                              ],
                            ),
                            onTap: () => _previewGame(game),
                          ),
                        );
                      },
                    ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 7) {
      return '${date.month}/${date.day}/${date.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}
