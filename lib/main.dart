import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'theme/dark_academia_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/username_welcome_dialog.dart';
import 'screens/landing_page.dart';
import 'services/user_service.dart';

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
      theme: DarkAcademiaTheme.buildTheme(),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    try {
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor:
                  DarkAcademiaTheme.buildTheme().scaffoldBackgroundColor,
              body: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            // User is logged in - ensure user document exists in Firestore
            return FutureBuilder<void>(
              future: UserService.ensureUserDocument(snapshot.data!),
              builder: (context, futureSnapshot) {
                if (futureSnapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    backgroundColor:
                        DarkAcademiaTheme.buildTheme().scaffoldBackgroundColor,
                    body: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                // Show username welcome dialog if needed, then game list
                return const UsernameChecker();
              },
            );
          }

          return const LandingPage();
        },
      );
    } catch (_) {
      return const LandingPage();
    }
  }
}

/// Widget that checks if user needs to confirm their username
/// Shows welcome dialog for new users with unlocked usernames
class UsernameChecker extends StatefulWidget {
  const UsernameChecker({super.key});

  @override
  State<UsernameChecker> createState() => _UsernameCheckerState();
}

class _UsernameCheckerState extends State<UsernameChecker> {
  bool _hasCheckedUsername = false;

  @override
  void initState() {
    super.initState();
    _checkUsernameStatus();
  }

  Future<void> _checkUsernameStatus() async {
    if (_hasCheckedUsername) return;

    try {
      final isLocked = await UserService.isUsernameLocked();
      final username = await UserService.getCurrentUsername();

      if (!isLocked && username != null && mounted) {
        // Show welcome dialog to let user confirm or regenerate
        await showDialog(
          context: context,
          barrierDismissible: false, // Must confirm username
          builder: (context) => UsernameWelcomeDialog(
            initialUsername: username,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _hasCheckedUsername = true;
        });
      }
    } catch (e) {
      // If error, continue to app
      if (mounted) {
        setState(() {
          _hasCheckedUsername = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasCheckedUsername) {
      return Scaffold(
        backgroundColor: DarkAcademiaTheme.buildTheme().scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return const GameListScreen(guest: false);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.firebaseReady,
    this.user,
  });

  final bool firebaseReady;
  final User? user;

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
    final isSignedIn = widget.user != null;

    Future<void> openLoginScreen() async {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('DiceGames'),
        actions: [
          if (isSignedIn)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: GestureDetector(
                  onTap: () async {
                    final shouldSignOut = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Sign Out'),
                        content: const Text(
                          'Are you sure you want to sign out?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );
                    if (shouldSignOut == true) {
                      await FirebaseAuth.instance.signOut();
                    }
                  },
                  child: const Chip(
                    label: Text('Sign Out'),
                  ),
                ),
              ),
            ),
        ],
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
                      if (!isSignedIn)
                        FilledButton.tonalIcon(
                          onPressed: openLoginScreen,
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
