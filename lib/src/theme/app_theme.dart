import 'package:flutter/material.dart';

class AppPalette {
  static Brightness _brightness = Brightness.light;
  static bool _highContrast = false;

  static void setVisualStyle(
    Brightness brightness, {
    bool highContrast = false,
  }) {
    _brightness = brightness;
    _highContrast = highContrast;
  }

  static bool get isDark => _brightness == Brightness.dark;
  static bool get isHighContrast => _highContrast;

  static Color get background => isDark
      ? isHighContrast
            ? const Color(0xFF060708)
            : const Color(0xFF111315)
      : isHighContrast
      ? const Color(0xFFFFFFFF)
      : const Color(0xFFF8F4EE);

  static Color get foreground => isDark
      ? isHighContrast
            ? const Color(0xFFFFFFFF)
            : const Color(0xFFF5EFE4)
      : isHighContrast
      ? const Color(0xFF000000)
      : const Color(0xFF1D1711);

  static Color get card => isDark
      ? isHighContrast
            ? const Color(0xFF11151A)
            : const Color(0xFF1A1F23)
      : isHighContrast
      ? const Color(0xFFFFFFFF)
      : const Color(0xFFFFFCF7);

  static Color get primary => const Color(0xFFC88B2D);

  static Color get secondary => isDark
      ? isHighContrast
            ? const Color(0xFF20262D)
            : const Color(0xFF252B31)
      : isHighContrast
      ? const Color(0xFFF3E8D4)
      : const Color(0xFFF0E2CC);

  static Color get muted => isDark
      ? isHighContrast
            ? const Color(0xFF181D22)
            : const Color(0xFF20262B)
      : isHighContrast
      ? const Color(0xFFF4EFE6)
      : const Color(0xFFF2ECE2);

  static Color get mutedForeground => isDark
      ? isHighContrast
            ? const Color(0xFFF1E8D7)
            : const Color(0xFFB9B0A2)
      : isHighContrast
      ? const Color(0xFF3F3427)
      : const Color(0xFF6F6456);

  static Color get border => isDark
      ? isHighContrast
            ? const Color(0xFF8A949D)
            : const Color(0xFF2D343A)
      : isHighContrast
      ? const Color(0xFF977A45)
      : const Color(0xFFE7D9C0);

  static const Color white = Colors.white;
  static const Color black = Color(0xFF0C0F11);
  static const Color success = Color(0xFF2D9A68);

  static Color get shadow => black.withValues(alpha: isDark ? 0.30 : 0.08);
}

ThemeData buildAppTheme({
  Brightness brightness = Brightness.light,
  bool highContrast = false,
}) {
  AppPalette.setVisualStyle(brightness, highContrast: highContrast);

  final ColorScheme scheme =
      ColorScheme.fromSeed(
        seedColor: AppPalette.primary,
        brightness: brightness,
      ).copyWith(
        primary: AppPalette.primary,
        onPrimary: AppPalette.white,
        secondary: AppPalette.secondary,
        onSecondary: AppPalette.foreground,
        surface: AppPalette.card,
        onSurface: AppPalette.foreground,
        outline: AppPalette.border,
      );

  final ThemeData base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppPalette.background,
    brightness: brightness,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppPalette.foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: AppPalette.foreground,
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppPalette.card,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    dividerColor: AppPalette.border,
    splashColor: AppPalette.primary.withValues(alpha: 0.08),
    highlightColor: Colors.transparent,
    iconTheme: IconThemeData(color: AppPalette.foreground),
    textTheme: base.textTheme.apply(
      bodyColor: AppPalette.foreground,
      displayColor: AppPalette.foreground,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppPalette.isDark
          ? AppPalette.isHighContrast
                ? const Color(0xFF0F1317)
                : const Color(0xFF161B1F)
          : AppPalette.card,
      hintStyle: TextStyle(color: AppPalette.mutedForeground),
      labelStyle: TextStyle(color: AppPalette.mutedForeground),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: AppPalette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: AppPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: AppPalette.primary, width: 1.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.primary,
        foregroundColor: AppPalette.white,
        minimumSize: const Size(0, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppPalette.foreground,
        side: BorderSide(color: AppPalette.border),
        minimumSize: const Size(0, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppPalette.secondary,
      selectedColor: AppPalette.primary.withValues(alpha: 0.18),
      side: BorderSide(color: AppPalette.border),
      labelStyle: TextStyle(color: AppPalette.foreground),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppPalette.foreground,
      contentTextStyle: TextStyle(color: AppPalette.background),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

BoxDecoration appCardDecoration({
  Color? color,
  double radius = 28,
  Border? border,
}) {
  return BoxDecoration(
    color: color ?? AppPalette.card,
    borderRadius: BorderRadius.circular(radius),
    border:
        border ??
        Border.all(
          color: AppPalette.border.withValues(
            alpha: AppPalette.isHighContrast ? 1 : 0.7,
          ),
        ),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: AppPalette.shadow,
        blurRadius: 32,
        spreadRadius: -10,
        offset: const Offset(0, 18),
      ),
    ],
  );
}
