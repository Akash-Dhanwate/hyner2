import 'package:flutter/material.dart';

import 'theme_preset.dart';

export 'theme_preset.dart';

/// One visual system for the business workspace and every QuickPrice entry.
abstract final class HynerTheme {
  static const inkGreen = Color(0xFF175C46);
  static final _cache = <(Brightness, ThemePreset), ThemeData>{};
  static ThemeData build(
    Brightness brightness, {
    ThemePreset preset = ThemePreset.sageGreen,
  }) => _cache.putIfAbsent((
    brightness,
    preset,
  ), () => _build(brightness, preset));

  static ThemeData _build(Brightness brightness, ThemePreset preset) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: preset.lightPrimary,
          brightness: brightness,
        ).copyWith(
          primary: dark ? preset.darkPrimary : preset.lightPrimary,
          onPrimary: dark ? preset.darkSurface : Colors.white,
          primaryContainer: dark
              ? Color.alphaBlend(
                  preset.darkPrimary.withValues(alpha: .16),
                  preset.darkSurface,
                )
              : Color.alphaBlend(
                  preset.lightPrimary.withValues(alpha: .10),
                  preset.lightSurface,
                ),
          onPrimaryContainer: dark ? preset.darkPrimary : preset.lightPrimary,
          surface: dark ? preset.darkSurface : preset.lightSurface,
          onSurface: dark ? const Color(0xFFEDF3EC) : const Color(0xFF222D27),
          onSurfaceVariant: dark
              ? const Color(0xFFB5C3B8)
              : const Color(0xFF526157),
          surfaceContainerLow: dark
              ? Color.alphaBlend(
                  preset.darkPrimary.withValues(alpha: .04),
                  preset.darkSurface,
                )
              : const Color(0xFFFFFEFB),
          surfaceContainerHighest: dark
              ? Color.alphaBlend(
                  preset.darkPrimary.withValues(alpha: .10),
                  preset.darkSurface,
                )
              : Color.alphaBlend(
                  preset.lightPrimary.withValues(alpha: .06),
                  preset.lightSurface,
                ),
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
      extensions: [
        HynerStatusColors(
          success: dark ? const Color(0xFF9AD8B8) : const Color(0xFF246447),
          warning: dark ? const Color(0xFFE9C58C) : const Color(0xFF80541D),
        ),
      ],
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
