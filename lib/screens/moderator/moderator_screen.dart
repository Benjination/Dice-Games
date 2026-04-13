import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/saved_game.dart';
import '../../services/game_service.dart';
import '../../services/user_service.dart';
import '../../theme/dark_academia_theme.dart';
import '../games/dice_pool_screen.dart';

/// Moderator screen for reviewing and approving pending public games
class ModeratorScreen extends StatefulWidget {
  const ModeratorScreen({super.key});

  @override
  State<ModeratorScreen> createState() => _ModeratorScreenState();
}

class _ModeratorScreenState extends State<ModeratorScreen> {
  List<SavedGame>? _pendingGames;
  bool _isLoading = true;
  String? _error;
  bool _isModerator = false;

  @override
  void initState() {
    super.initState();
    _checkModeratorStatus();
  }

  Future<void> _checkModeratorStatus() async {
    final isMod = await UserService.isUserModerator();
    if (!mounted) return;

    if (!isMod) {
      // Not a moderator, show error
      setState(() {
        _isModerator = false;
        _isLoading = false;
        _error = 'You do not have moderator privileges';
      });
      return;
    }

    setState(() {
      _isModerator = true;
    });
    _loadPendingGames();
  }

  Future<void> _loadPendingGames() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final games = await GameService.loadPendingGames();
      if (mounted) {
        setState(() {
          _pendingGames = games;
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

  Future<void> _approveGame(SavedGame game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Game'),
        content: Text('Approve "${game.name}" and make it public?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true && game.id != null) {
      try {
        await GameService.approveGame(game.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Game "${game.name}" approved!')),
          );
          _loadPendingGames();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error approving game: $e')),
          );
        }
      }
    }
  }

  Future<void> _rejectGame(SavedGame game) async {
    final reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Game'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject "${game.name}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Why is this game being rejected?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
          ],
        ),
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
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && game.id != null) {
      try {
        await GameService.rejectGame(
          game.id!,
          reason: reasonController.text.trim().isEmpty
              ? null
              : reasonController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Game "${game.name}" rejected')),
          );
          _loadPendingGames();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error rejecting game: $e')),
          );
        }
      }
    }
  }

  Future<void> _previewGame(SavedGame game) async {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approve Games'),
        actions: [
          if (_isModerator)
            IconButton(
              onPressed: _loadPendingGames,
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
                        _isModerator ? Icons.error_outline : Icons.lock,
                        size: 64,
                        color: DarkAcademiaColors.cream.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: DarkAcademiaColors.cream.withValues(alpha: 0.8),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_isModerator) ...[
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadPendingGames,
                          child: const Text('Retry'),
                        ),
                      ],
                    ],
                  ),
                )
              : _pendingGames == null || _pendingGames!.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: DarkAcademiaColors.cream.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No pending games to review',
                            style: TextStyle(
                              color: DarkAcademiaColors.cream.withValues(alpha: 0.6),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'All submissions have been reviewed!',
                            style: TextStyle(
                              color: DarkAcademiaColors.cream.withValues(alpha: 0.4),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pendingGames!.length,
                      itemBuilder: (context, index) {
                        final game = _pendingGames![index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header with game info
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: DarkAcademiaColors.antiqueBrass,
                                      child: Text(
                                        game.dice.length.toString(),
                                        style: const TextStyle(
                                          color: DarkAcademiaColors.navyBlue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            game.name,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${game.dice.length} dice • Submitted ${_formatDate(game.createdAt)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: DarkAcademiaColors.cream
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                // General rules
                                if (game.generalRules?.isNotEmpty ?? false) ...[
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Text(
                                    'General Rules:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: DarkAcademiaColors.antiqueBrass,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    game.generalRules!,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                                // Dice configurations
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                                Text(
                                  'Dice Configuration:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: DarkAcademiaColors.antiqueBrass,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: game.dice.map((die) {
                                    return Chip(
                                      label: Text(
                                        '${die.label} (d${die.sides})',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      backgroundColor: DarkAcademiaColors
                                          .navyBlue
                                          .withValues(alpha: 0.3),
                                    );
                                  }).toList(),
                                ),
                                // Action buttons
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _previewGame(game),
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Preview'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => _rejectGame(game),
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('Reject'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: () => _approveGame(game),
                                      icon: const Icon(Icons.check, size: 18),
                                      label: const Text('Approve'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
