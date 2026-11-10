import 'dart:async';

import 'package:flutter/material.dart';

import '../application/calculator_session.dart';
import '../application/product_setup.dart';
import '../application/workspace.dart';
import '../domain/exact.dart';
import '../domain/pricing_models.dart';
import '../domain/universal/rate_card.dart';
import 'pricing_widgets.dart';
import 'rule_editors.dart';

class ProductSetupScreen extends StatefulWidget {
  const ProductSetupScreen({
    super.key,
    required this.workspace,
    required this.setup,
    required this.storageKey,
    required this.currency,
    required this.categories,
    required this.onSave,
  });
  final QuickPriceWorkspace workspace;
  final ProductSetup setup;
  final String storageKey;
  final Currency currency;
  final List<PricingCategory> categories;
  final Future<void> Function(UniversalProduct, ProductSetup) onSave;
  @override
  State<ProductSetupScreen> createState() => _ProductSetupScreenState();
}

class _ProductSetupScreenState extends State<ProductSetupScreen> {
  late final setup = widget.setup;
  late final writer = DraftWriter(widget.workspace.values);
  final preview = CalculatorSession();
  String? error;
  bool saving = false, saveFailed = false;
  int get step => setup.data['step'] as int;
  Map<String, dynamic> get data => setup.data;
  Map<String, String> get variables => {
    for (final f
        in setup
            .rows('fields')
            .where((f) => ['decimal', 'integer'].contains(f['type'])))
      f['id'] as String: '${f['label']} (${f['id']})',
    for (final r in setup.rows('rates'))
      'rate:${r['key']}': 'Rate: ${r['key']}',
  };
  @override
  void initState() {
    super.initState();
    if (step == 2) {
      try {
        preview.select(
          setup.compile(widget.workspace.businessId, widget.currency),
        );
        if (data['preview'] is Map<String, dynamic>) {
          preview.restore(data['preview'] as Map<String, dynamic>);
        }
      } catch (_) {
        data['step'] = 1;
      }
    }
    preview.addListener(_previewChanged);
  }

  @override
  void dispose() {
    preview.removeListener(_previewChanged);
    preview.dispose();
    super.dispose();
  }

  void _persist() {
    unawaited(
      writer
          .write(widget.storageKey, data)
          .then((_) {
            if (mounted && saveFailed) setState(() => saveFailed = false);
          })
          .catchError((Object e) {
            if (mounted) {
              setState(() {
                saveFailed = true;
                error = 'Draft could not be saved. ${pricingError(e)}';
              });
            }
          }),
    );
  }

  void _changed() {
    setState(() => error = null);
    _persist();
  }

  void _previewChanged() {
    data['preview'] = preview.toJson();
    if (mounted) setState(() {});
    _persist();
  }

  void _set(String key, dynamic value) {
    data[key] = value;
    _changed();
  }

  Widget _text(
    String key,
    String label, {
    bool numeric = false,
    String? helper,
  }) => ValueField(
    key: ValueKey('setup-$key'),
    label: label,
    value: data[key] as String? ?? '',
    numeric: numeric,
    helper: helper,
    onChanged: (v) => _set(key, v),
  );
  void _next() {
    FocusScope.of(context).unfocus();
    try {
      if (step == 0) validateName(data['name'] as String);
      if (step == 1) {
        preview.select(
          setup.compile(widget.workspace.businessId, widget.currency),
        );
        if (data['preview'] is Map<String, dynamic>) {
          preview.restore(data['preview'] as Map<String, dynamic>);
        }
      }
      _set('step', step + 1);
    } catch (e) {
      setState(() => error = pricingError(e));
    }
  }

