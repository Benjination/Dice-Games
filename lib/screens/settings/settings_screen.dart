import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/settings_service.dart';
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
                    leading: const Icon(Icons.email),
                    title: const Text('Email'),
                    subtitle: Text(user.email ?? 'No email'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('User ID'),
                    subtitle: Text(user.uid),
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
                    'Replace inappropriate words with ****** in game names and rules',
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
