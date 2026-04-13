import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/settings_service.dart';
import '../../services/username_generator.dart';
import '../../services/user_service.dart';
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
  String? _username;

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

  /// Ensures the current user has a username set in Firestore
  /// Automatically generates one if missing
  Future<void> _ensureUsernameExists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // This will create/update user doc and ensure valid username exists
        await UserService.ensureUserDocument(user);
        // Load the username
        final username = await UserService.getCurrentUsername();
        if (mounted) {
          setState(() {
            _username = username;
          });
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
        await UserService.updateUsername(newUsername);
        
        if (mounted) {
          setState(() {
            _username = newUsername;
          });
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

  Future<void> _showInstallDialog() async {
    // Detect device type from user agent
    final isIOS = kIsWeb && 
        (RegExp(r'iPhone|iPad|iPod').hasMatch(
            Uri.base.toString()) || 
         RegExp(r'iPhone|iPad|iPod').hasMatch(
            WidgetsBinding.instance.platformDispatcher.defaultRouteName));
    
    if (!kIsWeb) {
      // Native app already installed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are already using the native app!'),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isIOS ? Icons.phone_iphone : Icons.phone_android,
              color: DarkAcademiaColors.antiqueBrass,
            ),
            const SizedBox(width: 12),
            const Text('Install App'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isIOS ? 'Install on iOS:' : 'Install on Android/Desktop:',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              if (isIOS) ...[
                _buildInstallStep(
                  '1',
                  'Tap the Share button',
                  Icons.ios_share,
                ),
                const SizedBox(height: 8),
                _buildInstallStep(
                  '2',
                  'Scroll down and tap "Add to Home Screen"',
                  Icons.add_box_outlined,
                ),
                const SizedBox(height: 8),
                _buildInstallStep(
                  '3',
                  'Tap "Add" to confirm',
                  Icons.check_circle_outline,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: DarkAcademiaColors.antiqueBrass,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Note: This feature only works in Safari browser on iOS',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _buildInstallStep(
                  '1',
                  'Click the install icon in your browser\'s address bar',
                  Icons.download,
                ),
                const SizedBox(height: 8),
                _buildInstallStep(
                  '2',
                  'Or use browser menu → "Install DiceGames"',
                  Icons.more_vert,
                ),
                const SizedBox(height: 8),
                _buildInstallStep(
                  '3',
                  'The app will be added to your home screen',
                  Icons.home,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 20,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Works offline • Fast loading • Native feel',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallStep(String number, String text, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: DarkAcademiaColors.antiqueBrass,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: DarkAcademiaColors.navyBlue,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, size: 20, color: DarkAcademiaColors.antiqueBrass),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
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
                        (_username ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: DarkAcademiaColors.navyBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: const Text('Username'),
                    subtitle: Text(
                      _username ?? 'Loading...',
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
                // Install App section (PWA)
                if (kIsWeb) ...[
                  const ListTile(
                    title: Text(
                      'Mobile App',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: DarkAcademiaColors.antiqueBrass,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('Install App'),
                    subtitle: const Text(
                      'Add DiceGames to your phone\'s home screen for a native app experience',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showInstallDialog,
                  ),
                  const Divider(),
                ],
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
