import 'package:flutter/material.dart';

import '../application/product_setup.dart';
import '../application/workspace.dart';
import 'pricing_widgets.dart';

class ExpressionEditor extends StatelessWidget {
  const ExpressionEditor({
    super.key,
    required this.node,
    required this.variables,
    required this.onChanged,
    this.depth = 0,
  });
  final Map<String, dynamic> node;
  final Map<String, String> variables;
  final VoidCallback onChanged;
  final int depth;
  @override
  Widget build(BuildContext context) {
    void set(String key, dynamic value) {
      node[key] = value;
      onChanged();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectField(
          label: depth == 0 ? 'Expression' : 'Operand',
          value: node['kind'] as String,
          options: {
            'reference': 'Input or rate',
            'literal': 'Constant',
            if (depth < 8) 'binary': 'Arithmetic operation',
          },
          onChanged: (v) {
            node.clear();
            node.addAll(switch (v) {
              'literal' => literalDraft('', 'number'),
              'binary' => opDraft(
                'multiply',
                literalDraft('1'),
                variables.isEmpty
                    ? literalDraft('1')
                    : refDraft(variables.keys.first),
              ),
              _ => refDraft(variables.keys.firstOrNull ?? ''),
            });
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        if (node['kind'] == 'reference')
          SelectField(
            label: 'Variable',
            value: node['name'] as String?,
            options: variables,
            onChanged: (v) => set('name', v),
          ),
        if (node['kind'] == 'literal') ...[
          ValueField(
            label: 'Constant value',
            value: node['value'] as String,
            numeric: true,
            onChanged: (v) => set('value', v),
          ),
          const SizedBox(height: 8),
          SelectField(
            label: 'Constant unit',
            value: node['unit'] as String,
            options: {...unitLabels, 'money': 'Profile currency'},
            onChanged: (v) => set('unit', v),
          ),
        ],
        if (node['kind'] == 'binary') ...[
          SelectField(
            label: 'Operation',
            value: node['operation'] as String,
            options: const {
              'add': 'Add (+)',
              'subtract': 'Subtract (−)',
              'multiply': 'Multiply (×)',
              'divide': 'Divide (÷)',
              'minimum': 'Smaller value',
              'maximum': 'Larger value',
              'ceilTo': 'Round up to increment',
            },
            onChanged: (v) => set('operation', v),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(depth == 0 ? 'Left side' : 'First operand'),
                const SizedBox(height: 6),
                ExpressionEditor(
                  node: node['left'] as Map<String, dynamic>,
                  variables: variables,
                  onChanged: onChanged,
                  depth: depth + 1,
                ),
                const SizedBox(height: 14),
                const Text('Second operand'),
                const SizedBox(height: 6),
                ExpressionEditor(
                  node: node['right'] as Map<String, dynamic>,
                  variables: variables,
                  onChanged: onChanged,
                  depth: depth + 1,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class InputSchemaEditor extends StatelessWidget {
  const InputSchemaEditor({
    super.key,
    required this.fields,
    required this.onChanged,
  });
  final List<Map<String, dynamic>> fields;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, field) in fields.indexed)
        _field(context, field, index),
      TextButton.icon(
        onPressed: fields.length >= 32
            ? null
            : () {
                fields.add(
                  inputDraft(
                    'input_${newPricingId().substring(0, 8)}',
                    'New input',
                    'number',
                  ),
                );
                onChanged();
              },
        icon: const Icon(Icons.add),
        label: const Text('Add input field'),
      ),
    ],
  );
  Widget _field(BuildContext context, Map<String, dynamic> field, int index) {
    void set(String key, dynamic value) {
      field[key] = value;
      onChanged();
    }

    Widget text(
      String key,
      String label, {
      bool numeric = false,
      String? helper,
    }) => ValueField(
      label: label,
      value: field[key] as String? ?? '',
      numeric: numeric,
      helper: helper,
      onChanged: (v) => set(key, v),
    );
    final numeric = ['decimal', 'integer'].contains(field['type']);
    final dependencies = fields.where(
      (f) => f != field && ['choice', 'boolean'].contains(f['type']),
    );
    final dependency = dependencies
        .where((f) => f['id'] == field['visibleField'])
        .firstOrNull;
    final choices = dependency == null
        ? <String>[]
        : dependency['type'] == 'boolean'
        ? ['true', 'false']
        : (dependency['choices'] as String)
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
    return ExpansionTile(
      key: ObjectKey(field),
      tilePadding: EdgeInsets.zero,
      title: Text(field['label'] as String),
      subtitle: Text(
        numeric
            ? unitLabels[field['unit']] ?? '${field['unit']}'
            : '${field['type']}',
      ),
      children: [
        FormSection(
          'Input settings',
          children: [
            text('label', 'Label shown to seller'),
            SelectField(
              label: 'Input type',
              value: field['type'] as String,
              options: const {
                'decimal': 'Measurement / decimal',
                'integer': 'Whole number',
                'choice': 'Choice',
                'boolean': 'Yes / no',
              },
              onChanged: (v) => set('type', v),
            ),
            if (numeric) ...[
              SelectField(
                label: 'Default unit',
                value: field['unit'] as String,
                options: unitLabels,
                onChanged: (v) {
                  field['unit'] = v;
                  field['permitted'] = compatibleUnits(v);
                  onChanged();
                },
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final unit in compatibleUnits(field['unit'] as String))
                    FilterChip(
                      label: Text(unitShort[unit] ?? unit),
                      selected: (field['permitted'] as List).contains(unit),
                      onSelected: unit == field['unit']
                          ? null
                          : (v) {
                              final permitted = field['permitted'] as List;
                              if (v) {
                                permitted.add(unit);
                              } else {
                                permitted.remove(unit);
                              }
                              onChanged();
                            },
                    ),
                ],
              ),
              text('minimum', 'Minimum permitted value', numeric: true),
              text(
                'maximum',
                'Maximum permitted value (optional)',
                numeric: true,
              ),
              text('precision', 'Decimal places allowed', numeric: true),
              text('multiple', 'Required multiple (optional)', numeric: true),
              text(
                'billMinimum',
                'Minimum billable dimension (optional)',
                numeric: true,
              ),
              text(
                'billIncrement',
                'Round dimension up by (optional)',
                numeric: true,
                helper: 'Uses the default unit. The seller will see any billing adjustment.',
              ),
            ],
            if (field['type'] == 'choice')
              text('choices', 'Choices, separated by commas'),
            if (field['type'] == 'boolean')
              SelectField(
                label: 'Default selection',
                value: field['default'] == 'true' ? 'true' : 'false',
                options: const {'false': 'Off', 'true': 'On'},
                onChanged: (v) => set('default', v),
              )
            else
              text('default', 'Default value (optional)', numeric: numeric),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Required input'),
              value: field['required'] as bool,
              onChanged: (v) => set('required', v),
            ),
            SelectField(
              label: 'Show this field',
              value: field['visibleField'] as String? ?? '',
              options: {
                '': 'Always',
                for (final d in dependencies)
                  d['id'] as String: 'When ${d['label']} matches',
              },
              onChanged: (v) => set('visibleField', v),
            ),
            if ((field['visibleField'] as String? ?? '').isNotEmpty)
              SelectField(
                label: 'Show when value is',
                value: field['visibleValue'] as String?,
                options: {for (final c in choices) c: c},
                onChanged: (v) => set('visibleValue', v),
              ),
            text(
              'id',
              'Formula variable ID',
              helper: 'Use letters, numbers and underscores. Keep IDs consistent across compatible products.',
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: index == 0
                      ? null
                      : () {
                          fields.removeAt(index);
                          fields.insert(index - 1, field);
                          onChanged();
                        },
                  icon: const Icon(Icons.arrow_upward),
                  label: const Text('Move up'),
                ),
                TextButton.icon(
                  onPressed: () {
                    fields.remove(field);
                    onChanged();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove field'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class RatesEditor extends StatelessWidget {
  const RatesEditor({super.key, required this.setup, required this.onChanged});
  final ProductSetup setup;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final choices = setup.rows('fields').where((f) => f['type'] == 'choice');
    final rows = setup.rows('rates');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, rate) in rows.indexed)
          FormSection(
            rows.length == 1 ? 'Selling rate' : 'Rate ${index + 1}',
            children: [
              ValueField(
                key: ValueKey('rate-${rate['id']}'),
                label: 'Selling rate',
                value: rate['amount'] as String,
                numeric: true,
                onChanged: (v) {
                  rate['amount'] = v;
                  onChanged();
                },
              ),
              if (setup.kind == 'formula')
                ValueField(
                  label: 'Rate variable name',
                  value: rate['key'] as String,
                  helper:
                      'Reference this as rate:${rate['key']} in the formula.',
                  onChanged: (v) {
                    rate['key'] = v;
                    onChanged();
                  },
                ),
              if (setup.kind == 'formula')
                SelectField(
                  label: 'Unit for this rate',
                  value: rate['unit'] as String,
                  options: {'': 'Use product rate unit', ...unitLabels},
                  onChanged: (v) {
                    rate['unit'] = v;
                    onChanged();
                  },
                ),
              for (final field in choices)
                SelectField(
                  label: '${field['label']} for this rate',
                  value:
                      (rate['selectors'] as Map)[field['id']] as String? ?? '',
                  options: {
                    '': 'Any selection',
                    for (final c
                        in (field['choices'] as String)
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty))
                      c: c,
                  },
                  onChanged: (v) {
                    final selectors = rate['selectors'] as Map<String, dynamic>;
                    if (v.isEmpty) {
                      selectors.remove(field['id']);
                    } else {
                      selectors[field['id'] as String] = v;
                    }
                    onChanged();
                  },
                ),
              if ((rate['selectors'] as Map).isNotEmpty)
                TextButton(
                  onPressed: () {
                    rate['selectors'] = <String, dynamic>{};
                    onChanged();
                  },
                  child: const Text('Clear variant filters'),
                ),
              if (rows.length > 1)
                TextButton.icon(
                  onPressed: () {
                    rows.remove(rate);
                    onChanged();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove rate'),
                ),
            ],
          ),
        if (choices.isNotEmpty || setup.kind == 'formula')
          TextButton.icon(
            onPressed: rows.length >= 50
                ? null
                : () {
                    rows.add({
                      'id': newPricingId(),
                      'key': 'base',
                      'amount': '',
                      'unit': '',
                      'selectors': <String, dynamic>{},
                    });
                    onChanged();
                  },
            icon: const Icon(Icons.add),
            label: Text(
              setup.kind == 'formula'
                  ? 'Add rate variable'
                  : 'Add variant rate',
            ),
          ),
      ],
    );
  }
}

class ComponentsEditor extends StatelessWidget {
  const ComponentsEditor({
    super.key,
    required this.rows,
    required this.variables,
    required this.onChanged,
  });
  final List<Map<String, dynamic>> rows;
  final Map<String, String> variables;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final row in rows)
        ExpansionTile(
          key: ValueKey('component-${row['id']}'),
          initiallyExpanded: true,
          tilePadding: EdgeInsets.zero,
          title: Text(
            (row['name'] as String).isEmpty
                ? 'New charge'
                : row['name'] as String,
          ),
          children: [
            FormSection(
              'Charge settings',
              children: [
                ValueField(
                  label: 'Charge name',
                  value: row['name'] as String,
                  onChanged: (v) {
                    row['name'] = v;
                    onChanged();
                  },
                ),
                SelectField(
                  label: 'Charge basis',
                  value: row['type'] as String,
                  options: const {
                    'perItem': 'Fixed per item',
                    'perOrder': 'Fixed per order',
                    'area': 'Per area',
                    'linear': 'Per length',
                    'weight': 'Per weight',
                    'quantity': 'Component quantity',
                  },
                  onChanged: (v) {
                    row['type'] = v;
                    row['unit'] = switch (v) {
                      'area' => 'ft2',
                      'linear' => 'm',
                      'weight' => 'kg',
                      _ => 'piece',
                    };
                    row['measure'] = switch (v) {
                      'area' => opDraft(
                        'multiply',
                        refDraft('height'),
                        refDraft('width'),
                      ),
                      'linear' => refDraft('length'),
                      'weight' => refDraft('weight'),
                      _ => literalDraft('1', 'piece'),
                    };
                    onChanged();
                  },
                ),
                ValueField(
                  label: 'Charge rate',
                  value: row['amount'] as String,
                  numeric: true,
                  onChanged: (v) {
                    row['amount'] = v;
                    onChanged();
                  },
                ),
                if (!['perItem', 'perOrder'].contains(row['type'])) ...[
                  SelectField(
                    label: 'Charge unit',
                    value: row['unit'] as String,
                    options: unitLabels,
                    onChanged: (v) {
                      row['unit'] = v;
                      onChanged();
                    },
                  ),
                  const MessageLine(
                    'Use the configured numeric inputs to calculate this charge’s measure.',
                  ),
                  ExpressionEditor(
                    node: row['measure'] as Map<String, dynamic>,
                    variables: variables,
                    onChanged: onChanged,
                  ),
                ],
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Seller may choose this charge'),
                  value: row['optional'] as bool,
                  onChanged: (v) {
                    row['optional'] = v;
                    onChanged();
                  },
                ),
                if (row['optional'] == true)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Selected by default'),
                    value: row['selected'] as bool,
                    onChanged: (v) {
                      row['selected'] = v;
                      onChanged();
                    },
                  ),
                TextButton.icon(
                  onPressed: () {
                    rows.remove(row);
                    onChanged();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove charge'),
                ),
              ],
            ),
          ],
        ),
      TextButton.icon(
        onPressed: rows.length >= 16
            ? null
            : () {
                rows.add(ProductSetup.componentDraft());
                onChanged();
              },
        icon: const Icon(Icons.add),
        label: const Text('Add charge'),
      ),
    ],
  );
}
