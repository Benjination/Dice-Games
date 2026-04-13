import 'dart:math';

/// Service for generating human-readable usernames in the format AdjectiveNoun####
/// Similar to Xbox gamertags or Spectrum usernames
class UsernameGenerator {
  static final _random = Random();

  // Curated list of positive adjectives
  static const _adjectives = [
    'Bold', 'Brave', 'Bright', 'Calm', 'Clever', 'Cool', 'Cosmic', 'Daring',
    'Divine', 'Epic', 'Fearless', 'Fierce', 'Free', 'Golden', 'Grand', 'Happy',
    'Heroic', 'Honest', 'Iron', 'Jolly', 'Kind', 'Lucky', 'Loyal', 'Magic',
    'Mighty', 'Noble', 'Quick', 'Radiant', 'Rapid', 'Royal', 'Sacred', 'Silent',
    'Silver', 'Smart', 'Solar', 'Sonic', 'Stellar', 'Strong', 'Swift', 'Thunder',
    'Titan', 'True', 'Turbo', 'Ultra', 'Valiant', 'Vivid', 'Wild', 'Wise',
    'Azure', 'Blazing', 'Cosmic', 'Crimson', 'Crystal', 'Diamond', 'Electric',
    'Emerald', 'Ethereal', 'Fabled', 'Frost', 'Jade', 'Lunar', 'Mystic',
    'Neon', 'Omega', 'Phoenix', 'Prism', 'Quantum', 'Rogue', 'Sapphire',
    'Shadow', 'Spark', 'Storm', 'Velvet', 'Volt', 'Zen',
  ];

  // Curated list of nouns (animals, objects, nature)
  static const _nouns = [
    'Bear', 'Dragon', 'Eagle', 'Falcon', 'Fox', 'Hawk', 'Lion', 'Owl',
    'Panther', 'Phoenix', 'Raven', 'Tiger', 'Wolf', 'Cobra', 'Jaguar',
    'Viper', 'Shark', 'Orca', 'Lynx', 'Puma', 'Leopard', 'Cheetah',
    'Blade', 'Arrow', 'Sword', 'Shield', 'Star', 'Crown', 'Flame', 'Spark',
    'Bolt', 'Storm', 'Thunder', 'Wind', 'Wave', 'Cloud', 'Moon', 'Sun',
    'Nova', 'Comet', 'Meteor', 'Nebula', 'Galaxy', 'Cosmos', 'Orbit',
    'Mountain', 'River', 'Ocean', 'Forest', 'Desert', 'Canyon', 'Valley',
    'Peak', 'Summit', 'Dawn', 'Dusk', 'Eclipse', 'Horizon', 'Aurora',
    'Knight', 'Warrior', 'Hunter', 'Ranger', 'Mage', 'Sage', 'Guardian',
    'Champion', 'Legend', 'Hero', 'Titan', 'Sentinel', 'Paladin',
  ];

  /// Generates a random username in the format AdjectiveNoun####
  /// Example: BraveDragon5847
  static String generate() {
    final adjective = _adjectives[_random.nextInt(_adjectives.length)];
    final noun = _nouns[_random.nextInt(_nouns.length)];
    final number = _random.nextInt(10000).toString().padLeft(4, '0');
    
    return '$adjective$noun$number';
  }

  /// Generates a username with a seed for reproducibility
  /// Useful for testing or user-specific generation
  static String generateWithSeed(int seed) {
    final random = Random(seed);
    final adjective = _adjectives[random.nextInt(_adjectives.length)];
    final noun = _nouns[random.nextInt(_nouns.length)];
    final number = random.nextInt(10000).toString().padLeft(4, '0');
    
    return '$adjective$noun$number';
  }

  /// Checks if a username follows the AdjectiveNoun#### format
  static bool isValidFormat(String username) {
    // Should be like: BraveDragon5847
    // Format: [A-Z][a-z]+[A-Z][a-z]+[0-9]{4}
    final regex = RegExp(r'^[A-Z][a-z]+[A-Z][a-z]+\d{4}$');
    return regex.hasMatch(username);
  }

  /// Extracts the numeric suffix from a username
  /// Returns null if not in valid format
  static String? getNumberSuffix(String username) {
    if (!isValidFormat(username)) return null;
    return username.substring(username.length - 4);
  }
}
