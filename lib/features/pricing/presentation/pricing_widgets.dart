import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

import '../application/calculator_session.dart';
import '../application/product_setup.dart';
import '../domain/exact.dart';
import '../domain/universal/universal_pricing.dart';

ThemeData hynerTheme(Brightness brightness) => HynerTheme.build(brightness);

class ValueField extends StatefulWidget {
  const ValueField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.numeric = false,
    this.helper,
    this.large = false,
    this.lines = 1,
  });
  final String label, value;
  final ValueChanged<String> onChanged;
  final bool numeric, large;
  final String? helper;
  final int lines;
  @override
  State<ValueField> createState() => _ValueFieldState();
}

class _ValueFieldState extends State<ValueField> {
  late final TextEditingController controller = TextEditingController(
    text: widget.value,
  );
  @override
  void didUpdateWidget(ValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.text != widget.value) {
      controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: widget.onChanged,
    maxLines: widget.lines,
    keyboardType: widget.numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    textInputAction: widget.lines > 1
        ? TextInputAction.newline
        : TextInputAction.next,
    style: widget.large
        ? const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          )
        : null,
    decoration: InputDecoration(
      labelText: widget.label,
      helperText: widget.helper,
      helperMaxLines: 3,
    ),
  );
}

class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey('$label:$value:${options.keys.join(',')}'),
    initialValue: options.containsKey(value) ? value : null,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: options.entries
        .map(
          (e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
  );
}

class FormSection extends StatelessWidget {
  const FormSection(
    this.title, {
    super.key,
    required this.children,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: 14),
        for (final child in children)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
      ],
    ),
  );
}

class MessageLine extends StatelessWidget {
  const MessageLine(this.message, {super.key, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Semantics(
      liveRegion: error,
      child: Text(
        message,
        style: TextStyle(
          color: error
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

class DynamicInputs extends StatelessWidget {
  const DynamicInputs({super.key, required this.session});
  final CalculatorSession session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final fields = session.visibleFields;
      return LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns =
              constraints.maxWidth >= 280 &&
              MediaQuery.textScalerOf(context).scale(16) < 21;
          final children = <Widget>[
            if (session.availableLengthUnits.isNotEmpty) ...[
              CheckboxListTile(
                key: const ValueKey('use-same-unit'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Use the same unit'),
                value: session.useSameUnit,
                onChanged: (value) => session.setUseSameUnit(value ?? true),
              ),
              if (session.useSameUnit)
                SelectField(
                  key: const ValueKey('common-length-unit'),
                  label: 'Measurement unit',
                  value: session.commonLengthUnit,
                  options: {
                    for (final unit in session.availableLengthUnits)
                      unit: '${unitLabels[unit] ?? unit} ($unit)',
                  },
                  onChanged: session.changeLengthUnit,
                ),
            ],
          ];
          final choiceControls = fields
              .where((f) => f.type == InputDataType.choice)
              .toList();
          children.insertAll(0, [
            for (final field in choiceControls) _field(context, field),
          ]);
          final measurements = fields
              .where((f) => f.type != InputDataType.choice)
              .toList();
          for (var i = 0; i < measurements.length; i++) {
            final field = measurements[i];
            if (twoColumns &&
                field.isNumeric &&
                i + 1 < measurements.length &&
                measurements[i + 1].isNumeric) {
              children.add(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _field(context, field)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(context, measurements[++i])),
                  ],
                ),
              );
            } else {
              children.add(_field(context, field));
            }
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: child,
                ),
            ],
          );
        },
      );
    },
  );
  Widget _field(BuildContext context, InputDefinition field) {
    final entry = session.entries[field.id]!;
    if (field.type == InputDataType.boolean) {
      return SwitchListTile.adaptive(
        key: ValueKey('input-${field.id}'),
        contentPadding: EdgeInsets.zero,
        title: Text(field.label),
        value: entry['checked'] == true,
        onChanged: (v) => session.change(field.id, 'checked', v),
      );
    }
    if (field.type == InputDataType.choice) {
      return SelectField(
        key: ValueKey('input-${field.id}'),
        label: field.label,
        value: entry['choice'] as String?,
        options: {for (final c in field.choices) c: c},
        onChanged: (v) => session.change(field.id, 'choice', v),
      );
    }
    final orderedUnits = field.dimension == MeasureDimension.length
        ? [
            ...CalculatorSession.lengthUnits.where(
              field.permittedUnits.contains,
            ),
            ...field.permittedUnits.where(
              (u) => !CalculatorSession.lengthUnits.contains(u),
            ),
          ]
        : field.permittedUnits;
    final units = {for (final u in orderedUnits) u: unitShort[u] ?? u};
    if (field.permittedUnits.contains('ft') &&
        field.permittedUnits.contains('in')) {
      units['ft_in'] = 'ft + in';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueField(
          key: ValueKey('input-${field.id}'),
          label: entry['unit'] == 'ft_in'
              ? '${field.label} · feet'
              : '${field.label} · ${unitShort[entry['unit']] ?? entry['unit']}',
          helper: session.isRounded(field.id)
              ? '≈ Rounded display (half up). Exact measurement used until edited.'
              : null,
          value: entry['text'] as String,
          numeric: true,
          large: true,
          onChanged: (v) => session.change(field.id, 'text', v),
        ),
        if (entry['unit'] == 'ft_in')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ValueField(
              key: ValueKey('inches-${field.id}'),
              label: '${field.label} · inches',
              value: entry['inches'] as String? ?? '',
              numeric: true,
              onChanged: (v) => session.change(field.id, 'inches', v),
            ),
          ),
        if (!session.usesCommonUnit(field)) ...[
          const SizedBox(height: 6),
          Semantics(
            label: '${field.label} unit',
            child: DropdownButton<String>(
              key: ValueKey('unit-${field.id}'),
              value: units.containsKey(entry['unit'])
                  ? entry['unit'] as String
                  : null,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: units.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) session.change(field.id, 'unit', v);
              },
            ),
          ),
        ],
      ],
    );
  }
}

