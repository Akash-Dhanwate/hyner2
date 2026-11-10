import '../exact.dart';
import '../pricing_models.dart' show validateId, validateName;
import 'formulas.dart';
import 'inputs.dart';
import 'rates.dart';
import 'units.dart';

enum StrategyKind {
  perUnit,
  area,
  linear,
  weight,
  volume,
  packaging,
  sizeSlab,
  quantityTier,
  component,
  formula,
}

final class StrategyContext {
  const StrategyContext(this.schema, this.rates, this.inputs, this.quantity);
  final InputSchema schema;
  final RateLookup rates;
  final ValidatedInputs inputs;
  final int quantity;
  Map<String, MeasuredValue> symbols(FormulaProgram program) {
    final values = <String, MeasuredValue>{
      ...inputs.numbers,
      'quantity': MeasuredValue(
        Exact.integer(quantity),
        MeasureDimension.scalar,
      ),
    };
    for (final ref in program.externalReferences.where(
      (r) => r.startsWith('rate:'),
    )) {
      values[ref] = rates.asFormulaValue(
        rates.resolve(ref.substring(5), inputs),
      );
    }
    return values;
  }
}

Map<String, MeasureDimension> formulaTypes(
  InputSchema schema,
  RateLookup rates,
) => {
  ...schema.numericTypes,
  'quantity': MeasureDimension.scalar,
  for (final key in rates.keys)
    'rate:$key':
        MeasureDimension.money(rates.currency.code) / rates.dimension(key),
};

final class StrategyCharge {
  StrategyCharge({
    required this.label,
    required this.amount,
    required this.measured,
    required this.billable,
    required this.unit,
    String? measuredUnit,
    List<SellingRate> rates = const [],
    this.perOrder = false,
    List<String> policies = const [],
  }) : measuredUnit = measuredUnit ?? unit,
       rates = List.unmodifiable(rates),
       policies = List.unmodifiable(policies);
  final String label;
  final Exact amount;
  final Exact measured;
  final Exact billable;
  final String unit;
  final String measuredUnit;
  final List<SellingRate> rates;
  final bool perOrder;
  final List<String> policies;
  StrategyCharge withScope(String prefix, bool order) => StrategyCharge(
    label: '$prefix / $label',
    amount: amount,
    measured: measured,
    billable: billable,
    unit: unit,
    measuredUnit: measuredUnit,
    rates: rates,
    perOrder: perOrder || order,
    policies: policies,
  );
  Map<String, Object?> toJson() => {
    'label': label,
    'amount': '$amount',
    'measured': '$measured',
    'billable': '$billable',
    'unit': unit,
    'measuredUnit': measuredUnit,
    'rates': rates.map((r) => r.toJson()).toList(),
    'perOrder': perOrder,
    'policies': policies,
  };
}

final class BillableQuantityPolicy {
  BillableQuantityPolicy({
    required this.unit,
    Exact? minimum,
    this.increment,
    Exact? wastePercent,
    Exact? minimumCharge,
  }) : minimum = minimum ?? Exact.zero,
       wastePercent = wastePercent ?? Exact.zero,
       minimumCharge = minimumCharge ?? Exact.zero {
    if (this.minimum < Exact.zero ||
        (increment != null && increment! <= Exact.zero) ||
        this.wastePercent < Exact.zero ||
        this.wastePercent > Exact.integer(100) ||
        this.minimumCharge < Exact.zero) {
      throw ArgumentError('Invalid billable quantity rules');
    }
  }
  final String unit;
  final Exact minimum;
  final Exact? increment;
  final Exact wastePercent;
  final Exact minimumCharge;
  Exact billing(Exact value) {
    final v = (value * (Exact.one + wastePercent / Exact.integer(100))).max(
      minimum,
    );
    return increment == null ? v : v.ceilTo(increment!);
  }

  List<String> get descriptions => [
    if (wastePercent != Exact.zero) 'Wastage: $wastePercent%',
    if (minimum != Exact.zero) 'Minimum: $minimum $unit',
    if (increment != null) 'Round upward: $increment $unit',
    if (minimumCharge != Exact.zero) 'Minimum charge: $minimumCharge',
  ];
  Map<String, Object?> toJson() => {
    'unit': unit,
    'minimum': '$minimum',
    'increment': increment?.toString(),
    'wastePercent': '$wastePercent',
    'minimumCharge': '$minimumCharge',
  };
  factory BillableQuantityPolicy.fromJson(Map<String, dynamic> j) =>
      BillableQuantityPolicy(
        unit: j['unit'] as String,
        minimum: Exact.parse(j['minimum'] as String),
        increment: j['increment'] == null
            ? null
            : Exact.parse(j['increment'] as String),
        wastePercent: Exact.parse(j['wastePercent'] as String),
        minimumCharge: Exact.parse(j['minimumCharge'] as String),
      );
}

