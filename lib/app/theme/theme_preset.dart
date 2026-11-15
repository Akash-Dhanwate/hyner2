import 'package:flutter/material.dart';

/// Colour choice is independent of the user's light/dark appearance preference.
enum ThemePreset {
  slateBlue(
    'Slate Blue',
    Color(0xFF45617D),
    Color(0xFFB2CBE6),
    Color(0xFFF7F8FA),
    Color(0xFF151A20),
  ),
  sageGreen(
    'Sage Green',
    Color(0xFF175C46),
    Color(0xFF9AD8B8),
    Color(0xFFF8F9F5),
    Color(0xFF111A16),
  ),
  warmCopper(
    'Warm Copper',
    Color(0xFF855236),
    Color(0xFFE9BC99),
    Color(0xFFFAF8F5),
    Color(0xFF211A16),
  ),
  mutedViolet(
    'Muted Violet',
    Color(0xFF675480),
    Color(0xFFD1BDE7),
    Color(0xFFF9F8FA),
    Color(0xFF1C1821),
  );

  const ThemePreset(
    this.label,
    this.lightPrimary,
    this.darkPrimary,
    this.lightSurface,
    this.darkSurface,
  );
  final String label;
  final Color lightPrimary, darkPrimary, lightSurface, darkSurface;
}

/// Non-brand semantic colours used by UI states and charts, never PDF content.
@immutable
class HynerStatusColors extends ThemeExtension<HynerStatusColors> {
  const HynerStatusColors({required this.success, required this.warning});
  final Color success, warning;

  @override
  HynerStatusColors copyWith({Color? success, Color? warning}) =>
      HynerStatusColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
      );

  @override
  HynerStatusColors lerp(covariant HynerStatusColors? other, double t) =>
      other == null
      ? this
      : HynerStatusColors(
          success: Color.lerp(success, other.success, t)!,
          warning: Color.lerp(warning, other.warning, t)!,
        );
}
