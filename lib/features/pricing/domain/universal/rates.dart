import '../exact.dart';
import '../pricing_models.dart' show validateId;
import 'inputs.dart';
import 'units.dart';

final class SellingRate {
  SellingRate({
    required this.id,
    required this.key,
    required this.amount,
    required this.unit,
    Map<String, String> selectors = const {},
  }) : selectors = Map.unmodifiable(selectors) {
    validateId(id);
    validateId(key);
    if (amount < Exact.zero || amount > Exact.parse('1000000000000')) {
      throw ArgumentError('Selling rate is outside supported limits');
    }
  }
  final String id;
  final String key;
  final Exact amount;
  final String unit;
  final Map<String, String> selectors;
  Map<String, Object?> toJson() => {
    'id': id,
    'key': key,
    'amount': '$amount',
    'unit': unit,
    'selectors': selectors,
  };
  factory SellingRate.fromJson(Map<String, dynamic> j) => SellingRate(
    id: j['id'] as String,
    key: j['key'] as String,
    amount: Exact.parse(j['amount'] as String),
    unit: j['unit'] as String,
    selectors: Map<String, String>.from(j['selectors'] as Map),
  );
}

final class RateLookup {
  RateLookup(List<SellingRate> rates, this.schema, this.currency)
    : rates = List.unmodifiable(rates) {
    if (rates.length > 1000 ||
        rates.map((r) => r.id).toSet().length != rates.length) {
      throw ArgumentError('Duplicate or excessive rates');
    }
    for (final rate in rates) {
      schema.units.registry.require(rate.unit);
      for (final selector in rate.selectors.entries) {
        final field = schema.fields
            .where((f) => f.id == selector.key)
            .firstOrNull;
        if (field == null ||
            field.type != InputDataType.choice ||
            !field.choices.contains(selector.value)) {
          throw ArgumentError('Rate selector does not match input schema');
        }
      }
      for (final other in rates.where(
        (r) => r.id != rate.id && r.key == rate.key,
      )) {
        if (schema.units.registry.require(other.unit).dimension !=
            schema.units.registry.require(rate.unit).dimension) {
          throw ArgumentError('Rates for one key must use compatible units');
        }
        // Reject overlapping equal-specificity rules at configuration time.
        if (other.selectors.length == rate.selectors.length &&
            rate.selectors.entries.every(
              (e) =>
                  other.selectors[e.key] == null ||
                  other.selectors[e.key] == e.value,
            )) {
          throw ArgumentError('Ambiguous rate schedule');
        }
      }
    }
  }
  final List<SellingRate> rates;
  final InputSchema schema;
  final Currency currency;
  Set<String> get keys => rates.map((r) => r.key).toSet();
  MeasureDimension dimension(String key) {
    final matches = rates.where((r) => r.key == key);
    if (matches.isEmpty) throw ArgumentError('Missing rate schedule: $key');
    return schema.units.registry.require(matches.first.unit).dimension;
  }

  SellingRate resolve(String key, ValidatedInputs input) {
    final matches =
        rates
            .where(
              (r) =>
                  r.key == key &&
                  r.selectors.entries.every(
                    (e) =>
                        input.values[e.key] is ChoiceInput &&
                        (input.values[e.key] as ChoiceInput).value == e.value,
                  ),
            )
            .toList()
          ..sort((a, b) => b.selectors.length.compareTo(a.selectors.length));
    if (matches.isEmpty) {
      throw StateError(
        'No approved rate matches $key and the selected variant',
      );
    }
    if (matches.length > 1 &&
        matches[0].selectors.length == matches[1].selectors.length) {
      throw StateError('Ambiguous applicable selling rates');
    }
    return matches.first;
  }

  MeasuredValue asFormulaValue(SellingRate rate) {
    final unit = schema.units.registry.require(rate.unit);
    return MeasuredValue(
      rate.amount / unit.canonicalFactor,
      MeasureDimension.money(currency.code) / unit.dimension,
    );
  }
}
