import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/splash/splash_screen.dart';

/// Lets non-widget code (the foreground push-notification handler) show a
/// SnackBar without needing a BuildContext of its own.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Royal design-system palette (v2): Royal Aubergine + Deep Plum + Champagne
/// Gold on a Warm Ivory canvas — a quieter, more premium register than the
/// brighter purple/gold v1 palette. Every screen draws from these same
/// named tokens (not ad-hoc colors), so retuning the palette here is a
/// one-file, whole-app change.
const ourShelfSeed = Color(0xFF321342); // Primary — Royal Aubergine
const ourShelfDark = Color(0xFF210B2C); // Deeper aubergine, for gradients
const ourShelfSecondary = Color(0xFF4B1D68); // Secondary — Deep Plum
const ourShelfAccent = Color(0xFFD6AD62); // Accent — Champagne Gold
const ourShelfTertiary = Color(0xFF4B1D68);
const ourShelfLightAccent = Color(0xFFEAE2ED); // Soft Lavender
const ourShelfBackground = Color(0xFFFAF7F2); // Warm Ivory
const ourShelfCardBackground = Color(0xFFFFFFFF);
const ourShelfTextPrimary = Color(0xFF25212A); // Charcoal
const ourShelfTextSecondary = Color(0xFF827B87); // Muted Grey
const ourShelfSuccess = Color(0xFF218765); // Elegant Green
const ourShelfWarning = Color(0xFFD99B36); // Warm Amber
const ourShelfError = Color(0xFFC94C58); // Muted Red
const ourShelfBorder = Color(0xFFEAE4EA); // Soft Beige

/// 4/8/12/16/20/24/32 spacing scale — reach for these instead of ad-hoc
/// EdgeInsets values so rhythm stays consistent screen to screen.
class OurShelfSpacing {
  const OurShelfSpacing._();
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const pageHorizontal = 20.0;
  static const cardPadding = 18.0;
  static const cardRadius = 20.0;
  static const inputRadius = 15.0;
  static const primaryButtonHeight = 56.0;
  static const iconButtonSize = 46.0;
}

/// Used sparingly — a subtle aubergine-to-plum gradient for the hero banner
/// and a couple of other premium, high-emphasis surfaces (per the design
/// spec's "avoid excessive gradients" rule).
const royalGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [ourShelfDark, ourShelfSeed, ourShelfSecondary],
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

    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: Brightness.light).textTheme,
    );
    final textTheme = baseTextTheme.copyWith(
      // Main page title — 26/700.
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: ourShelfTextPrimary,
      ),
      // Main section heading — 20/700.
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: ourShelfTextPrimary,
      ),
      // Card heading — 17/600.
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: ourShelfTextPrimary,
      ),
      // Body text — 15/400.
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: ourShelfTextPrimary,
      ),
      // Secondary text — 13/400.
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: ourShelfTextSecondary,
      ),
      // Small labels — 12/600.
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: ourShelfTextSecondary,
      ),
      // Primary buttons — 16/700.
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );

    return MaterialApp(
      title: 'OurShelf',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        textTheme: textTheme,
        scaffoldBackgroundColor: ourShelfBackground,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: colorScheme.secondary,
          foregroundColor: const Color(0xFF2B0A4E),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: ourShelfCardBackground,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OurShelfSpacing.cardRadius),
            side: const BorderSide(color: ourShelfBorder),
          ),
        ),
        chipTheme: ChipThemeData(
          selectedColor: ourShelfLightAccent,
          backgroundColor: ourShelfBackground,
          labelStyle: const TextStyle(color: ourShelfTextPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: ourShelfBorder),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(OurShelfSpacing.inputRadius),
            borderSide: const BorderSide(color: ourShelfBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(OurShelfSpacing.inputRadius),
            borderSide: const BorderSide(color: ourShelfBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(OurShelfSpacing.inputRadius),
            borderSide: const BorderSide(color: ourShelfSeed, width: 1.4),
          ),
        ),
        // Primary actions are Royal Aubergine with white text per the design
        // system — gold is reserved for specific highlights/accents, not
        // every button.
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: ourShelfSeed,
            foregroundColor: Colors.white,
            disabledBackgroundColor: ourShelfSeed.withValues(alpha: 0.4),
            minimumSize: const Size.fromHeight(OurShelfSpacing.primaryButtonHeight),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ourShelfSeed,
            side: const BorderSide(color: ourShelfBorder),
            minimumSize: const Size.fromHeight(OurShelfSpacing.primaryButtonHeight),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
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
