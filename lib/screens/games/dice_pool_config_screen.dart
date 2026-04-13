import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/dice_config.dart';
import '../../models/saved_game.dart';
import '../../services/game_service.dart';
import '../../theme/dark_academia_theme.dart';
import './dice_pool_screen.dart';

/// Configuration screen for creating a custom dice roulette game.
/// Users set the number of dice (max 10) and configure each die's
/// label and number of faces.
class DicePoolConfigScreen extends StatefulWidget {
  const DicePoolConfigScreen({super.key});

  @override
  State<DicePoolConfigScreen> createState() => _DicePoolConfigScreenState();
}

class _DicePoolConfigScreenState extends State<DicePoolConfigScreen> {
  int _diceCount = 2;
  final List<_DieSetup> _dice = [
    _DieSetup(label: 'Die 1', sides: 6),
    _DieSetup(label: 'Die 2', sides: 6),
  ];

  final _availableSides = [4, 6, 8, 10, 12, 20];

  void _updateDiceCount(String value) {
    final count = int.tryParse(value);
    if (count == null || count < 1 || count > 10) return;

    setState(() {
      _diceCount = count;
      if (_dice.length < count) {
        // Add more dice
        while (_dice.length < count) {
          _dice.add(_DieSetup(
            label: 'Die ${_dice.length + 1}',
            sides: 6,
          ));
        }
      } else if (_dice.length > count) {
        // Remove excess
        _dice.removeRange(count, _dice.length);
      }
    });
  }

  void _launchGame() {
    final configs = _dice
        .map((d) => DiceConfig(label: d.label, sides: d.sides))
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DicePoolScreen(configs: configs),
      ),
    );
  }

  void _showSaveDialog() {
    final nameController = TextEditingController();
    bool isPublic = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Save Game'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Game Name',
                    hintText: 'Enter a name for this game',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Text(
                  'Visibility',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                RadioListTile<bool>(
                  title: const Text('Private'),
                  subtitle: const Text(
                    'Only you can see and play this game',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: false,
                  groupValue: isPublic,
                  onChanged: (value) {
                    setDialogState(() => isPublic = value!);
                  },
                ),
                RadioListTile<bool>(
                  title: const Text('Public'),
                  subtitle: const Text(
                    'Available to all players after moderation',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: true,
                  groupValue: isPublic,
                  onChanged: (value) {
                    setDialogState(() => isPublic = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _saveGame(nameController.text, isPublic),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveGame(String name, bool isPublic) async {
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a game name')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save games')),
      );
      return;
    }

    try {
      Navigator.of(context).pop(); // Close dialog first
      
      // Check if a game with this name already exists
      final existingGame = await GameService.findGameByName(name.trim());
      
      final configs = _dice
          .map((d) => DiceConfig(
                label: d.label,
                sides: d.sides,
              ))
          .toList();

      if (isPublic) {
        await GameService.publishGame(
          name: name.trim(),
          generalRules: '',
          diceConfigs: configs,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Game "${name.trim()}" submitted for moderation!')),
          );
        }
      } else {
        await GameService.saveGame(
          name: name.trim(),
          generalRules: '',
          diceConfigs: configs,
          gameId: existingGame?.id, // Pass existing ID to overwrite
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(existingGame != null
                  ? 'Game "${name.trim()}" updated!'
                  : 'Game "${name.trim()}" saved!'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving game: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Dice Roulette'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set up your dice roulette',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Configure the number of dice (max 10) and the faces '
                      'for each die.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    // Dice count input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Number of Dice',
                              hintText: '1-10',
                              prefixIcon: Icon(Icons.casino),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            controller: TextEditingController(
                              text: _diceCount.toString(),
                            )..selection = TextSelection.fromPosition(
                                TextPosition(
                                  offset: _diceCount.toString().length,
                                ),
                              ),
                            onChanged: _updateDiceCount,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Configure Each Die',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    // List of dice configurations
                    for (int i = 0; i < _dice.length; i++) ...[
                      _DieConfigRow(
                        die: _dice[i],
                        availableSides: _availableSides,
                        onSidesChanged: (sides) {
                          setState(() => _dice[i].sides = sides);
                        },                        onLabelChanged: (label) {
                          setState(() => _dice[i].label = label);
                        },                      ),
                      if (i < _dice.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            // Bottom action bar
            Container(
              decoration: BoxDecoration(
                color: DarkAcademiaColors.navyBlue,
                border: Border(
                  top: BorderSide(
                    color:
                        DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.2),
                  ),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$_diceCount ${_diceCount == 1 ? 'die' : 'dice'} configured',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showSaveDialog,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Game'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _launchGame,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper classes
// ---------------------------------------------------------------------------

class _DieSetup {
  String label;
  int sides;

  _DieSetup({
    required this.label,
    required this.sides,
  });
}

class _DieConfigRow extends StatefulWidget {
  const _DieConfigRow({
    required this.die,
    required this.availableSides,
    required this.onSidesChanged,
    required this.onLabelChanged,
  });

  final _DieSetup die;
  final List<int> availableSides;
  final ValueChanged<int> onSidesChanged;
  final ValueChanged<String> onLabelChanged;

  @override
  State<_DieConfigRow> createState() => _DieConfigRowState();
}

class _DieConfigRowState extends State<_DieConfigRow> {
  late TextEditingController _labelController;
  final FocusNode _focusNode = FocusNode();
  late String _previousLabel;

  @override
  void initState() {
    super.initState();
    _previousLabel = widget.die.label;
    _labelController = TextEditingController(text: widget.die.label);
    
    // Select all text when gaining focus for easier editing
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _labelController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _labelController.text.length,
        );
      } else {
        // On focus loss, validate and restore if empty
        _validateAndRestore();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _updateLabel(String value) {
    // Allow alphanumeric characters, spaces, and basic punctuation
    final trimmed = value.trim();
    
    // Update parent with the cleaned value
    if (trimmed.isNotEmpty) {
      _previousLabel = trimmed;
      widget.onLabelChanged(trimmed);
    }
  }

  void _validateAndRestore() {
    final trimmed = _labelController.text.trim();
    if (trimmed.isEmpty) {
      // Restore previous value if empty
      _labelController.text = _previousLabel;
      widget.onLabelChanged(_previousLabel);
    } else {
      // Save the current trimmed value
      _previousLabel = trimmed;
      _labelController.text = trimmed;
      widget.onLabelChanged(trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            // Label input
            SizedBox(
              width: 200,
              child: TextField(
                controller: _labelController,
                focusNode: _focusNode,
                textAlign: TextAlign.center,
                maxLength: 30,
                style: const TextStyle(
                  color: DarkAcademiaColors.antiqueBrass,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'Die Name',
                  labelStyle: TextStyle(
                    color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.4),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.4),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: DarkAcademiaColors.antiqueBrass,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: DarkAcademiaColors.charcoalGray,
                ),
                onChanged: _updateLabel,
              ),
            ),
            const SizedBox(width: 16),
            // Sides dropdown
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: widget.die.sides,
                decoration: const InputDecoration(
                  labelText: 'Faces',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: widget.availableSides
                    .map(
                      (sides) => DropdownMenuItem(
                        value: sides,
                        child: Text('d$sides ($sides faces)'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) widget.onSidesChanged(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