class QuantityControl extends StatelessWidget {
  const QuantityControl({super.key, required this.session});
  final CalculatorSession session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'Decrease quantity',
            onPressed: (int.tryParse(session.quantity) ?? 1) <= 1
                ? null
                : () => session.stepQuantity(-1),
            icon: const Icon(Icons.remove),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ValueField(
              key: const ValueKey('quantity'),
              label: 'Quantity',
              value: session.quantity,
              numeric: true,
              onChanged: session.changeQuantity,
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'Increase quantity',
            onPressed: (int.tryParse(session.quantity) ?? 1) >= 1000000
                ? null
                : () => session.stepQuantity(1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    ),
  );
}

class PricePanel extends StatelessWidget {
  const PricePanel({
    super.key,
    required this.session,
    this.compact = false,
    this.breakdown = true,
    this.summaryOnly = false,
    this.expandBreakdown = false,
    this.title = 'Estimated total',
  });
  final CalculatorSession session;
  final String title;
  final bool compact, breakdown, summaryOnly, expandBreakdown;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final result = session.result;
      final scheme = Theme.of(context).colorScheme;
      if (result == null) {
        return MessageLine(
          session.error ?? 'Enter the product details',
          error: true,
        );
      }
      final currency = result.rule.currency;
      Widget line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 4,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(color: scheme.onSurfaceVariant)),
          Semantics(
            liveRegion: true,
            child: Text(
              moneyText(result.amounts.totalMinor, currency),
              key: const ValueKey('price-total'),
              style: TextStyle(
                fontSize: compact ? 28 : 34,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (!summaryOnly)
            for (final warning in result.warnings.toSet())
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(warning, style: TextStyle(color: scheme.tertiary)),
              ),
          if (!compact && !summaryOnly) ...[
            const SizedBox(height: 6),
            Text(
              '${result.request.quantity} × ${moneyText(currency.minor(result.unitBaseAmount, result.rule.rounding), currency)} base per item',
            ),
            Text(
              'Tax ${moneyText(result.amounts.taxMinor, currency)} · Excl. tax ${moneyText(result.amounts.netMinor, currency)}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (breakdown)
              ExpansionTile(
                initiallyExpanded: expandBreakdown,
                tilePadding: EdgeInsets.zero,
                title: const Text('Price breakdown'),
                children: [
                  for (final charge in result.base)
                    line(
                      'Measured → billable',
                      '${decimalText(charge.measured, approximate: true)} ${unitShort[charge.measuredUnit] ?? charge.measuredUnit} → ${decimalText(charge.billable, approximate: true)} ${unitShort[charge.unit] ?? charge.unit}',
                    ),
                  for (final charge in result.extras)
                    line(
                      charge.label.split(' / ').first,
                      moneyText(
                        currency.minor(
                          charge.amount *
                              Exact.integer(
                                charge.perOrder ? 1 : result.request.quantity,
                              ),
                          result.rule.rounding,
                        ),
                        currency,
                      ),
                    ),
                  line(
                    'Subtotal excluding tax',
                    moneyText(result.amounts.subtotalMinor, currency),
                  ),
                  line(
                    'Discount',
                    moneyText(result.amounts.discountMinor, currency),
                  ),
                  line('Tax', moneyText(result.amounts.taxMinor, currency)),
                  line(
                    'Total including tax',
                    moneyText(result.amounts.totalMinor, currency),
                  ),
                  line('Rate version', '${result.rule.version}'),
                ],
              ),
          ],
        ],
      );
    },
  );
}
