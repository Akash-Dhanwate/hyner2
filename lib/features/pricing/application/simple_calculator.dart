import '../domain/exact.dart';
import '../domain/pricing_models.dart';
import '../domain/serialization.dart';
import '../domain/universal/rate_card.dart';
import '../domain/universal/universal_pricing.dart';
import 'product_setup.dart';

const simpleVarietyField = 'quickprice_variety';

/// Read the simple editor's variety schedule from the durable published rule,
/// rather than relying on optional editor metadata being present.
List<Map<String, dynamic>> simpleVarieties(UniversalProduct product) {
  final base = product.rule.rateLookup.rates.where((r) => r.key == 'base');
  final field = product.rule.schema.fields
      .where((f) => f.id == simpleVarietyField)
      .firstOrNull;
  if (base.where((r) => r.selectors.isEmpty).length != 1) {
    throw StateError('Use Advanced settings to edit this rate schedule.');
  }
  if (field == null) return [];
  if (base.any(
    (r) =>
        r.selectors.isNotEmpty &&
        (r.selectors.length != 1 ||
            !r.selectors.containsKey(simpleVarietyField)),
  )) {
    throw StateError('Use Advanced settings to edit this rate schedule.');
  }
  if (field.type != InputDataType.choice || field.visibleWhen != null) {
    throw StateError('Use Advanced settings to edit this variety field.');
  }
  final fallback = base.singleWhere((r) => r.selectors.isEmpty);
  return [
    for (final choice in field.choices)
      (() {
        final rates = base.where(
          (r) => r.selectors[simpleVarietyField] == choice,
        );
        if (rates.length != 1 || rates.single.unit != fallback.unit) {
          throw StateError(
            'Use Advanced settings to edit this variety schedule.',
          );
        }
        final rate = rates.single;
        return <String, dynamic>{
          'id': rate.id,
          'name': choice,
          'amount': '${rate.amount}',
        };
      })(),
  ];
}

void _validateVarieties(List<Map<String, dynamic>> varieties) {
  if (varieties.length > 100) throw ArgumentError('Use at most 100 varieties.');
  final names = <String>{};
  for (final variety in varieties) {
    final name = (variety['name'] as String).trim();
    validateId(variety['id'] as String);
    validateName(name);
    if (name.length > 120 || name.contains(',')) {
      throw ArgumentError(
        'Keep variety names within 120 characters without commas.',
      );
    }
    if (!names.add(name.toLowerCase())) {
      throw ArgumentError('Give each variety a different name.');
    }
    final amount = Exact.parse((variety['amount'] as String).trim());
    if (amount <= Exact.zero || amount > Exact.parse('1000000000000')) {
      throw ArgumentError(
        'Enter a selling rate greater than zero for $name (up to 1,000,000,000,000).',
      );
    }
  }
}

/// Keep advanced-editor metadata in step with the simple editor. No database
/// migration or new rule format is needed: choices and selected rates exist.
void configureSimpleVarieties(
  ProductSetup setup,
  List<Map<String, dynamic>> varieties,
) {
  _validateVarieties(varieties);
  setup.rows('fields').removeWhere((f) => f['id'] == simpleVarietyField);
  setup
      .rows('rates')
      .removeWhere(
        (r) =>
            r['key'] == 'base' &&
            (r['selectors'] as Map).containsKey(simpleVarietyField),
      );
  if (varieties.isEmpty) return;
  setup.rows('rates').first['amount'] = varieties.first['amount'];
  setup
      .rows('fields')
      .insert(
        0,
        inputDraft(simpleVarietyField, 'Variety', 'number')..addAll({
          'type': 'choice',
          'choices': varieties
              .map((v) => (v['name'] as String).trim())
              .join(','),
          'default': (varieties.first['name'] as String).trim(),
        }),
      );
  setup.rows('rates').addAll([
    for (final variety in varieties)
      {
        'id': variety['id'],
        'key': 'base',
        'amount': variety['amount'],
        'unit': '',
        'selectors': {simpleVarietyField: (variety['name'] as String).trim()},
      },
  ]);
}

