import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for Squares grid-based dice game
/// Supports 2D grids (X, Y) and optional 3D mode (X, Y, Z layers)
class SquaresGame {
  final String gameId;
  final String name;
  final String description;
  final String category;
  
  // Dice configuration (4, 6, 8, 10, 12, 20 sides)
  final int xDieSides;
  final int yDieSides;
  final int? zDieSides; // Optional - enables 3D layer mode
  
  // Grid content - key format: "x,y" (always 2D, even in 3D mode)
  // In 3D mode, layers are modifiers/intensity, not separate grids
  final Map<String, String> gridContent;
  
  // Layer labels (only used if zDieSides is set)
  // These are modifiers/intensity for the grid content
  // Example: {1: "Friend: Sarah", 2: "Friend: Mike", 3: "Friend: John"}
  final Map<int, String>? layerLabels;
  
  // Completed squares tracking - key format: "x,y,z" (includes layer for 3D)
  // In 2D mode: "x,y", in 3D mode: "x,y,z"
  final Set<String> completedSquares;
  
  // Play mode settings
  final bool lockOutMode; // true = completed squares blocked, false = free play
  
  // Metadata
  final String creatorUid;
  final String creatorUsername;
  final DateTime createdAt;
  final bool isPublic;
  final String? sharedBy; // UID of user who shared this game (if applicable)

  const SquaresGame({
    required this.gameId,
    required this.name,
    required this.description,
    required this.category,
    required this.xDieSides,
    required this.yDieSides,
    this.zDieSides,
    this.gridContent = const {},
    this.layerLabels,
    this.completedSquares = const {},
    this.lockOutMode = true,
    required this.creatorUid,
    required this.creatorUsername,
    required this.createdAt,
    this.isPublic = false,
    this.sharedBy,
  });

  /// Check if game is in 3D mode
  bool get is3DMode => zDieSides != null;

  /// Returns true if this is a shared game (received from a friend)
  bool get isShared => sharedBy != null;

  /// Get total number of unique square positions (always 2D)
  int get totalSquares => xDieSides * yDieSides;
  
  /// Get total number of possible outcomes (includes layers in 3D)
  int get totalOutcomes {
    if (is3DMode) {
      return xDieSides * yDieSides * zDieSides!;
    }
    return xDieSides * yDieSides;
  }

  /// Get number of filled squares
  int get filledSquares => gridContent.length;

  /// Get number of completed squares
  int get completedCount => completedSquares.length;

  /// Check if a specific square is filled (always x,y - layers don't affect this)
  bool isSquareFilled(int x, int y) {
    final key = '$x,$y';
    return gridContent.containsKey(key);
  }

  /// Check if a specific outcome is completed (includes layer in 3D mode)
  bool isSquareCompleted(int x, int y, [int? z]) {
    final key = _makeKey(x, y, z);
    return completedSquares.contains(key);
  }

  /// Get content for a specific square (always x,y - layers are modifiers)
  String? getSquareContent(int x, int y) {
    final key = '$x,$y';
    return gridContent[key];
  }
  
  /// Get layer label for a specific z value
  String? getLayerLabel(int z) {
    return layerLabels?[z];
  }

  /// Helper to create consistent keys for completed tracking
  static String _makeKey(int x, int y, [int? z]) {
    if (z != null) {
      return '$x,$y,$z';
    }
    return '$x,$y';
  }

  /// Create a copy with updated fields
  SquaresGame copyWith({
    String? gameId,
    String? name,
    String? description,
    String? category,
    int? xDieSides,
    int? yDieSides,
    int? zDieSides,
    Map<String, String>? gridContent,
    Map<int, String>? layerLabels,
    Set<String>? completedSquares,
    bool? lockOutMode,
    String? creatorUid,
    String? creatorUsername,
    DateTime? createdAt,
    bool? isPublic,
    String? sharedBy,
  }) {
    return SquaresGame(
      gameId: gameId ?? this.gameId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      xDieSides: xDieSides ?? this.xDieSides,
      yDieSides: yDieSides ?? this.yDieSides,
      zDieSides: zDieSides ?? this.zDieSides,
      gridContent: gridContent ?? this.gridContent,
      layerLabels: layerLabels ?? this.layerLabels,
      completedSquares: completedSquares ?? this.completedSquares,
      lockOutMode: lockOutMode ?? this.lockOutMode,
      creatorUid: creatorUid ?? this.creatorUid,
      creatorUsername: creatorUsername ?? this.creatorUsername,
      createdAt: createdAt ?? this.createdAt,
      isPublic: isPublic ?? this.isPublic,
      sharedBy: sharedBy ?? this.sharedBy,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'xDieSides': xDieSides,
      'yDieSides': yDieSides,
      'zDieSides': zDieSides,
      'gridContent': gridContent,
      'layerLabels': layerLabels?.map((key, value) => MapEntry(key.toString(), value)),
      'lockOutMode': lockOutMode,
      'creatorUid': creatorUid,
      'creatorUsername': creatorUsername,
      'createdAt': Timestamp.fromDate(createdAt),
      'isPublic': isPublic,
      if (sharedBy != null) 'sharedBy': sharedBy,
    };
  }

  /// Create from Firestore document
  factory SquaresGame.fromFirestore(String docId, Map<String, dynamic> data) {
    return SquaresGame(
      gameId: docId,
      name: data['name'] as String,
      description: data['description'] as String,
      category: data['category'] as String,
      xDieSides: data['xDieSides'] as int,
      yDieSides: data['yDieSides'] as int,
      zDieSides: data['zDieSides'] as int?,
      gridContent: Map<String, String>.from(data['gridContent'] as Map? ?? {}),
      layerLabels: data['layerLabels'] != null
          ? Map<int, String>.from(
              (data['layerLabels'] as Map).map(
                (key, value) => MapEntry(int.parse(key.toString()), value.toString()),
              ),
            )
          : null,
      lockOutMode: data['lockOutMode'] as bool? ?? true,
      creatorUid: data['creatorUid'] as String,
      creatorUsername: data['creatorUsername'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isPublic: data['isPublic'] as bool? ?? false,
      sharedBy: data['sharedBy'] as String?,
      completedSquares: {}, // Not persisted - session only
    );
  }
}

/// Predefined categories for Squares games
class SquaresCategory {
  static const String romance = 'Romance';
  static const String workout = 'Workout';
  static const String sports = 'Sports';
  static const String funny = 'Funny';
  static const String party = 'Party';
  static const String education = 'Education';
  static const String custom = 'Custom';

  static const List<String> predefined = [
    romance,
    workout,
    sports,
    funny,
    party,
    education,
  ];

  static bool isPredefined(String category) {
    return predefined.contains(category);
  }
}
