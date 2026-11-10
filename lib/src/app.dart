import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/splash/splash_screen.dart';
import 'theme/theme_controller.dart';
import 'updates/app_update_service.dart';

/// Lets non-widget code (the foreground push-notification handler) show a
/// SnackBar without needing a BuildContext of its own.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Royal palette: deep amethyst/indigo primary with a metallic-gold accent —
/// a jewel-box, premium feel. Each token has a light and dark value; the
/// `ourShelfX` getters below resolve to whichever is currently active, so
/// every screen that already references them (as a plain value, not a
/// function call — Dart getters support that) gets dark mode for free.
const _lightSeed = Color(0xFF54277D);
const _lightDark = Color(0xFF351653);
const _lightSecondary = Color(0xFF8052A5);
const _lightAccent = Color(0xFFE9B52E);
const _lightBackground = Color(0xFFF8F6FA);
const _lightTextPrimary = Color(0xFF252033);
const _lightTextSecondary = Color(0xFF777182);
const _lightSuccess = Color(0xFF299B69);
const _lightWarning = Color(0xFFE7A32B);
const _lightError = Color(0xFFD84C55);
const _lightBorder = Color(0xFFEDE8F1);
const _lightCard = Colors.white;

const _darkSeed = Color(0xFF9B7BC7);
const _darkDark = Color(0xFF1A0F2E);
const _darkSecondary = Color(0xFFAD8ED6);
const _darkAccent = Color(0xFFF0C14B);
const _darkBackground = Color(0xFF121018);
const _darkTextPrimary = Color(0xFFF2EFF7);
const _darkTextSecondary = Color(0xFFB3AABF);
const _darkSuccess = Color(0xFF4CC38A);
const _darkWarning = Color(0xFFF0B84B);
const _darkError = Color(0xFFF0828C);
const _darkBorder = Color(0xFF332945);
const _darkCard = Color(0xFF1E1830);

/// Whether the app is *currently* rendering in dark mode. Set synchronously
/// at the top of [OurShelfApp]'s build (before any descendant builds in the
/// same frame), so by the time any widget reads an `ourShelfX` getter it
/// already reflects this frame's resolved brightness.
bool _isDark = false;

Color get ourShelfSeed => _isDark ? _darkSeed : _lightSeed;
Color get ourShelfDark => _isDark ? _darkDark : _lightDark;
Color get ourShelfSecondary => _isDark ? _darkSecondary : _lightSecondary;
Color get ourShelfAccent => _isDark ? _darkAccent : _lightAccent;
Color get ourShelfTertiary => ourShelfSecondary;
Color get ourShelfBackground => _isDark ? _darkBackground : _lightBackground;
Color get ourShelfTextPrimary => _isDark ? _darkTextPrimary : _lightTextPrimary;
Color get ourShelfTextSecondary => _isDark ? _darkTextSecondary : _lightTextSecondary;
Color get ourShelfSuccess => _isDark ? _darkSuccess : _lightSuccess;
Color get ourShelfWarning => _isDark ? _darkWarning : _lightWarning;
Color get ourShelfError => _isDark ? _darkError : _lightError;
Color get ourShelfBorder => _isDark ? _darkBorder : _lightBorder;
/// White card/surface background in light mode, a dark plum panel in dark
/// mode — use this instead of a literal `Colors.white` for any card-style
/// container so it doesn't stay glaring white on a dark background.
Color get ourShelfCard => _isDark ? _darkCard : _lightCard;

/// Shared royal gradient (dark purple -> primary -> gold) used by the
/// splash, sign-in and header surfaces so the whole app hands off smoothly
/// between screens instead of jumping between unrelated colors.
LinearGradient get royalGradient => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [ourShelfDark, ourShelfSeed, ourShelfAccent],
);

LinearGradient get royalHeaderGradient => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [ourShelfDark, ourShelfSeed],
);

/// Builds the ThemeData for [brightness], using that brightness's own
/// palette — NOT whatever `_isDark` happens to be set to right now. (The
/// `ourShelfX` getters below read the mutable `_isDark` global, so this
/// temporarily pins it to match [brightness] while building, then restores
/// it — see the caller in [_OurShelfAppState.build] for why that matters.)
ThemeData _buildTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: ourShelfSeed,
    brightness: brightness,
  ).copyWith(
    primary: ourShelfSeed,
    secondary: ourShelfAccent,
    tertiary: ourShelfTertiary,
    error: ourShelfError,
    surface: ourShelfCard,
    onSurface: ourShelfTextPrimary,
    outline: ourShelfBorder,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    brightness: brightness,
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
      color: ourShelfCard,
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
  );
}

class OurShelfApp extends ConsumerStatefulWidget {
  const OurShelfApp({super.key});

  @override
  ConsumerState<OurShelfApp> createState() => _OurShelfAppState();
}

class _OurShelfAppState extends ConsumerState<OurShelfApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(const AppUpdateService().checkForUpdate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Lets the app react immediately when the user flips their OS-level
  // light/dark switch while themeMode is "System", instead of waiting for
  // some unrelated rebuild.
  @override
  void didChangePlatformBrightness() {
    if (ref.read(themeModeProvider) == ThemeMode.system) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final platformBrightness =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    final resolved = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platformBrightness,
    };

    // Build each ThemeData with _isDark pinned to its own brightness, not
    // whatever's currently active — otherwise both would end up using the
    // same palette (see _buildTheme's doc comment).
    _isDark = false;
    final lightTheme = _buildTheme(Brightness.light);
    _isDark = true;
    final darkTheme = _buildTheme(Brightness.dark);

    // Only *after* both are built do we pin _isDark to the brightness
    // that's actually active — this is what every screen's `ourShelfX`
    // getters will see for the rest of this frame.
    _isDark = resolved == Brightness.dark;

    return MaterialApp(
      title: 'OurShelf',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      themeMode: mode,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: const SplashScreen(),
    );
  }
}
