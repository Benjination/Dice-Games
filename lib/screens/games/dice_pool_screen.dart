import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/dice_config.dart';
import '../../theme/dark_academia_theme.dart';
import '../../services/game_service.dart';

/// Dice bias modes for rolling
enum DiceBias {
  fair,      // Normal uniform distribution
  mean,      // Biased toward high values (sqrt distribution)
  nice,      // Biased toward low values (squared distribution)
}

/// A free-form dice roulette game: each die has a letter label and configurable
/// number of sides. Dice can be rolled individually (tap) or all at once.
/// Supports fair, mean (high-bias), and nice (low-bias) dice modes.
class DicePoolScreen extends StatefulWidget {
  const DicePoolScreen({
    super.key,
    required this.configs,
    this.gameName = 'Dice Roulette',
  });

  final List<DiceConfig> configs;
  final String gameName;

  @override
  State<DicePoolScreen> createState() => _DicePoolScreenState();
}

class _DicePoolScreenState extends State<DicePoolScreen> {
  late List<int?> _values;
  DiceBias _diceBias = DiceBias.fair;
  late Random _random;
  
  final _generalRulesController = TextEditingController();
  final Map<String, Map<int, TextEditingController>> _faceRulesControllers = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final seed = Object.hashAll([
      now.microsecondsSinceEpoch,
      now.millisecondsSinceEpoch,
      widget.configs.length,
    ]);
    _random = Random(seed);
    _values = List.filled(widget.configs.length, null);
    
