import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app settings
class SettingsService {
  static const _profanityFilterKey = 'profanity_filter_enabled';

  /// Gets profanity filter setting (default: true)
  static Future<bool> getProfanityFilterEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_profanityFilterKey) ?? true; // Default on
  }

  /// Sets profanity filter setting
  static Future<void> setProfanityFilterEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_profanityFilterKey, enabled);
  }
}
