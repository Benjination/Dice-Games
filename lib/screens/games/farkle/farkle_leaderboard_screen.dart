import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/farkle_game.dart';
import '../../../services/farkle_service.dart';
import '../../../theme/dark_academia_theme.dart';

/// Screen displaying Farkle leaderboard with top 15 scores
class FarkleLeaderboardScreen extends StatefulWidget {
  const FarkleLeaderboardScreen({super.key});

  @override
  State<FarkleLeaderboardScreen> createState() => _FarkleLeaderboardScreenState();
}

class _FarkleLeaderboardScreenState extends State<FarkleLeaderboardScreen> {
  List<FarkleScore>? _scores;
  bool _isLoading = true;
  String? _error;
  FarkleScore? _userBest;
  int? _userRank;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final scores = await FarkleService.getTopScores(limit: 15);
      
      // Load user's personal best if logged in
      final user = FirebaseAuth.instance.currentUser;
      FarkleScore? userBest;
      int? userRank;
      
      if (user != null) {
        userBest = await FarkleService.getUserBestScore(user.uid);
        if (userBest != null) {
          userRank = await FarkleService.getUserRank(user.uid);
        }
      }

      if (mounted) {
        setState(() {
          _scores = scores;
          _userBest = userBest;
          _userRank = userRank;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farkle Leaderboard'),
        actions: [
          IconButton(
            onPressed: _loadLeaderboard,
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
                      ),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadLeaderboard,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildLeaderboard(),
    );
  }

  Widget _buildLeaderboard() {
    if (_scores == null || _scores!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: DarkAcademiaColors.cream.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No scores yet',
              style: TextStyle(
                color: DarkAcademiaColors.cream.withValues(alpha: 0.6),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Be the first to set a high score!',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      );
    }

    final user = FirebaseAuth.instance.currentUser;

    return Column(
      children: [
        // User's personal best (if they have one and are logged in)
        if (_userBest != null && user != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: DarkAcademiaColors.navyBlue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Best Score',
                  style: TextStyle(
                    color: DarkAcademiaColors.cream.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _userBest!.score.toString(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: DarkAcademiaColors.antiqueBrass,
                      ),
                    ),
                    if (_userRank != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: DarkAcademiaColors.richCognac,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Rank #$_userRank',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: DarkAcademiaColors.darkText,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        
        // Top 15 leaderboard
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _scores!.length,
            itemBuilder: (context, index) {
              final score = _scores![index];
              final isCurrentUser = user != null && score.userId == user.uid;
              final rank = index + 1;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isCurrentUser
                    ? DarkAcademiaColors.richCognac.withValues(alpha: 0.2)
                    : null,
                child: ListTile(
                  leading: _buildRankBadge(rank),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          score.username,
                          style: TextStyle(
                            fontWeight: isCurrentUser 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isCurrentUser)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: DarkAcademiaColors.antiqueBrass,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: DarkAcademiaColors.darkText,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: Text(
                    score.score.toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: DarkAcademiaColors.antiqueBrass,
                    ),
                  ),
                  subtitle: Text(
                    _formatDate(score.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: DarkAcademiaColors.cream.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRankBadge(int rank) {
    Color? badgeColor;
    IconData? icon;
    
    if (rank == 1) {
      badgeColor = const Color(0xFFFFD700); // Gold
      icon = Icons.emoji_events;
    } else if (rank == 2) {
      badgeColor = const Color(0xFFC0C0C0); // Silver
      icon = Icons.emoji_events;
    } else if (rank == 3) {
      badgeColor = const Color(0xFFCD7F32); // Bronze
      icon = Icons.emoji_events;
    }

    if (icon != null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: badgeColor!.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: badgeColor,
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: DarkAcademiaColors.charcoalGray,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '#$rank',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
