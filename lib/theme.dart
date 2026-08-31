import "package:flutter/material.dart";

const background = Color(0xFFF8F7F2);
const surface = Color(0xFFFFFFFF);
const surfaceAlt = Color(0xFFF0F4EF);
const ink = Color(0xFF17211C);
const mutedInk = Color(0xFF6F7973);
const primary = Color(0xFF187A4E);
const primaryDark = Color(0xFF0E5637);
const primarySoft = Color(0xFFE1F3E8);
const amber = Color(0xFFC78316);
const amberSoft = Color(0xFFFFF2D5);
const hairline = Color(0xFFE3E8E3);
const phoneFrame = Color(0xFF111815);
const desktopBackdrop = Color(0xFFFFFFFF);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.light,
    surface: surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
          fontFamily: "serif",
          fontSize: 32,
          height: 1.04,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.9,
          color: ink),
      headlineMedium: TextStyle(
          fontFamily: "serif",
          fontSize: 26,
          height: 1.08,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.6,
          color: ink),
      titleMedium:
          TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
      bodyLarge: TextStyle(fontSize: 15, height: 1.5, color: ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: ink),
      bodySmall: TextStyle(fontSize: 12, height: 1.35, color: mutedInk),
      labelSmall: TextStyle(
          fontSize: 10,
          letterSpacing: 1.05,
          fontWeight: FontWeight.w700,
          color: mutedInk),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0.6,
      shadowColor: const Color(0x180E3D27),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: hairline),
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: hairline)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: hairline)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );
}