/// Each strategy returns per-item and/or once-per-order selling contributions.
/// Quantity multiplication, discounts and tax have one shared downstream path.
sealed class PricingStrategy {
  const PricingStrategy();
  StrategyKind get kind;
  void validate(InputSchema schema, RateLookup rates);
  List<StrategyCharge> calculate(StrategyContext context);
  Map<String, Object?> toJson();
  factory PricingStrategy.fromJson(Map<String, dynamic> j) {
    var nodes = 0;
    PricingStrategy parse(Map<String, dynamic> node, int depth) {
      if (++nodes > 256 || depth > 16) {
        throw const FormatException('Strategy exceeds composition limits');
      }
      final kind = StrategyKind.values.byName(node['kind'] as String);
      switch (kind) {
        case StrategyKind.perUnit:
        case StrategyKind.area:
        case StrategyKind.linear:
        case StrategyKind.weight:
        case StrategyKind.volume:
          return MeasuredRateStrategy(
            kind: kind,
            measure: FormulaProgram.fromJson(
              node['measure'] as Map<String, dynamic>,
            ),
            rateKey: node['rateKey'] as String,
            policy: BillableQuantityPolicy.fromJson(
              node['policy'] as Map<String, dynamic>,
            ),
          );
        case StrategyKind.packaging:
          return PackageStrategy(
            measure: FormulaProgram.fromJson(
              node['measure'] as Map<String, dynamic>,
            ),
            requestedUnit: node['requestedUnit'] as String,
            packageUnit: node['packageUnit'] as String,
            rateKey: node['rateKey'] as String,
            policy: BillableQuantityPolicy.fromJson(
              node['policy'] as Map<String, dynamic>,
            ),
          );
        case StrategyKind.sizeSlab:
          return SizeSlabStrategy(
            bands: (node['bands'] as List)
                .map((e) => SizeBand.fromJson(e as Map<String, dynamic>))
                .toList(),
          );
        case StrategyKind.quantityTier:
          return QuantityTierStrategy(
            (node['tiers'] as List)
                .map(
                  (e) => QuantityTier(
                    (e as Map<String, dynamic>)['minimum'] as int,
                    parse(e['strategy'] as Map<String, dynamic>, depth + 1),
                  ),
                )
                .toList(),
          );
        case StrategyKind.component:
          return ComponentStrategy(
            (node['components'] as List)
                .map(
                  (e) => PriceComponent(
                    id: e['id'] as String,
                    label: e['label'] as String,
                    strategy: parse(
                      e['strategy'] as Map<String, dynamic>,
                      depth + 1,
                    ),
                    perOrder: e['perOrder'] as bool,
                    enabledBy: e['enabledBy'] as String?,
                  ),
                )
                .toList(),
          );
        case StrategyKind.formula:
          return FormulaPriceStrategy(
            FormulaProgram.fromJson(node['program'] as Map<String, dynamic>),
          );
      }
    }

    return parse(j, 0);
  }
}

final class MeasuredRateStrategy extends PricingStrategy {
  MeasuredRateStrategy({
    required this.kind,
    required this.measure,
    required this.rateKey,
    required this.policy,
  }) {
    if (![
      StrategyKind.perUnit,
      StrategyKind.area,
      StrategyKind.linear,
      StrategyKind.weight,
      StrategyKind.volume,
    ].contains(kind)) {
      throw ArgumentError('Not a measured-rate strategy');
    }
  }
  @override
  final StrategyKind kind;
  final FormulaProgram measure;
  final String rateKey;
  final BillableQuantityPolicy policy;
  @override
  void validate(InputSchema schema, RateLookup rates) {
    final dimension = measure.validate(formulaTypes(schema, rates));
    final expected = switch (kind) {
      StrategyKind.area => MeasureDimension.area,
      StrategyKind.linear => MeasureDimension.length,
      StrategyKind.weight => MeasureDimension.mass,
      StrategyKind.volume => MeasureDimension.volume,
      _ => dimension,
    };
    if (dimension != expected ||
        (kind == StrategyKind.perUnit && !dimension.isCommercialUnit)) {
      throw ArgumentError('Measure does not match pricing strategy');
    }
    final rateDimension = rates.dimension(rateKey);
    final commercialBridge =
        kind == StrategyKind.perUnit &&
        dimension.isCommercialUnit &&
        rateDimension.isCommercialUnit;
    if (schema.units.registry.require(policy.unit).dimension != dimension ||
        (rateDimension != dimension && !commercialBridge)) {
      throw ArgumentError('Rate, measure and billable policy units must agree');
    }
    for (final rate in rates.rates.where((r) => r.key == rateKey)) {
      schema.units.convert(Exact.one, policy.unit, rate.unit);
    }
  }

