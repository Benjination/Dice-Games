class DiceConfig {
  final String label; // Die name (up to 30 characters)
  final int sides;    // Number of faces on this die
  final Map<int, String>? faceRules; // Optional: rules for each face (1-based)

  const DiceConfig({
    required this.label,
    required this.sides,
    this.faceRules,
  });

  DiceConfig copyWith({
    String? label,
    int? sides,
    Map<int, String>? faceRules,
  }) {
    return DiceConfig(
      label: label ?? this.label,
      sides: sides ?? this.sides,
      faceRules: faceRules ?? this.faceRules,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'sides': sides,
      if (faceRules != null)
        'faceRules': faceRules!.map((k, v) => MapEntry(k.toString(), v)),
    };
  }

  factory DiceConfig.fromJson(Map<String, dynamic> json) {
    return DiceConfig(
      label: json['label'] as String,
      sides: json['sides'] as int,
      faceRules: json['faceRules'] != null
          ? (json['faceRules'] as Map<String, dynamic>)
              .map((k, v) => MapEntry(int.parse(k), v as String))
          : null,
    );
  }
}
