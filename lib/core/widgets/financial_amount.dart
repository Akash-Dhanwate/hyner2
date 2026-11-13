import 'package:flutter/material.dart';

/// Displays an already formatted value. Never parses, rounds or converts money.
class FinancialAmount extends StatelessWidget {
  const FinancialAmount(
    this.value, {
    super.key,
    this.textKey,
    this.prominent = false,
    this.compact = false,
    this.color,
    this.textAlign,
    this.style,
    this.selectable = false,
  });
  final String value;
  final Key? textKey;
  final bool prominent, compact;
  final Color? color;
  final TextAlign? textAlign;
  final TextStyle? style;
  final bool selectable;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = Theme.of(context);
      final base = prominent
          ? theme.textTheme.headlineSmall
          : theme.textTheme.titleMedium;
      final amountStyle = base
          ?.copyWith(
            fontSize: prominent
                ? (constraints.maxWidth < 300 ? 24 : 28)
                : compact
                ? 16
                : 20,
            fontWeight: prominent ? FontWeight.w800 : FontWeight.w700,
            height: 1.3,
            letterSpacing: -.2,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: color ?? theme.colorScheme.onSurface,
          )
          .merge(style);
      if (selectable) {
        return SelectableText(
          value,
          key: textKey,
          textAlign: textAlign,
          style: amountStyle,
        );
      }
      return Text(
        value,
        key: textKey,
        textAlign: textAlign,
        softWrap: true,
        style: amountStyle,
      );
    },
  );
}
