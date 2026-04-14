import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/squares_game.dart';
import '../../../services/user_service.dart';
import '../../../services/squares_service.dart';
import '../../../theme/dark_academia_theme.dart';
import './squares_play_screen.dart';

/// Builder screen for creating custom Squares grid games
class SquaresBuilderScreen extends StatefulWidget {
  final SquaresGame? existingGame; // For editing saved games

  const SquaresBuilderScreen({super.key, this.existingGame});

  @override
  State<SquaresBuilderScreen> createState() => _SquaresBuilderScreenState();
}

class _SquaresBuilderScreenState extends State<SquaresBuilderScreen> {
  late int _xDieSides;
  late int _yDieSides;
  int? _zDieSides; // null = 2D mode, value = 3D mode
  
  late Map<String, String> _gridContent;
  late Map<int, String> _layerLabels;
  late bool _lockOutMode;

  final List<int> _availableSides = [4, 6, 8, 10, 12, 20];
  int _currentLayer = 1; // For 3D mode viewing
  
  @override
  void initState() {
    super.initState();
    if (widget.existingGame != null) {
      final game = widget.existingGame!;
      _xDieSides = game.xDieSides;
      _yDieSides = game.yDieSides;
      _zDieSides = game.zDieSides;
      _gridContent = Map.from(game.gridContent);
      _layerLabels = game.layerLabels != null ? Map.from(game.layerLabels!) : {};
      _lockOutMode = game.lockOutMode;
    } else {
      _xDieSides = 6;
      _yDieSides = 6;
      _zDieSides = null;
      _gridContent = {};
      _layerLabels = {};
      _lockOutMode = true;
    }
  }

  bool get _is3DMode => _zDieSides != null;

  String _makeKey(int x, int y, [int? z]) {
    if (z != null) return '$x,$y,$z';
    return '$x,$y';
  }

  void _toggleDimensionMode() {
    setState(() {
      if (_is3DMode) {
        // Switch to 2D: remove all Z coordinates and layer labels
        final new2DContent = <String, String>{};
        _gridContent.forEach((key, value) {
          final parts = key.split(',');
          if (parts.length == 3) {
            // Only keep layer 1 content when collapsing
            if (parts[2] == '1') {
              new2DContent['${parts[0]},${parts[1]}'] = value;
            }
          }
        });
        _gridContent = new2DContent;
        _zDieSides = null;
       _layerLabels = {};
        _currentLayer = 1;
      } else {
        // Switch to 3D: convert existing 2D grid to layer 1
        final new3DContent = <String, String>{};
        _gridContent.forEach((key, value) {
          new3DContent['$key,1'] = value;
        });
        _gridContent = new3DContent;
        _zDieSides = 6;
        _layerLabels = {1: 'Layer 1', 2: 'Layer 2', 3: 'Layer 3', 4: 'Layer 4', 5: 'Layer 5', 6: 'Layer 6'};
      }
    });
  }

  void _onDieSidesChanged(String axis, int newSides) {
    setState(() {
      if (axis == 'X') {
        _xDieSides = newSides;
      } else if (axis == 'Y') {
        _yDieSides = newSides;
      } else if (axis == 'Z') {
        _zDieSides = newSides;
        // Update layer labels to match new layer count
        final newLabels = <int, String>{};
        for (int i = 1; i <= newSides; i++) {
          newLabels[i] = _layerLabels[i] ?? 'Layer $i';
        }
        _layerLabels = newLabels;
      }
      
      // Remove grid content that's now out of bounds
      final keysToRemove = <String>[];
      _gridContent.forEach((key, _) {
        final parts = key.split(',');
        final x = int.parse(parts[0]);
        final y = int.parse(parts[1]);
        final z = parts.length > 2 ? int.parse(parts[2]) : null;
        
        if (x > _xDieSides || y > _yDieSides || (z != null && _zDieSides != null && z > _zDieSides!)) {
          keysToRemove.add(key);
        }
      });
      
      for (final key in keysToRemove) {
        _gridContent.remove(key);
      }
    });
  }

