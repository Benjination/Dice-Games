import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/settings_service.dart';
import '../../services/username_generator.dart';
import '../../theme/dark_academia_theme.dart';

/// Settings screen for app preferences
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _profanityFilterEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _ensureUsernameExists();
  }

  Future<void> _loadSettings() async {
    final filterEnabled = await SettingsService.getProfanityFilterEnabled();
    if (mounted) {
      setState(() {
        _profanityFilterEnabled = filterEnabled;
        _isLoading = false;
      });
    }
  }

  /// Ensures the current user has a username set
  /// Automatically generates one if missing
  Future<void> _ensureUsernameExists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && (user.displayName == null || user.displayName!.isEmpty)) {
      try {
        final username = UsernameGenerator.generate();
        await user.updateDisplayName(username);
        await user.reload();
        if (mounted) {
          setState(() {}); // Refresh to show new username
        }
      } catch (e) {
        // Silently fail - user can regenerate manually if needed
      }
    }
  }

  Future<void> _toggleProfanityFilter(bool value) async {
    await SettingsService.setProfanityFilterEnabled(value);
    if (mounted) {
      setState(() {
        _profanityFilterEnabled = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Profanity filter enabled'
                : 'Profanity filter disabled',
          ),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _regenerateUsername() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Username'),
        content: const Text(
          'Generate a new random username? Your old username will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate New'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final newUsername = UsernameGenerator.generate();
        await FirebaseAuth.instance.currentUser?.updateDisplayName(newUsername);
        await FirebaseAuth.instance.currentUser?.reload();
        
        if (mounted) {
          setState(() {}); // Refresh to show new username
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Username changed to $newUsername'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating username: $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Account section
                if (user != null) ...[
                  const ListTile(
                    title: Text(
                      'Account',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: DarkAcademiaColors.antiqueBrass,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: DarkAcademiaColors.antiqueBrass,
                      child: Text(
                        (user.displayName ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: DarkAcademiaColors.navyBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: const Text('Username'),
                    subtitle: Text(
                      user.displayName ?? 'No username set',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Regenerate username',
                      onPressed: _regenerateUsername,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Email'),
                    subtitle: Text(user.email ?? 'No email'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign Out'),
                    onTap: _signOut,
                  ),
                  const Divider(),
                ],
                // Content filtering section
                const ListTile(
                  title: Text(
                    'Content Filtering',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: DarkAcademiaColors.antiqueBrass,
                    ),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.filter_alt),
                  title: const Text('Profanity Filter'),
                  subtitle: const Text(
                    'Replace inappropriate words with ****** when publishing games. Private games are never filtered.',
                  ),
                  value: _profanityFilterEnabled,
                  onChanged: _toggleProfanityFilter,
                ),
                const Divider(),
                // About section
                const ListTile(
                  title: Text(
                    'About',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: DarkAcademiaColors.antiqueBrass,
                    ),
                  ),
                ),
                const ListTile(
                  leading: Icon(Icons.info),
                  title: Text('Version'),
                  subtitle: Text('1.0.0'),
                ),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Privacy Policy'),
                  onTap: () {
                    // TODO: Show privacy policy
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Privacy policy coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
