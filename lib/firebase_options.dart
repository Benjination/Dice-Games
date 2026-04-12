import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Firebase options are not configured for this platform yet. '
          'Run `flutterfire configure` after setting up your Firebase project.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError('Firebase options are not supported for fuchsia.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCNV6hfumW5u8ALY4yBXI4L32GngXWH2Jo',
    appId: '1:952432097302:web:bd252c374c60ca5e0e5d37',
    messagingSenderId: '952432097302',
    projectId: 'dice-games-6a9ab',
    authDomain: 'dice-games-6a9ab.firebaseapp.com',
    storageBucket: 'dice-games-6a9ab.firebasestorage.app',
    measurementId: 'G-N37QLR8XW6',
  );
}