  void _editSquare(int x, int y, [int? z]) {
    final key = _makeKey(x, y, z);
    final controller = TextEditingController(text: _gridContent[key] ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_is3DMode ? 'Square ($x, $y, $z)' : 'Square ($x, $y)'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Content',
            hintText: 'Enter text for this square',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          if (_gridContent.containsKey(key))
            TextButton(
              onPressed: () {
                setState(() => _gridContent.remove(key));
                Navigator.pop(context);
              },
              child: const Text('Clear'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              setState(() {
                if (text.isEmpty) {
                  _gridContent.remove(key);
                } else {
                  _gridContent[key] = text;
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editLayerLabel(int layer) {
    final controller = TextEditingController(text: _layerLabels[layer] ?? 'Layer $layer');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Layer $layer Label'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Layer Name',
            hintText: 'e.g., Easy, Medium, Hard',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _layerLabels[layer] = controller.text.trim();
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _launchGame() async {
    final user = FirebaseAuth.instance.currentUser;
    final username = user != null ? await UserService.getCurrentUsername() ?? 'Guest' : 'Guest';
    
    final game = SquaresGame(
      gameId: widget.existingGame?.gameId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: widget.existingGame?.name ?? 'Unsaved Game',
      description: widget.existingGame?.description ?? '',
      category: widget.existingGame?.category ?? 'Custom',
      xDieSides: _xDieSides,
      yDieSides: _yDieSides,
      zDieSides: _zDieSides,
      gridContent: _gridContent,
      layerLabels: _is3DMode ? _layerLabels : null,
      lockOutMode: _lockOutMode,
      creatorUid: user?.uid ?? 'guest',
      creatorUsername: username,
      createdAt: widget.existingGame?.createdAt ?? DateTime.now(),
      isPublic: widget.existingGame?.isPublic ?? false,
    );

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SquaresPlayScreen(game: game),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Squares Builder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Play Game',
            onPressed: _launchGame,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Game',
            onPressed: _showSaveDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDiceConfig(),
            const SizedBox(height: 24),
            _buildModeToggle(),
            const SizedBox(height: 24),
            if (_is3DMode) ...[
              _buildLayerSelector(),
              const SizedBox(height: 16),
            ],
            _buildGrid(),
            const SizedBox(height: 24),
            _buildPlayModeToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildDiceConfig() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dice Configuration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildDieSelector('X-Axis', _xDieSides, 'X'),
            const SizedBox(height: 12),
            _buildDieSelector('Y-Axis', _yDieSides, 'Y'),
            if (_is3DMode) ...[
              const SizedBox(height: 12),
              _buildDieSelector('Z-Axis (Layers)', _zDieSides!, 'Z'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDieSelector(String label, int currentSides, String axis) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label),
        ),
        Expanded(
          flex: 3,
          child: SegmentedButton<int>(
            segments: _availableSides.map((sides) {
              return ButtonSegment<int>(
                value: sides,
                label: Text('d$sides'),
              );
            }).toList(),
            selected: {currentSides},
            onSelectionChanged: (Set<int> selected) {
              _onDieSidesChanged(axis, selected.first);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _is3DMode ? '3D Mode (Layers)' : '2D Mode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _is3DMode
                        ? 'Grid has layers controlled by Z-die'
                        : 'Simple X,Y grid',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _toggleDimensionMode,
              icon: Icon(_is3DMode ? Icons.layers_clear : Icons.layers),
              label: Text(_is3DMode ? 'Switch to 2D' : 'Add Layers'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayerSelector() {
    return Card(
      color: DarkAcademiaColors.navyBlue.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Current Layer: ',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Expanded(
                  child: DropdownButton<int>(
                    value: _currentLayer,
                    isExpanded: true,
                    items: List.generate(_zDieSides!, (index) {
                      final layer = index + 1;
                      return DropdownMenuItem(
                        value: layer,
                        child: Text('$layer: ${_layerLabels[layer] ?? "Layer $layer"}'),
                      );
                    }),
                    onChanged: (value) {
                      setState(() => _currentLayer = value!);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit layer label',
                  onPressed: () => _editLayerLabel(_currentLayer),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Grid Editor',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${_gridContent.length} filled',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DarkAcademiaColors.antiqueBrass,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tap squares to edit content',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _buildGridDisplay(),
          ],
        ),
      ),
    );
  }

  Widget _buildGridDisplay() {
    return AspectRatio(
      aspectRatio: _xDieSides / _yDieSides,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _xDieSides,
          childAspectRatio: 1,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: _xDieSides * _yDieSides,
        itemBuilder: (context, index) {
          final x = (index % _xDieSides) + 1;
          final y = (index ~/ _xDieSides) + 1;
          final key = _makeKey(x, y, _is3DMode ? _currentLayer : null);
          final isFilled = _gridContent.containsKey(key);
          
          return GestureDetector(
            onTap: () => _editSquare(x, y, _is3DMode ? _currentLayer : null),
            child: Container(
              decoration: BoxDecoration(
                color: isFilled
                    ? DarkAcademiaColors.navyBlue
                    : DarkAcademiaColors.charcoalGray.withValues(alpha: 0.3),
                border: Border.all(
                  color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: isFilled
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: DarkAcademiaColors.antiqueBrass,
                      )
                    : Text(
                        '${x},${y}',
                        style: TextStyle(
                          fontSize: 10,
                          color: DarkAcademiaColors.cream.withValues(alpha: 0.3),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayModeToggle() {
    return Card(
      child: SwitchListTile(
        title: const Text('Lock-Out Mode'),
        subtitle: Text(
          _lockOutMode
              ? 'Completed squares are blocked'
              : 'Free play - can repeat squares',
        ),
        value: _lockOutMode,
        onChanged: (value) {
          setState(() => _lockOutMode = value);
        },
      ),
    );
  }

  void _showSaveDialog() {
    if (_gridContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some content to squares before saving')),
      );
      return;
    }

    final nameController = TextEditingController(text: widget.existingGame?.name ?? '');
    final descController = TextEditingController(text: widget.existingGame?.description ?? '');
    String selectedCategory = widget.existingGame?.category ?? 'Romance';
    String customCategory = '';
    bool isPublic = widget.existingGame?.isPublic ?? false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Save Squares Game'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Game Name',
                    hintText: 'e.g., Romantic Date Night Ideas',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Describe your game...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    ...SquaresCategory.predefined.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }),
                    const DropdownMenuItem(value: 'Custom', child: Text('Custom')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedCategory = value!);
                  },
                ),
                if (selectedCategory == 'Custom') ...[
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => customCategory = value,
                    decoration: const InputDecoration(
                      labelText: 'Custom Category',
                      hintText: 'e.g., Study Skills',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Visibility',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                RadioListTile<bool>(
                  title: const Text('Private'),
                  subtitle: const Text('Only you can see this game'),
                  value: false,
                  groupValue: isPublic,
                  onChanged: (value) {
                    setDialogState(() => isPublic = value!);
                  },
                ),
                RadioListTile<bool>(
                  title: const Text('Public'),
                  subtitle: const Text('Submit for approval by moderators'),
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a game name')),
                  );
                  return;
                }

                final category = selectedCategory == 'Custom' ? customCategory.trim() : selectedCategory;
                if (category.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a custom category name')),
                  );
                  return;
                }

                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please sign in to save games')),
                  );
                  return;
                }

                final username = await UserService.getCurrentUsername() ?? 'Guest';

                final game = SquaresGame(
                  gameId: widget.existingGame?.gameId ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  description: descController.text.trim(),
                  category: category,
                  xDieSides: _xDieSides,
                  yDieSides: _yDieSides,
                  zDieSides: _zDieSides,
                  gridContent: _gridContent,
                  layerLabels: _is3DMode ? _layerLabels : null,
                  lockOutMode: _lockOutMode,
                  creatorUid: user.uid,
                  creatorUsername: username,
                  createdAt: widget.existingGame?.createdAt ?? DateTime.now(),
                  isPublic: isPublic,
                );

                Navigator.pop(dialogContext);

                try {
                  await SquaresService.saveGame(game);
                  
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isPublic
                            ? 'Game submitted for approval!'
                            : 'Game saved privately!',
                      ),
                      action: SnackBarAction(
                        label: 'Play',
                        onPressed: () => _launchGame(),
                      ),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving game: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
