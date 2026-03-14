import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';  // needed for SystemChrome (edge-to-edge)
import 'screens/home_screen.dart';

// ── Optional Firebase ──────────────────────────────────────────────────────────
// To enable Firebase:
//   1. Run: flutterfire configure
//   2. Uncomment the imports and init code below
//   3. Uncomment firebase_core / cloud_firestore in pubspec.yaml
//   4. Run with: flutter run --dart-define-from-file=firebase.env.json
//
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Edge-to-edge rendering (iOS & Android) ──────────────────────────────────
  // Extends Flutter content behind the status bar and nav bar so the UI fills
  // the full screen. Pair with MediaQuery.of(context).padding in your widgets
  // to avoid drawing interactive content behind system chrome.
  //
  // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
  //   statusBarColor: Colors.transparent,
  //   statusBarIconBrightness: Brightness.light,
  //   systemNavigationBarColor: Colors.transparent,
  //   systemNavigationBarIconBrightness: Brightness.light,
  //   systemNavigationBarDividerColor: Colors.transparent,
  // ));
  // ─────────────────────────────────────────────────────────────────────────────

  // ── Firebase init (uncomment when Firebase is enabled) ──────────────────────
  // assert(
  //   const String.fromEnvironment('FIREBASE_IOS_API_KEY').isNotEmpty,
  //   'FIREBASE_IOS_API_KEY is not set. Run with --dart-define-from-file=firebase.env.json',
  // );
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // ─────────────────────────────────────────────────────────────────────────────

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'teamPeriod',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
