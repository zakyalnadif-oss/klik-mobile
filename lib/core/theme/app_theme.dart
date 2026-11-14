import 'package:material_ui/material_ui.dart';

import '../constants/design_tokens.dart';

abstract final class AppTheme {
  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: DesignTokens.accent,
          brightness: brightness,
        ).copyWith(
          primary: dark ? DesignTokens.accent : const Color(0xFF663000),
          onPrimary: DesignTokens.lightText,
          surface: dark ? DesignTokens.darkCard : DesignTokens.lightCard,
          onSurface: dark ? DesignTokens.darkText : DesignTokens.lightText,
          onSurfaceVariant: dark
              ? DesignTokens.darkSecondary
              : DesignTokens.lightSecondary,
        );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: brightness,
      colorScheme: colors,
      dividerColor: dark ? const Color(0xFF303036) : const Color(0xFFECE7DF),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DesignTokens.accent,
          foregroundColor: const Color(0xFF663000),
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const StadiumBorder(),
          foregroundColor: colors.onSurface,
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: DesignTokens.accent,
        backgroundColor: colors.surface,
        side: BorderSide.none,
        checkmarkColor: const Color(0xFF171B12),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: colors.onSurface,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: Color(0xFF171B12),
        ),
      ),
      scaffoldBackgroundColor: dark
          ? DesignTokens.darkBackground
          : DesignTokens.lightBackground,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: DesignTokens.accent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: 'Inter', fontSize: 11, color: colors.onSurface),
        ),
      ),
    );
  }
}