  @override
  List<StrategyCharge> calculate(StrategyContext context) {
    final quantity = measure.evaluate(context.symbols(measure));
    if (quantity.value <= Exact.zero) {
      throw ArgumentError('Calculated measure must be positive');
    }
    final unit = context.schema.units.registry.require(policy.unit);
    final measured = quantity.value / unit.canonicalFactor;
    final billable = policy.billing(measured);
    final rate = context.rates.resolve(rateKey, context.inputs);
    final priced =
        context.schema.units.convert(billable, policy.unit, rate.unit) *
        rate.amount;
    return [
      StrategyCharge(
        label: kind.name,
        amount: priced.max(policy.minimumCharge),
        measured: measured,
        billable: billable,
        unit: policy.unit,
        rates: [rate],
        policies: policy.descriptions,
      ),
    ];
  }

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'measure': measure.toJson(),
    'rateKey': rateKey,
    'policy': policy.toJson(),
  };
}

final class PackageStrategy extends PricingStrategy {
  const PackageStrategy({
    required this.measure,
    required this.requestedUnit,
    required this.packageUnit,
    required this.rateKey,
    required this.policy,
  });
  final FormulaProgram measure;
  final String requestedUnit;
  final String packageUnit;
  final String rateKey;

  /// Minimum/waste/increment are measured in requestedUnit before packing.
  final BillableQuantityPolicy policy;
  @override
  StrategyKind get kind => StrategyKind.packaging;
  @override
  void validate(InputSchema schema, RateLookup rates) {
    if (!schema.units.registry.require(packageUnit).dimension.isPackage) {
      throw ArgumentError('Choose a package unit');
    }
    if (measure.validate(formulaTypes(schema, rates)) !=
            schema.units.registry.require(requestedUnit).dimension ||
        policy.unit != requestedUnit) {
      throw ArgumentError('Package coverage and input units do not agree');
    }
    schema.units.convert(Exact.one, requestedUnit, packageUnit);
    if (!rates.dimension(rateKey).isPackage) {
      throw ArgumentError(
        'Package rate must price the configured package unit',
      );
    }
    for (final rate in rates.rates.where((r) => r.key == rateKey)) {
      schema.units.convert(Exact.one, packageUnit, rate.unit);
    }
  }

  @override
  List<StrategyCharge> calculate(StrategyContext context) {
    final canonical = measure.evaluate(context.symbols(measure));
    if (canonical.value <= Exact.zero) {
      throw ArgumentError('Package requirement must be positive');
    }
    final requested =
        canonical.value /
        context.schema.units.registry.require(requestedUnit).canonicalFactor;
    final adjusted = policy.billing(requested);
    final packs = context.schema.units
        .convert(adjusted, requestedUnit, packageUnit)
        .ceilTo(Exact.one);
    final rate = context.rates.resolve(rateKey, context.inputs);
    final price =
        context.schema.units.convert(packs, packageUnit, rate.unit) *
        rate.amount;
    return [
      StrategyCharge(
        label: 'packaging',
        amount: price.max(policy.minimumCharge),
        measured: requested,
        billable: packs,
        unit: packageUnit,
        measuredUnit: requestedUnit,
        rates: [rate],
        policies: [
          ...policy.descriptions,
          'Requested $requested $requestedUnit; whole $packageUnit packages rounded upward',
        ],
      ),
    ];
  }

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'measure': measure.toJson(),
    'requestedUnit': requestedUnit,
    'packageUnit': packageUnit,
    'rateKey': rateKey,
    'policy': policy.toJson(),
  };
}

