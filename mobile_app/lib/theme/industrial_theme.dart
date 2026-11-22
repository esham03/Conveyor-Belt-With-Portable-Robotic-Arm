import 'package:flutter/material.dart';

class IndustrialTheme {
  // Primary Palette - Dark Graphite & Navy Industrial Base
  static const Color background = Color(0xFF0A0E17);
  static const Color surface = Color(0xFF121824);
  static const Color surfaceElevated = Color(0xFF1B2436);
  static const Color surfaceHighlight = Color(0xFF243048);
  static const Color border = Color(0xFF2A3852);

  // Accents - Crisp Cyan & Control Blue
  static const Color cyanAccent = Color(0xFF00E5FF);
  static const Color cyanDim = Color(0xFF00838F);
  static const Color blueControl = Color(0xFF0288D1);
  static const Color blueHover = Color(0xFF03A9F4);

  // Industrial Status Tints
  static const Color statusGreen = Color(0xFF00E676); // Operational / Normal
  static const Color statusAmber = Color(0xFFFFB300); // Standby / Calibrating
  static const Color statusRed = Color(0xFFFF1744);   // Emergency / Fault / Halted
  static const Color statusPurple = Color(0xFFB388FF);

  // Typography Colors
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: cyanAccent,
        secondary: blueControl,
        surface: surface,
        error: statusRed,
        onPrimary: background,
        onSecondary: textPrimary,
        onSurface: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
        iconTheme: IconThemeData(color: cyanAccent),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: surfaceElevated,
          foregroundColor: cyanAccent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: border, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: cyanAccent,
        inactiveTrackColor: surfaceElevated,
        thumbColor: cyanAccent,
        trackHeight: 4,
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
