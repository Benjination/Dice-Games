import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/squares_game.dart';
import '../../../theme/dark_academia_theme.dart';
import '../../../services/squares_service.dart';
import '../../auth/login_screen.dart';

/// Play screen for Squares grid game - roll dice and mark squares complete
class SquaresPlayScreen extends StatefulWidget {
  final SquaresGame game;

  const SquaresPlayScreen({super.key, required this.game});

  @override
  State<SquaresPlayScreen> createState() => _SquaresPlayScreenState();
}

class _SquaresPlayScreenState extends State<SquaresPlayScreen>
    with SingleTickerProviderStateMixin {
  late SquaresGame _game;
  
  int? _rolledX;
  int? _rolledY;
  int? _rolledZ;
  
  bool _isRolling = false;
  late AnimationController _diceAnimationController;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _game = widget.game;
    _diceAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _diceAnimationController.dispose();
    super.dispose();
  }

  bool get _is3DMode => _game.is3DMode;
  
  String _makeKey(int x, int y, [int? z]) {
    if (z != null) return '$x,$y,$z';
    return '$x,$y';
  }

  bool get _canRollCurrentSquare {
    if (_rolledX == null || _rolledY == null) return true; // No roll yet
    if (!_game.lockOutMode) return true; // Free play mode
    
    // In lock-out mode, check if this x,y position is completed (all layers)
    if (_is3DMode && _game.zDieSides != null) {
      // Check if all z-layers for this x,y are completed
      return !List.generate(_game.zDieSides!, (i) => i + 1)
          .every((z) => _game.isSquareCompleted(_rolledX!, _rolledY!, z));
    } else {
      return !_game.isSquareCompleted(_rolledX!, _rolledY!);
    }
  }

  void _rollDice() async {
    if (_isRolling) return;
    
    // In lock-out mode, find available (non-completed) squares
    List<Map<String, int>>? availableSquares;
    if (_game.lockOutMode) {
      availableSquares = [];
      for (int x = 1; x <= _game.xDieSides; x++) {
        for (int y = 1; y <= _game.yDieSides; y++) {
          // Check if this x,y position is completed (all layers if 3D)
          bool isCompleted = false;
          if (_is3DMode && _game.zDieSides != null) {
            isCompleted = List.generate(_game.zDieSides!, (i) => i + 1)
                .every((z) => _game.isSquareCompleted(x, y, z));
          } else {
            isCompleted = _game.isSquareCompleted(x, y);
          }
          
          if (!isCompleted) {
            availableSquares.add({'x': x, 'y': y});
          }
        }
      }
      
      // If no available squares, don't roll
      if (availableSquares.isEmpty) {
        setState(() => _isRolling = false);
        return;
      }
    }
    
    setState(() => _isRolling = true);
    _diceAnimationController.reset();
    _diceAnimationController.forward();
    
    // Animate dice rolling
    for (int i = 0; i < 15; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) {
        setState(() {
          if (_game.lockOutMode && availableSquares != null && availableSquares.isNotEmpty) {
            // Pick from available squares only
            final square = availableSquares[_random.nextInt(availableSquares.length)];
            _rolledX = square['x']!;
            _rolledY = square['y']!;
          } else {
            // Free play - any square
            _rolledX = _random.nextInt(_game.xDieSides) + 1;
            _rolledY = _random.nextInt(_game.yDieSides) + 1;
          }
          if (_is3DMode) {
            _rolledZ = _random.nextInt(_game.zDieSides!) + 1;
          }
        });
      }
    }
    
    setState(() => _isRolling = false);
    
    // Always show popup when a square is rolled
    if (_rolledX != null && _rolledY != null) {
      _showSquareEditDialog(_rolledX!, _rolledY!);
    }
  }

  void _markComplete() {
    if (_rolledX == null || _rolledY == null) return;
    
    setState(() {
      final newCompleted = {..._game.completedSquares};
      
      // Mark all layers complete for this x,y position
      if (_is3DMode && _game.zDieSides != null) {
        // Add all z-layers for this x,y
        for (int z = 1; z <= _game.zDieSides!; z++) {
          newCompleted.add(_makeKey(_rolledX!, _rolledY!, z));
        }
      } else {
        // 2D mode - just add x,y
        newCompleted.add(_makeKey(_rolledX!, _rolledY!));
      }
      
      _game = _game.copyWith(completedSquares: newCompleted);
    });
    
    // Check if all filled squares are completed
    if (_game.completedCount == _game.filledSquares) {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.celebration,
              color: DarkAcademiaColors.antiqueBrass,
            ),
            const SizedBox(width: 12),
            const Text('Game Complete!'),
          ],
        ),
        content: Text(
          'You completed all ${_game.filledSquares} squares!',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit game
            },
            child: const Text('Exit'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _game = _game.copyWith(completedSquares: {});
                _rolledX = null;
                _rolledY = null;
                _rolledZ = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  // Authentication helper
  Future<bool> _checkAuthenticationAndProceed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Login Required'),
          content: const Text('You need to be logged in to save or publish games.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Login'),
            ),
          ],
        ),
      );
      
      if (shouldLogin == true && mounted) {
        final loggedIn = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return loggedIn == true;
      }
      return false;
    }
    return true;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Save game dialog
  Future<void> _showSaveDialog() async {
    final isAuthenticated = await _checkAuthenticationAndProceed();
    if (!isAuthenticated || !mounted) return;

    final nameController = TextEditingController(text: _game.name);
    
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

  // Publish game dialog
  Future<void> _showPublishDialog() async {
    final isAuthenticated = await _checkAuthenticationAndProceed();
    if (!isAuthenticated || !mounted) return;

    final nameController = TextEditingController(text: _game.name);
    
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

  // Save game privately
  Future<void> _saveGame(String name) async {
    if (name.isEmpty) {
      _showSnackBar('Please enter a game name');
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final updatedGame = _game.copyWith(
        name: name,
        creatorUid: user.uid,
        creatorUsername: user.displayName ?? 'Unknown',
      );
      await SquaresService.saveGame(updatedGame);

      if (mounted) {
        setState(() {
          _game = updatedGame;
        });
        _showSnackBar('Game saved successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error saving game: $e');
      }
    }
  }

  // Publish game for moderation
  Future<void> _publishGame(String name) async {
    if (name.isEmpty) {
      _showSnackBar('Please enter a game name');
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final updatedGame = _game.copyWith(
        name: name,
        isPublic: true,
        creatorUid: user.uid,
        creatorUsername: user.displayName ?? 'Unknown',
      );
      await SquaresService.saveGame(updatedGame);

      if (mounted) {
        setState(() {
          _game = updatedGame;
        });
        _showSnackBar('Game submitted for moderation!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error publishing game: $e');
      }
    }
  }

  // Game settings dialog
  Future<void> _showGameSettings() async {
    final xController = TextEditingController(text: _game.xDieSides.toString());
    final yController = TextEditingController(text: _game.yDieSides.toString());
    final zController = TextEditingController(text: (_game.zDieSides ?? 6).toString());
    bool is3D = _game.is3DMode;
    bool lockOut = _game.lockOutMode;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Game Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: xController,
                  decoration: const InputDecoration(
                    labelText: 'X Die Sides',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yController,
                  decoration: const InputDecoration(
                    labelText: 'Y Die Sides',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('3D Mode'),
                  subtitle: const Text('Add a third dimension (Z)'),
                  value: is3D,
                  onChanged: (value) {
                    setDialogState(() => is3D = value);
                  },
                ),
                if (is3D) ...[
                  TextField(
                    controller: zController,
                    decoration: const InputDecoration(
                      labelText: 'Z Die Sides',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                ],
                SwitchListTile(
                  title: const Text('Lock-Out Mode'),
                  subtitle: const Text('Completed squares cannot be rolled again'),
                  value: lockOut,
                  onChanged: (value) {
                    setDialogState(() => lockOut = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, {
                  'xDieSides': int.tryParse(xController.text) ?? 6,
                  'yDieSides': int.tryParse(yController.text) ?? 6,
                  'is3DMode': is3D,
                  'zDieSides': is3D ? (int.tryParse(zController.text) ?? 6) : null,
                  'lockOutMode': lockOut,
                });
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _game = _game.copyWith(
          xDieSides: result['xDieSides'],
          yDieSides: result['yDieSides'],
          zDieSides: result['zDieSides'],
          lockOutMode: result['lockOutMode'],
        );
      });
    }
  }

  // Show square edit dialog (triggered by clicking grid or dice rolling)
  Future<void> _showSquareEditDialog(int x, int y) async {
    final baseContent = _game.getSquareContent(x, y) ?? '';
    final contentController = TextEditingController(text: baseContent);
    
    // Get layer label if in 3D mode and we have a current Z roll
    String? layerLabel;
    String displayContent = baseContent;
    if (_is3DMode && _rolledZ != null) {
      layerLabel = _game.getLayerLabel(_rolledZ!);
      if (baseContent.isNotEmpty) {
        displayContent = layerLabel != null ? '$baseContent $layerLabel' : baseContent;
      } else if (layerLabel != null) {
        displayContent = layerLabel;
      }
    }
    
    // Check if completed
    bool isCompleted = false;
    if (_is3DMode && _game.zDieSides != null) {
      isCompleted = List.generate(_game.zDieSides!, (i) => i + 1)
          .every((z) => _game.isSquareCompleted(x, y, z));
    } else {
      isCompleted = _game.isSquareCompleted(x, y);
    }
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _is3DMode
              ? 'Square ($x, $y${_rolledZ != null ? ', $_rolledZ' : ''})'
              : 'Square ($x, $y)',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (baseContent.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Rule not set',
                    style: TextStyle(
                      color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              if (baseContent.isNotEmpty || (_is3DMode && layerLabel != null))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    displayContent,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              if (isCompleted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: DarkAcademiaColors.antiqueBrass,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text('Already completed'),
                    ],
                  ),
                ),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Edit Rule:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  hintText: 'Enter rule for this square',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 200,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              final newContent = contentController.text.trim();
              setState(() {
                final newGridContent = Map<String, String>.from(_game.gridContent);
                final key = '$x,$y';
                if (newContent.isEmpty) {
                  newGridContent.remove(key);
                } else {
                  newGridContent[key] = newContent;
                }
                _game = _game.copyWith(gridContent: newGridContent);
              });
              Navigator.pop(context);
            },
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
          if (!isCompleted && (_rolledX == x && _rolledY == y))
            FilledButton.icon(
              onPressed: () {
                _markComplete();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.check),
              label: const Text('Mark Complete'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_game.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Game Settings',
            onPressed: _showGameSettings,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Game',
            onPressed: _showSaveDialog,
          ),
          IconButton(
            icon: const Icon(Icons.publish),
            tooltip: 'Publish Game',
            onPressed: _showPublishDialog,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Game Info',
            onPressed: _showGameInfo,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGameStats(),
            const SizedBox(height: 24),
            _buildDiceDisplay(),
            const SizedBox(height: 24),
            _buildGrid(),
            const SizedBox(height: 24),
            _buildRollButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildGameStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Completed', '${_game.completedCount}/${_game.filledSquares}'),
                _buildStatItem('Grid', 
                  _is3DMode 
                    ? '${_game.xDieSides}×${_game.yDieSides}×${_game.zDieSides}'
                    : '${_game.xDieSides}×${_game.yDieSides}'),
                _buildStatItem('Mode', _game.lockOutMode ? 'Lock-Out' : 'Free Play'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: DarkAcademiaColors.antiqueBrass,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildDiceDisplay() {
    return Card(
      color: DarkAcademiaColors.navyBlue.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              _rolledX == null ? 'Roll the dice!' : 'Current Roll',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDie('X', _rolledX, _game.xDieSides),
                _buildDie('Y', _rolledY, _game.yDieSides),
                if (_is3DMode) _buildDie('Z', _rolledZ, _game.zDieSides!),
              ],
            ),
            if (_rolledX != null && _rolledY != null && _game.lockOutMode && !_canRollCurrentSquare)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock,
                      size: 16,
                      color: DarkAcademiaColors.antiqueBrass,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'This square is completed (locked out)',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDie(String label, int? value, int sides) {
    return AnimatedBuilder(
      animation: _diceAnimationController,
      builder: (context, child) {
        final angle = _isRolling ? _diceAnimationController.value * 4 * pi : 0.0;
        return Transform.rotate(
          angle: angle,
          child: child,
        );
      },
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.2),
              border: Border.all(
                color: DarkAcademiaColors.antiqueBrass,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                value?.toString() ?? '?',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: DarkAcademiaColors.antiqueBrass,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$label (d$sides)',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
            child: AspectRatio(
              aspectRatio: _game.xDieSides / _game.yDieSides,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _game.xDieSides,
                  childAspectRatio: 1,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: _game.xDieSides * _game.yDieSides,
                itemBuilder: (context, index) {
              final x = (index % _game.xDieSides) + 1;
              final y = (index ~/ _game.xDieSides) + 1;
              
              // Content is always at x,y (layers are modifiers)
              final isFilled = _game.isSquareFilled(x, y);
              // Check if ALL layers are completed for this x,y
              bool isCompleted = false;
              if (_is3DMode && _game.zDieSides != null) {
                // Check if all z-layers for this x,y are completed
                isCompleted = List.generate(_game.zDieSides!, (i) => i + 1)
                    .every((z) => _game.isSquareCompleted(x, y, z));
              } else {
                isCompleted = _game.isSquareCompleted(x, y);
              }
              // Flash animation on rolled x,y position (regardless of z)
              final isCurrentRoll = (_rolledX == x && _rolledY == y);
              
              return GestureDetector(
                onTap: () => _showSquareEditDialog(x, y),
                child: Container(
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.5)
                        : isFilled
                            ? DarkAcademiaColors.navyBlue
                            : DarkAcademiaColors.charcoalGray.withValues(alpha: 0.3),
                    border: Border.all(
                      color: isCurrentRoll
                          ? DarkAcademiaColors.antiqueBrass
                          : DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.3),
                      width: isCurrentRoll ? 3 : 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    children: [
                      if (isCompleted)
                        Center(
                          child: Icon(
                            Icons.close,
                            color: DarkAcademiaColors.navyBlue,
                            size: 20,
                          ),
                        ),
                      if (isFilled && !isCompleted)
                        Center(
                          child: Icon(
                            Icons.circle,
                            size: 8,
                            color: DarkAcademiaColors.antiqueBrass.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildRollButton() {
    return FilledButton.icon(
      onPressed: _isRolling ? null : _rollDice,
      icon: _isRolling
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.casino),
      label: Text(_isRolling ? 'Rolling...' : 'Roll Dice'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showGameInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_game.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_game.description.isNotEmpty) ...[
                Text(_game.description),
                const SizedBox(height: 16),
              ],
              _buildInfoRow('Category', _game.category),
              _buildInfoRow('Creator', _game.creatorUsername),
              _buildInfoRow('Grid Size',
                _is3DMode 
                  ? '${_game.xDieSides}×${_game.yDieSides}×${_game.zDieSides}'
                  : '${_game.xDieSides}×${_game.yDieSides}'),
              _buildInfoRow('Total Squares', '${_game.totalSquares}'),
              _buildInfoRow('Filled Squares', '${_game.filledSquares}'),
              _buildInfoRow('Play Mode', _game.lockOutMode ? 'Lock-Out' : 'Free Play'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
