/// Simple profanity filter service
class ProfanityFilter {
  static final _profanityWords = {
    // Common profanity (add more as needed)
    'fuck', 'shit', 'bitch', 'ass', 'damn', 'hell', 'crap',
    'dick', 'cock', 'pussy', 'bastard', 'asshole', 'fck',
    'sht', 'btch', 'dmn', 'cunt', 'piss', 'whore', 'slut',
    'fag', 'nigger', 'nigga', 'retard', 'retarded',
  };

  /// Filters profanity from [text] if [enabled] is true.
  /// Replaces profane words with ****** (case-insensitive).
  static String filter(String text, {required bool enabled}) {
    if (!enabled) return text;

    String filtered = text;
    for (final word in _profanityWords) {
      // Create regex for word with word boundaries, case-insensitive
      final regex = RegExp(r'\b' + word + r'\b', caseSensitive: false);
      filtered = filtered.replaceAll(regex, '******');
    }
    return filtered;
  }

  /// Checks if text contains profanity
  static bool containsProfanity(String text) {
    final lowerText = text.toLowerCase();
    for (final word in _profanityWords) {
      final regex = RegExp(r'\b' + word + r'\b');
      if (regex.hasMatch(lowerText)) {
        return true;
      }
    }
    return false;
  }
}
