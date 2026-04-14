import 'dart:math';
import 'package:flutter/material.dart';
import '../../../models/squares_game.dart';
import '../../../theme/dark_academia_theme.dart';

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
  
  int _currentLayer = 1; // For 3D mode viewing

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
  
  String? get _currentCoordinateKey {
    if (_rolledX == null || _rolledY == null) return null;
    if (_is3DMode && _rolledZ == null) return null;
    return _makeKey(_rolledX!, _rolledY!, _rolledZ);
  }

  bool get _canRollCurrentSquare {
    if (_currentCoordinateKey == null) return true; // No roll yet
    if (!_game.lockOutMode) return true; // Free play mode
    return !_game.isSquareCompleted(_rolledX!, _rolledY!, _rolledZ); // Lock-out mode
  }

  void _rollDice() async {
    if (_isRolling) return;
    
    setState(() => _isRolling = true);
    _diceAnimationController.reset();
    _diceAnimationController.forward();
    
    // Animate dice rolling
    for (int i = 0; i < 15; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) {
        setState(() {
          _rolledX = _random.nextInt(_game.xDieSides) + 1;
          _rolledY = _random.nextInt(_game.yDieSides) + 1;
          if (_is3DMode) {
            _rolledZ = _random.nextInt(_game.zDieSides!) + 1;
            _currentLayer = _rolledZ!; // Auto-switch to rolled layer
          }
        });
      }
    }
    
    setState(() => _isRolling = false);
    
    // Show popup if square has content
    if (_currentCoordinateKey != null && _game.isSquareFilled(_rolledX!, _rolledY!, _rolledZ)) {
      _showSquarePopup();
    }
  }

  void _showSquarePopup() {
    final content = _game.getSquareContent(_rolledX!, _rolledY!, _rolledZ);
    if (content == null) return;
    
    final isCompleted = _game.isSquareCompleted(_rolledX!, _rolledY!, _rolledZ);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _is3DMode
              ? 'Square ($_rolledX, $_rolledY, $_rolledZ)'
              : 'Square ($_rolledX, $_rolledY)',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_is3DMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _game.layerLabels?[_rolledZ!] ?? 'Layer $_rolledZ',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: DarkAcademiaColors.antiqueBrass,
                  ),
                ),
              ),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 16),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!isCompleted)
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

  void _markComplete() {
    if (_currentCoordinateKey == null) return;
    
    setState(() {
      _game = _game.copyWith(
        completedSquares: {..._game.completedSquares, _currentCoordinateKey!},
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_game.name),
        actions: [
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
            if (_is3DMode) ...[
              _buildLayerSelector(),
              const SizedBox(height: 16),
            ],
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
            if (_currentCoordinateKey != null && _game.lockOutMode && !_canRollCurrentSquare)
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

  Widget _buildLayerSelector() {
    return Card(
      color: DarkAcademiaColors.navyBlue.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(
              'Viewing Layer: ',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Expanded(
              child: DropdownButton<int>(
                value: _currentLayer,
                isExpanded: true,
                items: List.generate(_game.zDieSides!, (index) {
                  final layer = index + 1;
                  return DropdownMenuItem(
                    value: layer,
                    child: Text('$layer: ${_game.layerLabels?[layer] ?? "Layer $layer"}'),
                  );
                }),
                onChanged: (value) {
                  setState(() => _currentLayer = value!);
                },
              ),
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
              final z = _is3DMode ? _currentLayer : null;
              
              final isFilled = _game.isSquareFilled(x, y, z);
              final isCompleted = _game.isSquareCompleted(x, y, z);
              final isCurrentRoll = (_rolledX == x && _rolledY == y && (_rolledZ == z || !_is3DMode));
              
              return GestureDetector(
                onTap: isFilled ? () {
                  // Show square content when tapped
                  final content = _game.getSquareContent(x, y, z);
                  if (content != null) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(_is3DMode ? 'Square ($x, $y, $z)' : 'Square ($x, $y)'),
                        content: Text(content),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  }
                } : null,
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
