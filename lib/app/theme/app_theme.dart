import 'package:flutter/material.dart';

/// One visual system for the business workspace and every QuickPrice entry.
abstract final class HynerTheme {
  static const inkGreen = Color(0xFF175C46);
  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: inkGreen,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFF9AD8B8) : inkGreen,
          onPrimary: dark ? const Color(0xFF0A3927) : Colors.white,
          primaryContainer: dark
              ? const Color(0xFF234B38)
              : const Color(0xFFE0EDE4),
          onPrimaryContainer: dark
              ? const Color(0xFFD6F2DF)
              : const Color(0xFF193F2D),
          surface: dark ? const Color(0xFF111A16) : const Color(0xFFF8F9F5),
          onSurface: dark ? const Color(0xFFEDF3EC) : const Color(0xFF222D27),
          onSurfaceVariant: dark
              ? const Color(0xFFB5C3B8)
              : const Color(0xFF526157),
          surfaceContainerLow: dark
              ? const Color(0xFF19241E)
              : const Color(0xFFFFFEFB),
          surfaceContainerHighest: dark
              ? const Color(0xFF293A30)
              : const Color(0xFFE8EEE7),
          outline: dark ? const Color(0xFF82988A) : const Color(0xFF76877B),
          outlineVariant: dark
              ? const Color(0xFF34473B)
              : const Color(0xFFDCE3DA),
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: 'Manrope',
    );
    final text = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    const radius = BorderRadius.all(Radius.circular(10));
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -.8,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          letterSpacing: -.3,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -.2,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
        bodySmall: text.bodySmall?.copyWith(
          fontSize: 12,
          height: 1.5,
          color: scheme.onSurfaceVariant,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: const OutlineInputBorder(borderRadius: radius),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        helperMaxLines: 3,
        errorMaxLines: 4,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          shape: const RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w600,
          ),
          shape: const RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Manrope',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 12, bottom: 16),
        shape: const Border(),
        collapsedShape: const Border(),
        textColor: scheme.onSurface,
        collapsedTextColor: scheme.onSurface,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? scheme.surfaceContainerHighest
            : scheme.onSurface,
        contentTextStyle: TextStyle(
          fontFamily: 'Manrope',
          color: dark ? scheme.onSurface : scheme.surface,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        minVerticalPadding: 8,
        minTileHeight: 56,
      ),
    );
  }
}