/// Preserve the original strategy, dimensions, tax, discounts and add-ons.
/// Only this editor's own choice field and base-rate schedule are replaced.
UniversalProduct replaceSimpleVarieties(
  UniversalProduct product,
  String name,
  String amount,
  List<Map<String, dynamic>> varieties,
) {
  simpleVarieties(product);
  _validateVarieties(varieties);
  if (varieties.isNotEmpty &&
      product.rule.rateLookup.rates.any(
        (r) =>
            r.key == 'base' &&
            r.selectors.keys.any((key) => key != simpleVarietyField),
      )) {
    throw StateError(
      'Use Advanced settings to add varieties to this rate schedule.',
    );
  }
  final updated = replaceSimpleRate(
    product,
    name,
    varieties.isEmpty ? amount : varieties.first['amount'] as String,
  );
  final json = jsonObject(canonicalJson(updated.toJson()));
  final rule = json['rule'] as Map<String, dynamic>;
  final inputs = rule['inputs'] as List;
  inputs.removeWhere((f) => (f as Map)['id'] == simpleVarietyField);
  final rates = rule['rates'] as List;
  rates.removeWhere(
    (r) =>
        (r as Map)['key'] == 'base' &&
        (r['selectors'] as Map).containsKey(simpleVarietyField),
  );
  if (varieties.isNotEmpty) {
    inputs.insert(
      0,
      InputDefinition(
        id: simpleVarietyField,
        label: 'Variety',
        type: InputDataType.choice,
        dimension: MeasureDimension.scalar,
        defaultUnit: null,
        permittedUnits: [],
        defaultValue: ChoiceInput((varieties.first['name'] as String).trim()),
        choices: [for (final v in varieties) (v['name'] as String).trim()],
      ).toJson(),
    );
    final base = updated.rule.rateLookup.rates.singleWhere(
      (r) => r.key == 'base' && r.selectors.isEmpty,
    );
    rates.addAll([
      for (final v in varieties)
        SellingRate(
          id: v['id'] as String,
          key: 'base',
          amount: Exact.parse((v['amount'] as String).trim()),
          unit: base.unit,
          selectors: {simpleVarietyField: (v['name'] as String).trim()},
        ).toJson(),
    ]);
  }
  return UniversalProduct.fromJson(json);
}

const quickTemplates = {
  'doors': 'Doors',
  'plywood': 'Plywood / sheets',
  'glass': 'Glass',
  'pipes': 'Pipes',
  'steel': 'Steel',
  'tiles': 'Tiles',
  'hardware': 'Hardware fittings',
};

ProductSetup quickProduct(String template, {String? name}) {
  final setup = ProductSetup.create(
    kind: switch (template) {
      'pipes' => 'linear',
      'steel' => 'weight',
      'tiles' => 'packaging',
      'hardware' => 'perUnit',
      _ => 'area',
    },
  );
  setup.data['template'] = template;
  setup.data['name'] =
      name ??
      switch (template) {
        'doors' => 'Flush Door',
        'glass' => 'Glass',
        'plywood' => 'Plywood',
        'pipes' => 'Pipe',
        'steel' => 'Steel',
        'tiles' => 'Tile box',
        _ => 'Hardware item',
      };
  setup.data['taxBehavior'] = 'exempt';
  setup.data['rounding'] = 'halfUp';
  if (['doors', 'glass', 'plywood'].contains(template)) {
    for (final field in setup.rows('fields')) {
      field['unit'] = 'in';
      field['permitted'] = ['in', 'ft', 'mm', 'cm', 'm'];
    }
  }
  return setup;
}

/// Updating a selling rate preserves the category, tax, dimensions, add-ons,
/// discounts and every other approved policy. Publishing creates a new version.
UniversalProduct replaceSimpleRate(
  UniversalProduct product,
  String name,
  String amount,
) {
  validateName(name.trim());
  final value = Exact.parse(amount.trim());
  final bases = product.rule.rateLookup.rates
      .where((r) => r.key == 'base' && r.selectors.isEmpty)
      .toList();
  if (bases.length != 1) {
    throw StateError('Use advanced settings for variant or scheduled rates.');
  }
  final json = jsonObject(canonicalJson(product.toJson()));
  json['name'] = name.trim();
  final rule = json['rule'] as Map<String, dynamic>;
  for (final rate in rule['rates'] as List) {
    if (rate['id'] == bases.single.id) rate['amount'] = '$value';
  }
  return UniversalProduct.fromJson(json);
}