final class SlabRange {
  SlabRange({
    required this.unit,
    required this.minimum,
    required this.maximum,
  }) {
    if (minimum >= maximum) throw ArgumentError('Size range must be nonempty');
  }
  final String unit;
  final Exact minimum;
  final Exact maximum;
  Map<String, Object?> toJson() => {
    'unit': unit,
    'minimum': '$minimum',
    'maximum': '$maximum',
  };
  factory SlabRange.fromJson(Map<String, dynamic> j) => SlabRange(
    unit: j['unit'] as String,
    minimum: Exact.parse(j['minimum'] as String),
    maximum: Exact.parse(j['maximum'] as String),
  );
}

final class SizeBand {
  SizeBand({
    required this.id,
    required Map<String, SlabRange> ranges,
    required this.rateKey,
  }) : ranges = Map.unmodifiable(ranges) {
    validateId(id);
    if (ranges.isEmpty) throw ArgumentError('A size slab needs ranges');
  }
  final String id;
  final Map<String, SlabRange> ranges;
  final String rateKey;
  Map<String, Object?> toJson() => {
    'id': id,
    'ranges': ranges.map((k, v) => MapEntry(k, v.toJson())),
    'rateKey': rateKey,
  };
  factory SizeBand.fromJson(Map<String, dynamic> j) => SizeBand(
    id: j['id'] as String,
    ranges: (j['ranges'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, SlabRange.fromJson(v as Map<String, dynamic>)),
    ),
    rateKey: j['rateKey'] as String,
  );
}

final class SizeSlabStrategy extends PricingStrategy {
  SizeSlabStrategy({required List<SizeBand> bands})
    : bands = List.unmodifiable(bands) {
    if (bands.isEmpty ||
        bands.length > 100 ||
        bands.map((b) => b.id).toSet().length != bands.length) {
      throw ArgumentError('Invalid size slabs');
    }
  }
  final List<SizeBand> bands;
  @override
  StrategyKind get kind => StrategyKind.sizeSlab;
  @override
  void validate(InputSchema schema, RateLookup rates) {
    for (final band in bands) {
      if (rates.dimension(band.rateKey) != MeasureDimension.scalar) {
        throw ArgumentError('Size slab needs a flat rate per number');
      }
      for (final range in band.ranges.entries) {
        if (schema.numericTypes[range.key] !=
            schema.units.registry.require(range.value.unit).dimension) {
          throw ArgumentError('Size slab needs compatible numeric fields');
        }
      }
    }
    for (var i = 0; i < bands.length; i++) {
      for (var j = i + 1; j < bands.length; j++) {
        final a = bands[i];
        final b = bands[j];
        var separated = false;
        for (final key in a.ranges.keys.where(b.ranges.containsKey)) {
          final x = a.ranges[key]!;
          final y = b.ranges[key]!;
          final min = schema.units.registry.convert(y.minimum, y.unit, x.unit);
          final max = schema.units.registry.convert(y.maximum, y.unit, x.unit);
          if (x.maximum <= min || max <= x.minimum) separated = true;
        }
        if (!separated) throw ArgumentError('Overlapping size slabs');
      }
    }
  }

  @override
  List<StrategyCharge> calculate(StrategyContext context) {
    final matches = bands
        .where(
          (band) => band.ranges.entries.every((r) {
            final value = context.inputs.numbers[r.key];
            if (value == null) {
              throw ArgumentError('Enter ${r.key} for size pricing');
            }
            final raw =
                value.value /
                context.schema.units.registry
                    .require(r.value.unit)
                    .canonicalFactor;
            return raw >= r.value.minimum && raw < r.value.maximum;
          }),
        )
        .toList();
    if (matches.length != 1) {
      throw StateError('No unique size slab fits the measurements');
    }
    final band = matches.single;
    final rate = context.rates.resolve(band.rateKey, context.inputs);
    final amount =
        rate.amount /
        context.schema.units.registry.require(rate.unit).canonicalFactor;
    return [
      StrategyCharge(
        label: 'Size slab ${band.id}',
        amount: amount,
        measured: Exact.one,
        billable: Exact.one,
        unit: 'number',
        rates: [rate],
        policies: [
          'Size intervals include the minimum and exclude the maximum',
        ],
      ),
    ];
  }

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'bands': bands.map((b) => b.toJson()).toList(),
  };
}

final class QuantityTier {
  QuantityTier(this.minimum, this.strategy) {
    if (minimum < 1 || minimum > 1000000) {
      throw ArgumentError('Invalid quantity threshold');
    }
  }
  final int minimum;
  final PricingStrategy strategy;
  Map<String, Object?> toJson() => {
    'minimum': minimum,
    'strategy': strategy.toJson(),
  };
}