    // Initialize face rules controllers for each die and each face
    for (final config in widget.configs) {
      _faceRulesControllers[config.label] = {};
      for (int face = 1; face <= config.sides; face++) {
        _faceRulesControllers[config.label]![face] = TextEditingController(
          text: config.faceRules?[face] ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    _generalRulesController.dispose();
    for (final dieControllers in _faceRulesControllers.values) {
      for (final controller in dieControllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  /// Rolls a single die with [sides] faces.
  ///
  /// Fair mode: uniform distribution over [1, sides].
  ///
  /// Mean Dice mode: uses a square-root distribution (PDF = 2x over [0,1])
  /// which heavily favors higher results — rolling 6 on a d6 is ~17× more
  /// likely than rolling 1.
  ///
  /// Nice Dice mode: uses a squared distribution (PDF = 2(1-x) over [0,1])
  /// which heavily favors lower results — rolling 1 on a d6 is ~17× more
  /// likely than rolling 6.
  int _computeRoll(int sides) {
    if (_diceBias == DiceBias.mean) {
      // sqrt(U) where U ~ Uniform[0,1) has PDF f(x) = 2x → biased high
      final raw = sqrt(_random.nextDouble());
      return (raw * sides).floor().clamp(0, sides - 1) + 1;
    } else if (_diceBias == DiceBias.nice) {
      // U^2 where U ~ Uniform[0,1) has PDF f(x) = 2(1-x) → biased low
      final raw = _random.nextDouble();
      final squared = raw * raw;
      return (squared * sides).floor().clamp(0, sides - 1) + 1;
    }
    return _random.nextInt(sides) + 1;
  }

  void _rollDie(int index) {
    setState(() {
      final updated = List<int?>.from(_values);
      updated[index] = _computeRoll(widget.configs[index].sides);
      _values = updated;
    });
  }

  void _rollAll() {
    setState(() {
      _values = List.generate(
        widget.configs.length,
        (i) => _computeRoll(widget.configs[i].sides),
      );
    });
  }

  void _reset() {
    setState(() {
      _values = List.filled(widget.configs.length, null);
    });
  }

  bool get _anyRolled => _values.any((v) => v != null);

  /// Shows dialog to save game privately
  Future<void> _showSaveDialog() async {
    final nameController = TextEditingController(text: widget.gameName);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Game'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Save this game configuration to your library.'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Game Name',
                border: OutlineInputBorder(),
              ),
              maxLength: 50,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _saveGame(nameController.text.trim());
    }
  }

  /// Shows dialog to publish game
  Future<void> _showPublishDialog() async {
    final nameController = TextEditingController(text: widget.gameName);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish Game'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Publish this game for others to play. Your game will be reviewed by moderators before being made public.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Game Name',
                border: OutlineInputBorder(),
              ),
              maxLength: 50,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _publishGame(nameController.text.trim());
    }
  }

  /// Saves game privately
  Future<void> _saveGame(String name) async {
    if (name.isEmpty) {
      _showSnackBar('Please enter a game name');
      return;
    }

    try {
      // Get current face rules from controllers
      final updatedConfigs = widget.configs.map((config) {
        final faceRules = <int, String>{};
        final controllers = _faceRulesControllers[config.label]!;
        for (final entry in controllers.entries) {
          if (entry.value.text.trim().isNotEmpty) {
            faceRules[entry.key] = entry.value.text.trim();
          }
        }
        return DiceConfig(
          label: config.label,
          sides: config.sides,
          faceRules: faceRules.isEmpty ? null : faceRules,
        );
      }).toList();

      await GameService.saveGame(
        name: name,
        generalRules: _generalRulesController.text.trim(),
        diceConfigs: updatedConfigs,
      );

      if (mounted) {
        _showSnackBar('Game saved successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error saving game: $e');
      }
    }
  }

  /// Publishes game for moderation
  Future<void> _publishGame(String name) async {
    if (name.isEmpty) {
      _showSnackBar('Please enter a game name');
      return;
    }

    try {
      // Get current face rules from controllers
      final updatedConfigs = widget.configs.map((config) {
        final faceRules = <int, String>{};
        final controllers = _faceRulesControllers[config.label]!;
        for (final entry in controllers.entries) {
          if (entry.value.text.trim().isNotEmpty) {
            faceRules[entry.key] = entry.value.text.trim();
          }
        }
        return DiceConfig(
          label: config.label,
          sides: config.sides,
          faceRules: faceRules.isEmpty ? null : faceRules,
        );
      }).toList();

      await GameService.publishGame(
        name: name,
        generalRules: _generalRulesController.text.trim(),
        diceConfigs: updatedConfigs,
      );

      if (mounted) {
        _showSnackBar('Game submitted for moderation!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error publishing game: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gameName),
        actions: [
          IconButton(
            onPressed: _showSaveDialog,
            icon: const Icon(Icons.save),
            tooltip: 'Save Game',
          ),
          IconButton(
            onPressed: _showPublishDialog,
            icon: const Icon(Icons.publish),
            tooltip: 'Publish Game',
          ),
          if (_anyRolled)
            IconButton(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset all dice',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Dice display - centered
                    Center(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          for (int i = 0; i < widget.configs.length; i++)
                            _DieCard(
                              config: widget.configs[i],
                              value: _values[i],
                              onTap: () => _rollDie(i),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Rules section - centered with max width
                    _RulesSection(
                      configs: widget.configs,
                      generalRulesController: _generalRulesController,
                      faceRulesControllers: _faceRulesControllers,
                    ),
                  ],
                ),
              ),
            ),
            _BottomBar(
              diceBias: _diceBias,
              onDiceBiasChanged: (bias) => setState(() => _diceBias = bias),
              onRollAll: _rollAll,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Die card widget
// ---------------------------------------------------------------------------

class _DieCard extends StatelessWidget {
  const _DieCard({
    required this.config,
    required this.value,
    required this.onTap,
  });

  final DiceConfig config;
  final int? value;
  final VoidCallback onTap;

  /// Builds the dice image widget for the given [value].
  /// - For 1-6: shows the corresponding dice image (6.1.png through 6.6.png)
  /// - For 7+: shows ?.? with the number overlaid on top
  Widget _buildDiceImage(int value) {
    final imagePath = value >= 1 && value <= 6
        ? 'assets/images/dice-images/6.$value.png'
        : 'assets/images/dice-images/?.?';

    if (value <= 6) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain,
        ),
      );
    }

    // For values > 6, overlay the number on the blank die
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            imagePath,
            fit: BoxFit.contain,
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              color: DarkAcademiaColors.darkText,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: DarkAcademiaColors.cream,
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final borderColor = hasValue
        ? DarkAcademiaColors.antiqueBrass
        : DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.25);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 110,
        height: 130,
        decoration: BoxDecoration(
          color: DarkAcademiaColors.charcoalGray,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: hasValue ? 2.0 : 1.0,
          ),
          boxShadow: hasValue
              ? [
                  BoxShadow(
                    color: DarkAcademiaColors.antiqueBrass.withValues(
                      alpha: 0.25,
                    ),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top row: letter label + subtle tap hint
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    config.label,
                    style: const TextStyle(
                      color: DarkAcademiaColors.antiqueBrass,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Icon(
                    Icons.touch_app,
                    size: 12,
                    color: DarkAcademiaColors.antiqueBrass.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            // Centre: dice image or placeholder
            Expanded(
              child: Center(
                child: hasValue
                    ? _buildDiceImage(value!)
                    : Text(
                        '—',
                        style: TextStyle(
                          color: DarkAcademiaColors.cream.withValues(alpha: 0.2),
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
              ),
            ),
            // Bottom: die-type label
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'd${config.sides}',
                style: TextStyle(
                  color: DarkAcademiaColors.cream.withValues(alpha: 0.35),
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom action bar
// ---------------------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.diceBias,
    required this.onDiceBiasChanged,
    required this.onRollAll,
  });

  final DiceBias diceBias;
  final ValueChanged<DiceBias> onDiceBiasChanged;
  final VoidCallback onRollAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DarkAcademiaColors.navyBlue,
        border: Border(
          top: BorderSide(
            color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.2),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Dice bias toggles grouped together
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mean Dice toggle
              Row(
                children: [
                  Text(
                    'Mean Dice',
                    style: TextStyle(
                      color: diceBias == DiceBias.mean
                          ? DarkAcademiaColors.antiqueBrass
                          : DarkAcademiaColors.cream,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: diceBias == DiceBias.mean,
                    onChanged: (value) {
                      onDiceBiasChanged(
                        value ? DiceBias.mean : DiceBias.fair,
                      );
                    },
                    thumbColor: WidgetStateProperty.resolveWith<Color?>(
                      (states) => states.contains(WidgetState.selected)
                          ? DarkAcademiaColors.antiqueBrass
                          : null,
                    ),
                    trackColor: WidgetStateProperty.resolveWith<Color?>(
                      (states) => states.contains(WidgetState.selected)
                          ? DarkAcademiaColors.antiqueBrass.withValues(
                              alpha: 0.35,
                            )
                          : null,
                    ),
                  ),
                  Text(
                    diceBias == DiceBias.mean ? 'Biased high' : '',
                    style: TextStyle(
                      color: DarkAcademiaColors.cream.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Nice Dice toggle
              Row(
                children: [
                  Text(
                    'Nice Dice',
                    style: TextStyle(
                      color: diceBias == DiceBias.nice
                          ? DarkAcademiaColors.antiqueBrass
                          : DarkAcademiaColors.cream,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: diceBias == DiceBias.nice,
                    onChanged: (value) {
                      onDiceBiasChanged(
                        value ? DiceBias.nice : DiceBias.fair,
                      );
                    },
                    thumbColor: WidgetStateProperty.resolveWith<Color?>(
                      (states) => states.contains(WidgetState.selected)
                          ? DarkAcademiaColors.antiqueBrass
                          : null,
                    ),
                    trackColor: WidgetStateProperty.resolveWith<Color?>(
                      (states) => states.contains(WidgetState.selected)
                          ? DarkAcademiaColors.antiqueBrass.withValues(
                              alpha: 0.35,
                            )
                          : null,
                    ),
                  ),
                  Text(
                    diceBias == DiceBias.nice ? 'Biased low' : '',
                    style: TextStyle(
                      color: DarkAcademiaColors.cream.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Roll all button
          FilledButton.icon(
            onPressed: onRollAll,
            icon: const Icon(Icons.casino),
            label: const Text('Roll Dice'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rules section widget
// ---------------------------------------------------------------------------

class _RulesSection extends StatelessWidget {
  const _RulesSection({
    required this.configs,
    required this.generalRulesController,
    required this.faceRulesControllers,
  });

  final List<DiceConfig> configs;
  final TextEditingController generalRulesController;
  final Map<String, Map<int, TextEditingController>> faceRulesControllers;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // General rules card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description,
                        size: 20,
                        color: DarkAcademiaColors.antiqueBrass,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Game Rules',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: DarkAcademiaColors.antiqueBrass,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: generalRulesController,
                    decoration: const InputDecoration(
                      hintText: 'Describe the rules of your game...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    minLines: 2,
                    maxLength: 500,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Per-die rules cards - 5 per row
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            children: [
              for (int i = 0; i < configs.length; i++)
                SizedBox(
                  width: (600 - 48) / 5, // (maxWidth - spacing) / 5
                  child: _DieRulesPanel(
                    config: configs[i],
                    faceControllers: faceRulesControllers[configs[i].label]!,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Die rules panel widget
// ---------------------------------------------------------------------------

class _DieRulesPanel extends StatefulWidget {
  const _DieRulesPanel({
    required this.config,
    required this.faceControllers,
  });

  final DiceConfig config;
  final Map<int, TextEditingController> faceControllers;

  @override
  State<_DieRulesPanel> createState() => _DieRulesPanelState();
}

class _DieRulesPanelState extends State<_DieRulesPanel> {
  int? _editingFace;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Die label header
            Text(
              widget.config.label,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: DarkAcademiaColors.antiqueBrass,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Face rules
            ...List.generate(widget.config.sides, (index) {
              final face = index + 1;
              final controller = widget.faceControllers[face]!;
              final hasText = controller.text.trim().isNotEmpty;
              final isEditing = _editingFace == face;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: isEditing
                    ? TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: InputDecoration(
                          prefixText: '$face - ',
                          prefixStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: DarkAcademiaColors.antiqueBrass,
                          ),
                          hintText: 'Enter rule',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          isDense: true,
                        ),
                        maxLength: 60,
                        style: const TextStyle(fontSize: 13),
                        onSubmitted: (_) {
                          setState(() => _editingFace = null);
                        },
                        onTapOutside: (_) {
                          setState(() => _editingFace = null);
                        },
                      )
                    : InkWell(
                        onTap: () {
                          setState(() => _editingFace = face);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$face - ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: DarkAcademiaColors.antiqueBrass,
                                  fontSize: 13,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  hasText ? controller.text : 'No rule set',
                                  style: TextStyle(
                                    color: hasText
                                        ? DarkAcademiaColors.cream
                                        : DarkAcademiaColors.cream.withValues(
                                            alpha: 0.4,
                                          ),
                                    fontStyle: hasText
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
