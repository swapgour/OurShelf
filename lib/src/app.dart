import 'package:flutter/material.dart';

import 'features/splash/splash_screen.dart';

/// Lets non-widget code (the foreground push-notification handler) show a
/// SnackBar without needing a BuildContext of its own.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Royal palette: deep amethyst/indigo primary with a metallic-gold accent —
/// a jewel-box, premium feel instead of the old flat "fresh grocery" green.
/// Exact hex values pinned to the product's design spec so every screen
/// draws from the same named tokens instead of ad-hoc colors.
const ourShelfSeed = Color(0xFF54277D); // Primary
const ourShelfDark = Color(0xFF351653); // Dark Purple
const ourShelfSecondary = Color(0xFF8052A5); // Secondary Purple
const ourShelfAccent = Color(0xFFE9B52E); // Gold Accent
const ourShelfTertiary = Color(0xFF8052A5);
const ourShelfBackground = Color(0xFFF8F6FA);
const ourShelfTextPrimary = Color(0xFF252033);
const ourShelfTextSecondary = Color(0xFF777182);
const ourShelfSuccess = Color(0xFF299B69);
const ourShelfWarning = Color(0xFFE7A32B);
const ourShelfError = Color(0xFFD84C55);
const ourShelfBorder = Color(0xFFEDE8F1);

/// Shared royal gradient (dark purple -> primary -> gold) used by the
/// splash, sign-in and header surfaces so the whole app hands off smoothly
/// between screens instead of jumping between unrelated colors.
const royalGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [ourShelfDark, ourShelfSeed, ourShelfAccent],
);

const royalHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [ourShelfDark, ourShelfSeed],
);

class OurShelfApp extends StatelessWidget {
  const OurShelfApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: ourShelfSeed,
      brightness: Brightness.light,
    ).copyWith(
      primary: ourShelfSeed,
      secondary: ourShelfAccent,
      tertiary: ourShelfTertiary,
      error: ourShelfError,
      surface: Colors.white,
      onSurface: ourShelfTextPrimary,
      outline: ourShelfBorder,
    );

    return MaterialApp(
      title: 'OurShelf',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: ourShelfBackground,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: colorScheme.secondary,
          foregroundColor: const Color(0xFF2B0A4E),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        chipTheme: ChipThemeData(
          selectedColor: colorScheme.secondaryContainer,
          backgroundColor: colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(color: colorScheme.onSurface),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.secondary,
            foregroundColor: const Color(0xFF2B0A4E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: colorScheme.primary,
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