final class QuantityTierStrategy extends PricingStrategy {
  QuantityTierStrategy(List<QuantityTier> tiers)
    : tiers = List.unmodifiable(
        [...tiers]..sort((a, b) => a.minimum.compareTo(b.minimum)),
      ) {
    if (tiers.isEmpty ||
        tiers.length > 100 ||
        this.tiers.first.minimum != 1 ||
        tiers.map((t) => t.minimum).toSet().length != tiers.length) {
      throw ArgumentError(
        'Quantity tiers must start at one with unique thresholds',
      );
    }
  }
  final List<QuantityTier> tiers;
  @override
  StrategyKind get kind => StrategyKind.quantityTier;
  @override
  void validate(InputSchema schema, RateLookup rates) {
    for (final t in tiers) {
      t.strategy.validate(schema, rates);
    }
  }

  @override
  List<StrategyCharge> calculate(StrategyContext context) => tiers
      .lastWhere((t) => t.minimum <= context.quantity)
      .strategy
      .calculate(context)
      .map(
        (c) => c.withScope(
          'All-units tier ${tiers.lastWhere((t) => t.minimum <= context.quantity).minimum}+',
          false,
        ),
      )
      .toList();
  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'tiers': tiers.map((t) => t.toJson()).toList(),
  };
}

final class PriceComponent {
  PriceComponent({
    required this.id,
    required this.label,
    required this.strategy,
    this.perOrder = false,
    this.enabledBy,
  }) {
    validateId(id);
    validateName(label);
  }
  final String id;
  final String label;
  final PricingStrategy strategy;
  final bool perOrder;
  final String? enabledBy;
  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'strategy': strategy.toJson(),
    'perOrder': perOrder,
    'enabledBy': enabledBy,
  };
}

final class ComponentStrategy extends PricingStrategy {
  ComponentStrategy(List<PriceComponent> components)
    : components = List.unmodifiable(components) {
    if (components.isEmpty ||
        components.length > 32 ||
        components.map((c) => c.id).toSet().length != components.length) {
      throw ArgumentError('Invalid kit components');
    }
  }
  final List<PriceComponent> components;
  @override
  StrategyKind get kind => StrategyKind.component;
  @override
  void validate(InputSchema schema, RateLookup rates) {
    for (final c in components) {
      if (c.enabledBy != null &&
          !schema.fields.any(
            (f) => f.id == c.enabledBy && f.type == InputDataType.boolean,
          )) {
        throw ArgumentError('Component visibility requires a boolean input');
      }
      c.strategy.validate(schema, rates);
    }
  }

  @override
  List<StrategyCharge> calculate(StrategyContext context) => [
    for (final c in components)
      if (c.enabledBy == null ||
          (context.inputs.values[c.enabledBy] is BooleanInput &&
              (context.inputs.values[c.enabledBy] as BooleanInput).value))
        ...c.strategy
            .calculate(context)
            .map((charge) => charge.withScope(c.label, c.perOrder)),
  ];
  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'components': components.map((c) => c.toJson()).toList(),
  };
}

final class FormulaPriceStrategy extends PricingStrategy {
  const FormulaPriceStrategy(this.program);
  final FormulaProgram program;
  @override
  StrategyKind get kind => StrategyKind.formula;
  @override
  void validate(InputSchema schema, RateLookup rates) {
    if (program.validate(formulaTypes(schema, rates)) !=
        MeasureDimension.money(rates.currency.code)) {
      throw ArgumentError(
        'Custom price formula must produce selling money in the profile currency',
      );
    }
  }

  @override
  List<StrategyCharge> calculate(StrategyContext context) {
    final result = program.evaluate(context.symbols(program));
    if (result.value < Exact.zero) {
      throw ArgumentError('Formula produced a negative selling price');
    }
    final keys =
        program.externalReferences
            .where((s) => s.startsWith('rate:'))
            .map((s) => s.substring(5))
            .toList()
          ..sort();
    return [
      StrategyCharge(
        label: 'Custom formula v${program.version}',
        amount: result.value,
        measured: Exact.one,
        billable: Exact.one,
        unit: 'number',
        rates: keys
            .map((key) => context.rates.resolve(key, context.inputs))
            .toList(),
      ),
    ];
  }

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'program': program.toJson(),
  };
}
