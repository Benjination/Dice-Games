import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/saved_game.dart';
import '../../services/game_service.dart';
import '../../theme/dark_academia_theme.dart';
import 'dice_pool_screen.dart';

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
  List<SavedGame>? _games;
  bool _isLoading = true;
  String? _error;
  GameFilter _currentFilter = GameFilter.public;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final games = await GameService.loadUserGames();
      if (mounted) {
        setState(() {
          _games = games;
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

  /// Filters games based on the current filter selection
  List<SavedGame> get _filteredGames {
    if (_games == null) return [];
    
    switch (_currentFilter) {
      case GameFilter.all:
        return _games!;
      case GameFilter.public:
        return _games!.where((game) => game.isPublic).toList();
      case GameFilter.private:
        return _games!.where((game) => !game.isPublic).toList();
    }
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
          _loadGames();
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
        actions: [
          IconButton(
            onPressed: _loadGames,
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
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadGames,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
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
                    // Games list
                    Expanded(
                      child: _filteredGames.isEmpty
                          ? Center(
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
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredGames.length,
                              itemBuilder: (context, index) {
                                final game = _filteredGames[index];
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
                                  '${game.dice.length} dice • Updated ${_formatDate(game.updatedAt)}',
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
                                if (value == 'delete') {
                                  _deleteGame(game);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                            onTap: () => _playGame(game),
                          ),
                        );
                      },
                    ),
                    ),
                  ],
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