  Future<void> _save() async {
    if (saving || preview.result == null) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await writer.write(widget.storageKey, data);
      final product = setup.compile(
        widget.workspace.businessId,
        widget.currency,
      );
      await widget.onSave(product, setup);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = pricingError(e);
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Product setup')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Step ${step + 1} of 3 · ${['Product', 'Pricing', 'Preview'][step]}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: (step + 1) / 3),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  key: ValueKey('setup-step-$step'),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    if (error != null) MessageLine(error!, error: true),
                    if (step == 0) ..._product(),
                    if (step == 1) ..._pricing(),
                    if (step == 2) ...[
                      const FormSection(
                        'Try a real size',
                        subtitle: 'Check a sample price before saving this product to the draft rate card.',
                        children: [],
                      ),
                      DynamicInputs(session: preview),
                      QuantityControl(session: preview),
                      const SizedBox(height: 16),
                      PricePanel(session: preview),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      saveFailed
                          ? 'Draft not saved'
                          : widget.workspace.preview
                          ? 'Temporary browser draft'
                          : 'Draft saves on this device',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (step > 0) ...[
                          OutlinedButton(
                            onPressed: saving
                                ? null
                                : () => _set('step', step - 1),
                            child: const Text('Back'),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: FilledButton(
                            onPressed: saving
                                ? null
                                : step < 2
                                ? _next
                                : preview.result == null
                                ? null
                                : _save,
                            child: Text(
                              saving
                                  ? 'Saving…'
                                  : step == 2
                                  ? 'Save product'
                                  : 'Continue',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _product() => [
    FormSection(
      'What do you sell?',
      children: [
        SelectField(
          label: 'Start from a template',
          value: data['template'] as String? ?? 'custom',
          options: const {
            'doors': 'Doors',
            'plywood': 'Plywood / sheets',
            'glass': 'Glass',
            'pipes': 'Pipes / sections',
            'steel': 'Steel by weight',
            'tiles': 'Tiles by package',
            'hardware': 'Hardware fittings',
            'custom': 'Choose my own method',
          },
          onChanged: (value) {
            data['template'] = value;
            if (value != 'custom') {
              setup.setKind(switch (value) {
                'pipes' => 'linear',
                'steel' => 'weight',
                'tiles' => 'packaging',
                'hardware' => 'perUnit',
                _ => 'area',
              });
              if (value == 'glass') {
                for (final field in setup.rows('fields')) {
                  field['unit'] = 'mm';
                  field['permitted'] = compatibleUnits('mm');
                }
                setup
                    .rows('fields')
                    .add(inputDraft('thickness', 'Thickness', 'mm'));
              }
              if (value == 'pipes') {
                setup
                    .rows('fields')
                    .add(inputDraft('diameter', 'Diameter', 'mm'));
              }
            }
            _changed();
          },
        ),
        const MessageLine(
          'Choose the template and method first. Changing the method resets draft inputs and rates.',
        ),
        _text('name', 'Product / category name'),
        SelectField(
          label: 'Pricing method',
          value: setup.kind,
          options: strategyLabels,
          onChanged: (v) {
            setup.setKind(v);
            _changed();
          },
        ),
        SelectField(
          label: 'Category',
          value: data['categoryId'] as String,
          options: {
            '': 'Create a category',
            for (final c in widget.categories) c.id: c.name,
          },
          onChanged: (v) => _set('categoryId', v),
        ),
        if (data['categoryId'] == '') ...[
          _text(
            'categoryName',
            'Category name (optional)',
            helper: 'Uses the product name when left blank.',
          ),
          SelectField(
            label: 'Parent category',
            value: data['parentId'] as String,
            options: {
              '': 'No parent',
              for (final c in widget.categories) c.id: c.name,
            },
            onChanged: (v) => _set('parentId', v),
          ),
        ],
      ],
    ),
    if (setup.kind == 'quantityTier')
      FormSection(
        'Tier pricing basis',
        children: [
          SelectField(
            label: 'Apply quantity tiers to',
            value: data['tierBasis'] as String,
            options: {
              for (final key in [
                'perUnit',
                'area',
                'linear',
                'weight',
                'volume',
              ])
                key: strategyLabels[key]!,
            },
            onChanged: (v) {
              setup.setBasis(v);
              _changed();
            },
          ),
        ],
      ),
    FormSection(
      'Seller inputs',
      subtitle: 'These fields appear automatically in QuickPrice. Use matching variable IDs to preserve measurements when switching products.',
      children: [
        InputSchemaEditor(fields: setup.rows('fields'), onChanged: _changed),
      ],
    ),
  ];

  Map<String, String> get _rateUnits {
    final kind = setup.kind == 'quantityTier' ? data['tierBasis'] : setup.kind;
    final ids = switch (kind) {
      'area' => ['ft2', 'm2', 'in2', 'cm2'],
      'linear' => ['ft', 'm', 'in', 'mm', 'cm', 'yd'],
      'weight' => ['kg', 'g', 'tonne', 'lb'],
      'volume' => ['m3', 'ft3', 'litre', 'ml'],
      'packaging' => ['box', 'bag', 'carton', 'roll', 'bucket', 'pack'],
      'perUnit' => [
        'piece',
        'item',
        'pair',
        'set',
        'box',
        'bag',
        'carton',
        'roll',
        'bucket',
        'pack',
      ],
      _ => unitLabels.keys.toList(),
    };
    return {for (final id in ids) id: unitLabels[id]!};
  }

  List<Widget> _pricing() => [
    if (!['sizeSlab', 'component'].contains(setup.kind))
      FormSection(
        'Rate unit',
        children: [
          SelectField(
            label: 'Sell by',
            value: data['rateUnit'] as String,
            options: _rateUnits,
            onChanged: (v) {
              data['rateUnit'] = v;
              if (setup.kind == 'packaging') data['packageUnit'] = v;
              _changed();
            },
          ),
        ],
      ),
    if (!['sizeSlab', 'quantityTier', 'component'].contains(setup.kind))
      RatesEditor(setup: setup, onChanged: _changed),
    if (setup.kind == 'packaging')
      FormSection(
        'Package coverage',
        subtitle: 'QuickPrice rounds the requirement up to whole packages.',
        children: [
          SelectField(
            label: 'Coverage unit',
            value: data['requestedUnit'] as String,
            options: unitLabels,
            onChanged: (v) => _set('requestedUnit', v),
          ),
          _text(
            'coverage',
            'Coverage in one ${data['packageUnit']}',
            numeric: true,
          ),
        ],
      ),
    if (setup.kind == 'quantityTier') _tiers(),
    if (setup.kind == 'sizeSlab') _bands(),
    if (setup.kind == 'component')
      FormSection(
        'Kit components',
        children: [
          ComponentsEditor(
            rows: setup.rows('components'),
            variables: variables,
            onChanged: _changed,
          ),
        ],
      ),
    if (setup.kind == 'formula')
      FormSection(
        'Price formula',
        subtitle: 'Return the price for one item in the profile currency. Order quantity is applied afterwards.',
        children: [
          ExpressionEditor(
            node: data['formula'] as Map<String, dynamic>,
            variables: variables,
            onChanged: _changed,
          ),
        ],
      ),
    if (!['perUnit', 'sizeSlab', 'component', 'formula'].contains(setup.kind))
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Measured quantity expression'),
        children: [
          ExpressionEditor(
            node: data['measure'] as Map<String, dynamic>,
            variables: variables,
            onChanged: _changed,
          ),
        ],
      ),
    if (!['sizeSlab', 'component', 'formula'].contains(setup.kind))
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Minimums, rounding and wastage'),
        children: [
          FormSection(
            'Billing policy',
            subtitle:
                'Quantities use ${unitLabels[setup.kind == 'packaging' ? data['requestedUnit'] : data['rateUnit']]} before pricing.',
            children: [
              _text('minimum', 'Minimum billable measure', numeric: true),
              _text('increment', 'Round measure upward by', numeric: true),
              _text('waste', 'Wastage percentage', numeric: true),
              _text(
                'minimumCharge',
                'Minimum base charge per item',
                numeric: true,
              ),
            ],
          ),
        ],
      ),
    ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Accessories and services'),
      subtitle: Text('${setup.rows('extras').length} configured'),
      children: [
        ComponentsEditor(
          rows: setup.rows('extras'),
          variables: variables,
          onChanged: _changed,
        ),
      ],
    ),
    ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Automatic discount'),
      children: [
        FormSection(
          'Approved discount',
          children: [
            _text('discountThreshold', 'Minimum order quantity', numeric: true),
            _text('discountPercent', 'Percentage discount', numeric: true),
            _text('discountFixed', 'Fixed discount per line', numeric: true),
          ],
        ),
      ],
    ),
    ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Purchase / inventory conversions'),
      subtitle: const Text('Product-specific conversion rules'),
      children: [_conversions()],
    ),
    FormSection(
      'Tax and money rounding',
      children: [
        SelectField(
          label: 'Tax treatment',
          value: data['taxBehavior'] as String,
          options: const {
            'exempt': 'No tax charged',
            'exclusive': 'Add tax to the selling price',
            'inclusive': 'Tax is included in the selling price',
          },
          onChanged: (v) => _set('taxBehavior', v),
        ),
        if (data['taxBehavior'] != 'exempt' && data['taxBehavior'] != '')
          _text(
            'taxPercent',
            'Applicable tax percentage',
            numeric: true,
            helper:
                'Enter the rate approved for this product in your business.',
          ),
        SelectField(
          label: 'Final money rounding',
          value: data['rounding'] as String,
          options: const {
            'halfUp': 'Nearest minor unit · half up',
            'halfEven': 'Nearest minor unit · half even',
            'down': 'Round down to minor unit',
          },
          onChanged: (v) => _set('rounding', v),
        ),
      ],
    ),
  ];

  Widget _tiers() => FormSection(
    'Quantity rate schedule',
    subtitle: 'Each threshold prices every item in that order. The first threshold must be 1.',
    children: [
      for (final row in setup.rows('tiers'))
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueField(
              label: 'From quantity',
              value: row['minimum'] as String,
              numeric: true,
              onChanged: (v) {
                row['minimum'] = v;
                _changed();
              },
            ),
            const SizedBox(height: 8),
            ValueField(
              label: 'Rate at this quantity',
              value: row['amount'] as String,
              numeric: true,
              onChanged: (v) {
                row['amount'] = v;
                _changed();
              },
            ),
            if (setup.rows('tiers').length > 1)
              TextButton(
                onPressed: () {
                  setup.rows('tiers').remove(row);
                  _changed();
                },
                child: const Text('Remove tier'),
              ),
          ],
        ),
      TextButton.icon(
        onPressed: () {
          setup.rows('tiers').add({
            'id': newPricingId(),
            'minimum': '',
            'amount': '',
          });
          _changed();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add quantity tier'),
      ),
    ],
  );
  Widget _bands() => FormSection(
    'Size bands',
    subtitle: 'Lower bounds are included; upper bounds are excluded. A size must match exactly one band.',
    children: [
      for (final (index, row) in setup.rows('bands').indexed)
        ExpansionTile(
          initiallyExpanded: true,
          tilePadding: EdgeInsets.zero,
          title: Text('Band ${index + 1}'),
          children: [
            for (final field
                in setup
                    .rows('fields')
                    .where(
                      (f) => ['decimal', 'integer'].contains(f['type']),
                    )) ...[
              Builder(
                builder: (context) {
                  final ranges = row['ranges'] as Map<String, dynamic>;
                  final range = ranges.putIfAbsent(
                    field['id'] as String,
                    () => <String, dynamic>{'min': '', 'max': ''},
                  ) as Map<String, dynamic>;
                  return FormSection(
                    '${field['label']} (${field['unit']})',
                    children: [
                      ValueField(
                        label: 'From (included)',
                        value: range['min'] as String,
                        numeric: true,
                        onChanged: (v) {
                          range['min'] = v;
                          _changed();
                        },
                      ),
                      ValueField(
                        label: 'Below (excluded)',
                        value: range['max'] as String,
                        numeric: true,
                        onChanged: (v) {
                          range['max'] = v;
                          _changed();
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
            ValueField(
              label: 'Price for this size band',
              value: row['amount'] as String,
              numeric: true,
              onChanged: (v) {
                row['amount'] = v;
                _changed();
              },
            ),
            TextButton(
              onPressed: () {
                setup.rows('bands').remove(row);
                _changed();
              },
              child: const Text('Remove band'),
            ),
          ],
        ),
      TextButton.icon(
        onPressed: () {
          setup.rows('bands').add({
            'id': newPricingId(),
            'amount': '',
            'ranges': <String, dynamic>{},
          });
          _changed();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add size band'),
      ),
    ],
  );
  Widget _conversions() => FormSection(
    'Unit conversions',
    subtitle: 'Declare what one purchase or stock unit contains. Unrelated physical units cannot be converted directly.',
    children: [
      for (final row in setup.rows('conversions'))
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectField(
              label: 'One unit of',
              value: row['from'] as String,
              options: unitLabels,
              onChanged: (v) {
                row['from'] = v;
                _changed();
              },
            ),
            const SizedBox(height: 8),
            ValueField(
              label: 'Contains this quantity',
              value: row['factor'] as String,
              numeric: true,
              onChanged: (v) {
                row['factor'] = v;
                _changed();
              },
            ),
            const SizedBox(height: 8),
            SelectField(
              label: 'Of unit',
              value: row['to'] as String,
              options: unitLabels,
              onChanged: (v) {
                row['to'] = v;
                _changed();
              },
            ),
            TextButton(
              onPressed: () {
                setup.rows('conversions').remove(row);
                _changed();
              },
              child: const Text('Remove conversion'),
            ),
          ],
        ),
      TextButton.icon(
        onPressed: () {
          setup.rows('conversions').add({
            'from': 'box',
            'to': 'piece',
            'factor': '',
          });
          _changed();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add conversion'),
      ),
      for (final role in ['selling', 'purchase', 'inventory', 'display'])
        SelectField(
          label: '$role unit (optional)',
          value: (data['roles'] as Map)[role] as String? ?? '',
          options: {'': 'Not specified', ...unitLabels},
          onChanged: (v) {
            final roles = data['roles'] as Map<String, dynamic>;
            if (v.isEmpty) {
              roles.remove(role);
            } else {
              roles[role] = v;
            }
            _changed();
          },
        ),
    ],
  );
}
