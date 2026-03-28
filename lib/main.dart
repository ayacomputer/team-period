import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge rendering — content fills behind system bars.
  // Use MediaQuery.of(context).padding in widgets to avoid system chrome overlap.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  assert(
    const String.fromEnvironment('FIREBASE_IOS_API_KEY').isNotEmpty ||
        const String.fromEnvironment('FIREBASE_ANDROID_API_KEY').isNotEmpty,
    'Firebase API key not set. Run with --dart-define-from-file=firebase.env.json',
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'teamPeriod',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const MainShell(),
      // Locale support — English and Japanese.
      localizationsDelegates: const [
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Locale is driven by CycleSettings.languageCode; the MainShell passes it
      // down by wrapping children in a Localizations.override widget.
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE11D48), // rose
        brightness: Brightness.light,
      ),
      fontFamily: 'SF Pro Text', // falls back to system font on Android
      scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF9FAFB),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
        iconTheme: IconThemeData(color: Color(0xFF374151)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFE11D48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: Color(0xFFE11D48),
        thumbColor: Color(0xFFE11D48),
        overlayColor: Color(0x1FE11D48),
        inactiveTrackColor: Color(0xFFFFD1D7),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? const Color(0xFFE11D48)
              : null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? const Color(0xFFFFD1D7)
              : null;
        }),
      ),
    );
  }
}
