import 'dice_config.dart';

/// Represents a saved dice roulette game with rules and metadata.
class SavedGame {
  final String? id; // Firestore document ID (null for unsaved)
  final String name;
  final String? generalRules; // Optional general rules text
  final List<DiceConfig> dice;
  final bool isPublic; // Public games visible to all; private only to creator
  final String? creatorUid; // Firebase Auth user ID
  final String? sharedBy; // UID of user who shared this game (if applicable)
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavedGame({
    this.id,
    required this.name,
    this.generalRules,
    required this.dice,
    this.isPublic = false,
    this.creatorUid,
    this.sharedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Returns true if this is a shared game (received from a friend)
  bool get isShared => sharedBy != null;

  SavedGame copyWith({
    String? id,
    String? name,
    String? generalRules,
    List<DiceConfig>? dice,
    bool? isPublic,
    String? creatorUid,
    String? sharedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedGame(
      id: id ?? this.id,
      name: name ?? this.name,
      generalRules: generalRules ?? this.generalRules,
      dice: dice ?? this.dice,
      isPublic: isPublic ?? this.isPublic,
      creatorUid: creatorUid ?? this.creatorUid,
      sharedBy: sharedBy ?? this.sharedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (generalRules != null) 'generalRules': generalRules,
      'dice': dice.map((d) => d.toJson()).toList(),
      'isPublic': isPublic,
      if (creatorUid != null) 'creatorUid': creatorUid,
      if (sharedBy != null) 'sharedBy': sharedBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SavedGame.fromJson(Map<String, dynamic> json) {
    return SavedGame(
      id: json['id'] as String?,
      name: json['name'] as String,
      generalRules: json['generalRules'] as String?,
      dice: (json['dice'] as List)
          .map((d) => DiceConfig.fromJson(d as Map<String, dynamic>))
          .toList(),
      isPublic: json['isPublic'] as bool? ?? false,
      creatorUid: json['creatorUid'] as String?,
      sharedBy: json['sharedBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
