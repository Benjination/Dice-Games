import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await _initializeFirebase();
  runApp(DiceGamesApp(firebaseReady: firebaseReady));
}

Future<bool> _initializeFirebase() async {
  try {
    if (kIsWeb) {
      final app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseAnalytics.instanceFor(app: app).logAppOpen();
      return true;
    }
    return false;
  } catch (_) {
    return false;
  }
}

class DiceGamesApp extends StatelessWidget {
  const DiceGamesApp({super.key, this.firebaseReady = false});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DiceGames',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF116466)),
        useMaterial3: true,
      ),
      home: HomePage(firebaseReady: firebaseReady),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _diceCount = 2;
  List<int> _lastRoll = const [1, 1];
  int _lastSeed = 0;

  void _rollDice() {
    final now = DateTime.now();
    final entropy = Object.hashAll([
      now.microsecondsSinceEpoch,
      now.millisecondsSinceEpoch,
      _diceCount,
      _lastSeed,
    ]);

    final random = Random(entropy);
    final roll = List<int>.generate(_diceCount, (_) => random.nextInt(6) + 1);

    setState(() {
      _lastSeed = entropy;
      _lastRoll = roll;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _lastRoll.fold<int>(0, (sum, value) => sum + value);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('DiceGames Universal'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.firebaseReady) ...[
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Firebase is configured for web. Native targets will be enabled after running flutterfire configure.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    'Roll dice in guest mode now. Sign in later to save and build custom games.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dice count: $_diceCount'),
                          Slider(
                            min: 1,
                            max: 20,
                            divisions: 19,
                            value: _diceCount.toDouble(),
                            onChanged: (value) {
                              setState(() {
                                _diceCount = value.toInt();
                                _lastRoll = List<int>.filled(_diceCount, 1);
                              });
                            },
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _lastRoll
                                .map(
                                  (value) => Chip(
                                    label: Text('d6: $value'),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          Text('Total: $total'),
                          Text('Seed snapshot: $_lastSeed'),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _rollDice,
                            child: const Text('Roll Dice'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.casino),
                        label: const Text('Play Built-in Games (Guest)'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () {},
                        icon: const Icon(Icons.person),
                        label: const Text('Sign In to Save Games'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
