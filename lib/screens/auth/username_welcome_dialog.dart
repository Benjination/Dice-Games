import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../../services/username_generator.dart';
import '../../theme/dark_academia_theme.dart';

/// Dialog shown to new users to confirm their auto-generated username
/// Allows regeneration until they find one they like, then locks it permanently
class UsernameWelcomeDialog extends StatefulWidget {
  const UsernameWelcomeDialog({super.key, required this.initialUsername});

  final String initialUsername;

  @override
  State<UsernameWelcomeDialog> createState() => _UsernameWelcomeDialogState();
}

class _UsernameWelcomeDialogState extends State<UsernameWelcomeDialog> {
  late String _currentUsername;
  bool _isRegenerating = false;

  @override
  void initState() {
    super.initState();
    _currentUsername = widget.initialUsername;
  }

  Future<void> _regenerateUsername() async {
    setState(() {
      _isRegenerating = true;
    });

    try {
      // Generate new unique username
      final newUsername = UsernameGenerator.generate();
      final success = await UserService.updateUsername(newUsername);
      
      if (success && mounted) {
        setState(() {
          _currentUsername = newUsername;
          _isRegenerating = false;
        });
      } else if (mounted) {
        // Try again if username was taken
        await _regenerateUsername();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRegenerating = false;
        });
      }
    }
  }

  Future<void> _confirmUsername() async {
    // Lock the username permanently
    await UserService.lockUsername();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Welcome!',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Your username has been generated:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundColor: DarkAcademiaColors.antiqueBrass,
                  child: Text(
                    _currentUsername[0].toUpperCase(),
                    style: const TextStyle(
                      color: DarkAcademiaColors.navyBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _currentUsername,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: DarkAcademiaColors.antiqueBrass,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Not a fan? Regenerate until you find one you like!',
            style: TextStyle(
              fontSize: 12,
              color: DarkAcademiaColors.cream.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '⚠️ Once confirmed, your username is permanent',
            style: TextStyle(
              fontSize: 11,
              color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: _isRegenerating ? null : _regenerateUsername,
          icon: _isRegenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 20),
          label: Text(_isRegenerating ? 'Generating...' : 'Try Another'),
        ),
        FilledButton.icon(
          onPressed: _isRegenerating ? null : _confirmUsername,
          icon: const Icon(Icons.check_circle, size: 20),
          label: const Text('Looks Good!'),
        ),
      ],
    );
  }
}
