import 'package:flutter/material.dart';
import '../../services/friends_service.dart';
import '../../theme/dark_academia_theme.dart';

/// Screen for managing friends, friend requests, and searching for users
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _pendingRequestCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPendingCount();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(
              icon: Icon(Icons.people),
              text: 'Friends',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: _pendingRequestCount > 0,
                label: Text('$_pendingRequestCount'),
                child: const Icon(Icons.mail),
              ),
              text: 'Requests',
            ),
            const Tab(
              icon: Icon(Icons.person_add),
              text: 'Add Friend',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FriendsTab(onRequestCountChanged: _loadPendingCount),
          _RequestsTab(onRequestCountChanged: _loadPendingCount),
          _AddFriendTab(onRequestCountChanged: _loadPendingCount),
        ],
      ),
    );
  }
}

/// Tab showing list of friends
class _FriendsTab extends StatelessWidget {
  const _FriendsTab({required this.onRequestCountChanged});

  final VoidCallback onRequestCountChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FriendsService.friendsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final friends = snapshot.data ?? [];

        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: DarkAcademiaColors.cream.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'No friends yet',
                  style: TextStyle(
                    color: DarkAcademiaColors.cream.withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use the Add Friend tab to find people',
                  style: TextStyle(
                    color: DarkAcademiaColors.cream.withValues(alpha: 0.4),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: DarkAcademiaColors.antiqueBrass,
                  child: Text(
                    (friend['username'] as String)[0].toUpperCase(),
                    style: const TextStyle(
                      color: DarkAcademiaColors.navyBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  friend['username'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Friends',
                  style: TextStyle(
                    color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.person_remove, color: Colors.red),
                  tooltip: 'Remove friend',
                  onPressed: () => _confirmRemoveFriend(
                    context,
                    friend['uid'] as String,
                    friend['username'] as String,
                    onRequestCountChanged,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmRemoveFriend(
    BuildContext context,
    String friendUid,
    String username,
    VoidCallback onChanged,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Remove $username from your friends?'),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await FriendsService.removeFriend(friendUid);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed $username from friends')),
        );
        onChanged();
      }
    }
  }
}

/// Tab showing pending friend requests
class _RequestsTab extends StatelessWidget {
  const _RequestsTab({required this.onRequestCountChanged});

  final VoidCallback onRequestCountChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FriendsService.pendingRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 64,
                  color: DarkAcademiaColors.cream.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: TextStyle(
                    color: DarkAcademiaColors.cream.withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: DarkAcademiaColors.antiqueBrass,
                  child: Text(
                    (request['fromUsername'] as String)[0].toUpperCase(),
                    style: const TextStyle(
                      color: DarkAcademiaColors.navyBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  request['fromUsername'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Wants to be friends'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      tooltip: 'Accept',
                      onPressed: () => _acceptRequest(
                        context,
                        request['requestId'] as String,
                        request['fromUsername'] as String,
                        onRequestCountChanged,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      tooltip: 'Reject',
                      onPressed: () => _rejectRequest(
                        context,
                        request['requestId'] as String,
                        request['fromUsername'] as String,
                        onRequestCountChanged,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _acceptRequest(
    BuildContext context,
    String requestId,
    String username,
    VoidCallback onChanged,
  ) async {
    final success = await FriendsService.acceptFriendRequest(requestId);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You are now friends with $username!')),
      );
      onChanged();
    }
  }

  Future<void> _rejectRequest(
    BuildContext context,
    String requestId,
    String username,
    VoidCallback onChanged,
  ) async {
    final success = await FriendsService.rejectFriendRequest(requestId);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rejected friend request from $username')),
      );
      onChanged();
    }
  }
}

/// Tab for searching and adding new friends
class _AddFriendTab extends StatefulWidget {
  const _AddFriendTab({required this.onRequestCountChanged});

  final VoidCallback onRequestCountChanged;

  @override
  State<_AddFriendTab> createState() => _AddFriendTabState();
}

class _AddFriendTabState extends State<_AddFriendTab> {
  final _searchController = TextEditingController();
  List<Map<String, String>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final results = await FriendsService.searchUsers(query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by username...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _search(),
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            size: 64,
                            color: DarkAcademiaColors.cream.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'Search for users by username'
                                : 'No users found',
                            style: TextStyle(
                              color: DarkAcademiaColors.cream.withValues(alpha: 0.6),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: DarkAcademiaColors.antiqueBrass,
                              child: Text(
                                user['username']![0].toUpperCase(),
                                style: const TextStyle(
                                  color: DarkAcademiaColors.navyBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              user['username']!,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            trailing: FilledButton.icon(
                              onPressed: () => _sendFriendRequest(
                                user['uid']!,
                                user['username']!,
                              ),
                              icon: const Icon(Icons.person_add, size: 18),
                              label: const Text('Add'),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _sendFriendRequest(String toUid, String toUsername) async {
    final success = await FriendsService.sendFriendRequest(toUid, toUsername);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request sent to $toUsername')),
        );
        widget.onRequestCountChanged();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Already friends or request already sent'),
          ),
        );
      }
    }
  }
}
