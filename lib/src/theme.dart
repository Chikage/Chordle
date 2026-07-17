import 'package:flutter/material.dart';

abstract final class ChordleColors {
  static const background = Color(0xFF121213);
  static const surface = Color(0xFF1A1A1B);
  static const elevatedSurface = Color(0xFF242426);
  static const text = Color(0xFFF8F8F8);
  static const muted = Color(0xFFB8B8BB);
  static const border = Color(0xFF3A3A3C);
  static const green = Color(0xFF6AAA64);
  static const yellow = Color(0xFFCCB757);
  static const gray = Color(0xFF86888A);
  static const extraCorrect = Color(0xFF8EB8FF);
  static const extraNear = Color(0xFFF0A9C8);
  static const selected = Color(0xFFCBB8FF);
  static const error = Color(0xFFE57373);
  static const dialogBackground = Color(0xFFF8F0F8);
  static const dialogText = Color(0xFF4E4156);
  static const dialogMuted = Color(0xFF6E5D75);
}

String chordleWordmarkFontFamily(TargetPlatform platform) => switch (platform) {
  TargetPlatform.iOS => '.AppleSystemUIFontSerif',
  _ => 'serif',
};

ThemeData buildChordleTheme() {
  final colorScheme = const ColorScheme.dark(
    primary: ChordleColors.green,
    onPrimary: Colors.white,
    secondary: ChordleColors.yellow,
    onSecondary: Colors.white,
    error: ChordleColors.error,
    surface: ChordleColors.surface,
    onSurface: ChordleColors.text,
  );

  final base = ThemeData(
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: ChordleColors.background,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: ChordleColors.text,
      displayColor: ChordleColors.text,
    ),
    dividerColor: ChordleColors.border,
    splashColor: Colors.white.withValues(alpha: 0.08),
    highlightColor: Colors.white.withValues(alpha: 0.04),
    iconTheme: const IconThemeData(color: ChordleColors.muted),
    appBarTheme: const AppBarTheme(
      backgroundColor: ChordleColors.background,
      foregroundColor: ChordleColors.text,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ChordleColors.green,
        foregroundColor: Colors.white,
        disabledBackgroundColor: ChordleColors.border,
        disabledForegroundColor: ChordleColors.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ChordleColors.text,
        disabledForegroundColor: ChordleColors.gray,
        side: const BorderSide(color: ChordleColors.border, width: 1.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ChordleColors.muted,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: ChordleColors.green,
      inactiveTrackColor: ChordleColors.border,
      thumbColor: ChordleColors.green,
      overlayColor: ChordleColors.green.withValues(alpha: 0.16),
      valueIndicatorColor: ChordleColors.elevatedSurface,
      valueIndicatorTextStyle: const TextStyle(color: ChordleColors.text),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : ChordleColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ChordleColors.green
            : ChordleColors.border,
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: ChordleColors.dialogBackground,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: ChordleColors.dialogText,
        fontSize: 21,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: TextStyle(
        color: ChordleColors.dialogText,
        fontSize: 15,
        height: 1.35,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF2E2E31),
      contentTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
