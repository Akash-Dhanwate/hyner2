import '../domain/exact.dart';
import '../domain/pricing_models.dart';
import '../domain/serialization.dart';
import '../domain/universal/rate_card.dart';
import 'product_setup.dart';

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
