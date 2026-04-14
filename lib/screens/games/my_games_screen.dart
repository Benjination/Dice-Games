import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/saved_game.dart';
import '../../models/squares_game.dart';
import '../../services/game_service.dart';
import '../../services/squares_service.dart';
import '../../services/friends_service.dart';
import '../../theme/dark_academia_theme.dart';
import 'dice_pool_config_screen.dart';
import 'dice_pool_screen.dart';
import 'squares/squares_builder_screen.dart';
import 'squares/squares_play_screen.dart';

/// Filter options for game visibility
enum GameFilter {
  all('All Games'),
  public('Public Games'),
  private('Private Games');

  const GameFilter(this.label);
  final String label;
}

/// Screen showing user's saved games
class MyGamesScreen extends StatefulWidget {
  const MyGamesScreen({super.key});

  @override
  State<MyGamesScreen> createState() => _MyGamesScreenState();
}

class _MyGamesScreenState extends State<MyGamesScreen> {
  GameFilter _currentFilter = GameFilter.public;

  Future<void> _deleteSquaresGame(SquaresGame game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Game'),
        content: Text('Are you sure you want to delete "${game.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SquaresService.deleteGame(game.gameId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${game.name}"')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting game: $e')),
          );
        }
      }
    }
  }

  void _playSquaresGame(SquaresGame game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SquaresPlayScreen(game: game),
      ),
    );
  }

  void _editSquaresGame(SquaresGame game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SquaresBuilderScreen(existingGame: game),
      ),
    );
  }


  Future<void> _deleteGame(SavedGame game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Game'),
        content: Text('Are you sure you want to delete "${game.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && game.id != null) {
      try {
        await GameService.deleteGame(game.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Game deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting game: $e')),
          );
        }
      }
    }
  }

  void _playGame(SavedGame game) {
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

  Future<void> _shareGame(SavedGame game) async {
    if (game.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot share unsaved game')),
      );
      return;
    }

    // Only the creator can share a game
    final user = FirebaseAuth.instance.currentUser;
    if (game.creatorUid != user?.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the creator can share this game')),
      );
      return;
    }

    // Get list of friends
    try {
      final friends = await FriendsService.getFriends();
      if (!mounted) return;

      if (friends.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No friends to share with')),
        );
        return;
      }

      // Show friend selection dialog
      String? selectedFriendUid;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Share Game'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                return ListTile(
                  title: Text(friend['username'] ?? 'Unknown'),
                  onTap: () {
                    selectedFriendUid = friend['uid'];
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedFriendUid != null) {
        try {
          await GameService.shareGameWithFriend(game.id!, selectedFriendUid!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Game shared successfully!')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error sharing game: $e')),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading friends: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Games'),
        ),
        body: const Center(
          child: Text('Please log in to view your games'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Games'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGameMenu(context),
        icon: const Icon(Icons.add),
        label: const Text('New Game'),
      ),
      body: Column(
        children: [
          // Filter buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<GameFilter>(
              segments: GameFilter.values
                  .map(
                    (filter) => ButtonSegment<GameFilter>(
                      value: filter,
                      label: Text(filter.label),
                      icon: Icon(
                        filter == GameFilter.all
                            ? Icons.all_inclusive
                            : filter == GameFilter.public
                                ? Icons.public
                                : Icons.lock,
                      ),
                    ),
                  )
                  .toList(),
              selected: {_currentFilter},
              onSelectionChanged: (Set<GameFilter> selected) {
                setState(() {
                  _currentFilter = selected.first;
                });
              },
            ),
          ),
          // Combined games list
          Expanded(
            child: StreamBuilder<List<SavedGame>>(
              stream: GameService.loadUserGames().asStream().map((games) => games),
              builder: (context, dicePoolSnapshot) {
                return StreamBuilder<List<SquaresGame>>(
                  stream: SquaresService.getMyGames(),
                  builder: (context, squaresSnapshot) {
                    // Handle loading state
                    if (dicePoolSnapshot.connectionState == ConnectionState.waiting ||
                        squaresSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Handle errors
                    if (dicePoolSnapshot.hasError || squaresSnapshot.hasError) {
                      return Center(
                        child: Text('Error loading games'),
                      );
                    }

                    final dicePoolGames = dicePoolSnapshot.data ?? [];
                    final squaresGames = squaresSnapshot.data ?? [];

                    // Filter based on current filter
                    final filteredDicePool = dicePoolGames.where((game) {
                      switch (_currentFilter) {
                        case GameFilter.all:
                          return true;
                        case GameFilter.public:
                          return game.isPublic;
                        case GameFilter.private:
                          return !game.isPublic;
                      }
                    }).toList();

                    final filteredSquares = squaresGames.where((game) {
                      switch (_currentFilter) {
                        case GameFilter.all:
                          return true;
                        case GameFilter.public:
                          return game.isPublic;
                        case GameFilter.private:
                          return !game.isPublic;
                      }
                    }).toList();

                    final totalGames = filteredDicePool.length + filteredSquares.length;

                    if (totalGames == 0) {
                      return Center(
                        child: Text(
                          _currentFilter == GameFilter.public
                              ? 'No public games yet'
                              : _currentFilter == GameFilter.private
                                  ? 'No private games yet'
                                  : 'No saved games yet',
                          style: TextStyle(
                            color: DarkAcademiaColors.cream.withValues(alpha: 0.6),
                            fontSize: 16,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: totalGames,
                      itemBuilder: (context, index) {
                        // Show Squares games first, then dice pool games
                        if (index < filteredSquares.length) {
                          return _buildSquaresCard(filteredSquares[index]);
                        } else {
                          return _buildDicePoolCard(filteredDicePool[index - filteredSquares.length]);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquaresCard(SquaresGame game) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: DarkAcademiaColors.navyBlue,
          child: const Icon(
            Icons.grid_on,
            color: DarkAcademiaColors.antiqueBrass,
          ),
        ),
        title: Text(
          game.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Squares ${game.xDieSides}×${game.yDieSides}${game.is3DMode ? '×${game.zDieSides}' : ''} • ${game.category}',
            ),
            if (game.isPublic)
              const Text(
                'Public',
                style: TextStyle(
                  color: DarkAcademiaColors.antiqueBrass,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _editSquaresGame(game);
            } else if (value == 'delete') {
              _deleteSquaresGame(game);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
        onTap: () => _playSquaresGame(game),
      ),
    );
  }

  Widget _buildDicePoolCard(SavedGame game) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: DarkAcademiaColors.antiqueBrass,
          child: Text(
            game.dice.length.toString(),
            style: const TextStyle(
              color: DarkAcademiaColors.navyBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
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
            Text(
              'Dice Pool • ${game.dice.length} dice • Updated ${_formatDate(game.updatedAt)}',
            ),
            if (game.isPublic)
              const Text(
                'Public',
                style: TextStyle(
                  color: DarkAcademiaColors.antiqueBrass,
                  fontSize: 12,
                ),
              ),
            if (game.isShared)
              Text(
                'Shared by friend • Cannot edit/publish',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              _deleteGame(game);
            } else if (value == 'share') {
              _shareGame(game);
            }
          },
          itemBuilder: (context) => [
            if (game.creatorUid == FirebaseAuth.instance.currentUser?.uid)
              const PopupMenuItem(
                value: 'share',
                child: Text('Share with Friend'),
              ),
            if (game.creatorUid == FirebaseAuth.instance.currentUser?.uid)
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
          ],
        ),
        onTap: () => _playGame(game),
      ),
    );
  }

  void _showCreateGameMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.casino, color: DarkAcademiaColors.antiqueBrass),
              title: const Text('Create Dice Pool Game'),
              subtitle: const Text('Traditional dice rolling game'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DicePoolConfigScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_on, color: DarkAcademiaColors.navyBlue),
              title: const Text('Create Squares Game'),
              subtitle: const Text('Grid-based outcome game'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SquaresBuilderScreen(),
                  ),
                );
              },
            ),
          ],
        ),
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
