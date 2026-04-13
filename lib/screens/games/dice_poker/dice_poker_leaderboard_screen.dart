import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../models/dice_poker_game.dart';
import '../../../services/dice_poker_service.dart';
import '../../../theme/dark_academia_theme.dart';

/// Dice Poker leaderboard screen
class DicePokerLeaderboardScreen extends StatefulWidget {
  const DicePokerLeaderboardScreen({super.key});

  @override
  State<DicePokerLeaderboardScreen> createState() => _DicePokerLeaderboardScreenState();
}

class _DicePokerLeaderboardScreenState extends State<DicePokerLeaderboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<DicePokerScore> _topScores = [];
  DicePokerScore? _userBestScore;
  int? _userRank;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final topScores = await DicePokerService.getTopScores(limit: 15);

      final user = FirebaseAuth.instance.currentUser;
      DicePokerScore? userBestScore;
      int? userRank;

      if (user != null) {
        userBestScore = await DicePokerService.getUserBestScore(user.uid);
        if (userBestScore != null) {
          userRank = await DicePokerService.getUserRank(user.uid);
        }
      }

      if (!mounted) return;
      setState(() {
        _topScores = topScores;
        _userBestScore = userBestScore;
        _userRank = userRank;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dice Poker Leaderboard'),
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
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: DarkAcademiaColors.antiqueBrass,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading leaderboard',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: DarkAcademiaColors.cream,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: DarkAcademiaColors.cream.withValues(alpha: 0.7),
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadLeaderboard,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _topScores.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.casino,
                              size: 64,
                              color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No scores yet',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: DarkAcademiaColors.cream,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to play and set a record!',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: DarkAcademiaColors.cream.withValues(alpha: 0.7),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadLeaderboard,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // User's personal best (if exists and not in top 15)
                          if (_userBestScore != null &&
                              _userRank != null &&
                              _userRank! > 15) ...[
                            _buildPersonalBestCard(),
                            const SizedBox(height: 16),
                          ],

                          // Top 15 leaderboard
                          Card(
                            color: DarkAcademiaColors.navyBlue.withValues(alpha: 0.3),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.emoji_events,
                                        color: DarkAcademiaColors.antiqueBrass,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Top 15',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: DarkAcademiaColors.cream,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ..._topScores.asMap().entries.map((entry) {
                                    final rank = entry.key + 1;
                                    final score = entry.value;
                                    return _buildLeaderboardEntry(rank, score);
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildPersonalBestCard() {
    return Card(
      color: DarkAcademiaColors.deepForestGreen.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.person,
                  color: DarkAcademiaColors.antiqueBrass,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Best',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: DarkAcademiaColors.cream,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLeaderboardEntry(_userRank!, _userBestScore!, isCurrentUser: true),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardEntry(int rank, DicePokerScore score, {bool isCurrentUser = false}) {
    final user = FirebaseAuth.instance.currentUser;
    final isYou = user != null && score.userId == user.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isYou
            ? DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.2)
            : DarkAcademiaColors.charcoalGray.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: isYou
            ? Border.all(color: DarkAcademiaColors.antiqueBrass, width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 40,
            child: _buildRankBadge(rank),
          ),
          const SizedBox(width: 12),

          // Username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        score.username,
                        style: TextStyle(
                          color: DarkAcademiaColors.cream,
                          fontSize: 16,
                          fontWeight: isYou ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isYou) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: DarkAcademiaColors.antiqueBrass,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: DarkAcademiaColors.charcoalGray,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, y').format(score.timestamp),
                  style: TextStyle(
                    color: DarkAcademiaColors.cream.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Score
          Text(
            '${score.score}',
            style: const TextStyle(
              color: DarkAcademiaColors.antiqueBrass,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color badgeColor;
    Widget? icon;

    if (rank == 1) {
      badgeColor = const Color(0xFFFFD700); // Gold
      icon = const Icon(Icons.emoji_events, color: Colors.white, size: 20);
    } else if (rank == 2) {
      badgeColor = const Color(0xFFC0C0C0); // Silver
      icon = const Icon(Icons.emoji_events, color: Colors.white, size: 18);
    } else if (rank == 3) {
      badgeColor = const Color(0xFFCD7F32); // Bronze
      icon = const Icon(Icons.emoji_events, color: Colors.white, size: 16);
    } else {
      badgeColor = DarkAcademiaColors.charcoalGray;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: icon ??
            Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
      ),
    );
  }
}
