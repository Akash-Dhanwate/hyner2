import '../exact.dart';
import '../pricing_models.dart'
    show DiscountPolicy, TaxPolicy, TaxBehavior, validateId;
import '../serialization.dart';
import 'inputs.dart';
import 'rates.dart';
import 'strategies.dart';
import 'units.dart';

final class InputBillingRule {
  InputBillingRule({
    required this.fieldId,
    required this.unit,
    Exact? minimum,
    this.increment,
  }) : minimum = minimum ?? Exact.zero {
    if (this.minimum < Exact.zero ||
        (increment != null && increment! <= Exact.zero)) {
      throw ArgumentError('Invalid input billing rule');
    }
  }
  final String fieldId;
  final String unit;
  final Exact minimum;
  final Exact? increment;
  Map<String, Object?> toJson() => {
    'fieldId': fieldId,
    'unit': unit,
    'minimum': '$minimum',
    'increment': increment?.toString(),
  };
  factory InputBillingRule.fromJson(Map<String, dynamic> j) => InputBillingRule(
    fieldId: j['fieldId'] as String,
    unit: j['unit'] as String,
    minimum: Exact.parse(j['minimum'] as String),
    increment: j['increment'] == null
        ? null
        : Exact.parse(j['increment'] as String),
  );
}

/// A validated calculation definition. Stage B will persist/publish this model.
/// Its presence in memory alone is not evidence of server authorization.
final class UniversalPricingRule {
  UniversalPricingRule({
    required this.businessId,
    required this.productId,
    required this.id,
    required this.version,
    required this.currency,
    required this.schema,
    required List<SellingRate> rates,
    required this.strategy,
    required this.tax,
    DiscountPolicy? discount,
    this.rounding = MoneyRounding.halfUp,
    required this.effectiveAt,
    this.expiresAt,
    List<InputBillingRule> inputBilling = const [],
    List<PriceComponent> extras = const [],
  }) : rateLookup = RateLookup(rates, schema, currency),
       discount = discount ?? DiscountPolicy(),
       inputBilling = List.unmodifiable(inputBilling),
       extras = List.unmodifiable(extras) {
    validateId(businessId);
    validateId(productId);
    validateId(id);
    if (version < 1 ||
        version > 2147483647 ||
        schema.units.productId != productId ||
        (expiresAt != null && !expiresAt!.isAfter(effectiveAt))) {
      throw ArgumentError('Invalid rule identity or effective dates');
    }
    if (extras.length > 32 ||
        extras.map((e) => e.id).toSet().length != extras.length) {
      throw ArgumentError('Invalid extras');
    }
    var nodes = 0;
    void inspect(PricingStrategy s, int depth) {
      if (++nodes > 256 || depth > 16) {
        throw ArgumentError('Strategy exceeds composition limits');
      }
      if (s is ComponentStrategy) {
        for (final c in s.components) {
          inspect(c.strategy, depth + 1);
        }
      }
      if (s is QuantityTierStrategy) {
        for (final t in s.tiers) {
          inspect(t.strategy, depth + 1);
        }
      }
    }

    inspect(strategy, 0);
    for (final e in extras) {
      inspect(e.strategy, 0);
    }
    strategy.validate(schema, rateLookup);
    if (extras.isNotEmpty) {
      ComponentStrategy(extras).validate(schema, rateLookup);
    }
    if (inputBilling.map((r) => r.fieldId).toSet().length !=
        inputBilling.length) {
      throw ArgumentError('Duplicate dimension billing rules');
    }
    for (final rule in inputBilling) {
      if (schema.numericTypes[rule.fieldId] !=
          schema.units.registry.require(rule.unit).dimension) {
        throw ArgumentError('Billing dimension is incompatible with input');
      }
    }
  }
  final String businessId;
  final String productId;
  final String id;
  final int version;
  final Currency currency;
  final InputSchema schema;
  final RateLookup rateLookup;
  final PricingStrategy strategy;
  final TaxPolicy tax;
  final DiscountPolicy discount;
  final MoneyRounding rounding;
  final DateTime effectiveAt;
  final DateTime? expiresAt;
  final List<InputBillingRule> inputBilling;
  final List<PriceComponent> extras;
  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'engineVersion': UniversalPricingEngine.version,
    'businessId': businessId,
    'productId': productId,
    'id': id,
    'version': version,
    'currency': currency.toJson(),
    'units': schema.units.toJson(),
    'inputs': schema.toJson(),
    'rates': rateLookup.rates.map((r) => r.toJson()).toList(),
    'strategy': strategy.toJson(),
    'tax': tax.toJson(),
    'discount': discount.toJson(),
    'rounding': rounding.name,
    'effectiveAt': effectiveAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'inputBilling': inputBilling.map((r) => r.toJson()).toList(),
    'extras': extras.map((e) => e.toJson()).toList(),
  };
  factory UniversalPricingRule.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != 1 ||
        j['engineVersion'] != UniversalPricingEngine.version) {
      throw const FormatException('Unsupported universal rule version');
    }
    final units = ProductUnitSystem.fromJson(
      j['units'] as Map<String, dynamic>,
    );
    final schema = InputSchema.fromJson(j['inputs'] as List, units);
    return UniversalPricingRule(
      businessId: j['businessId'] as String,
      productId: j['productId'] as String,
      id: j['id'] as String,
      version: j['version'] as int,
      currency: Currency.fromJson(j['currency'] as Map<String, dynamic>),
      schema: schema,
      rates: (j['rates'] as List)
          .map((e) => SellingRate.fromJson(e as Map<String, dynamic>))
          .toList(),
      strategy: PricingStrategy.fromJson(j['strategy'] as Map<String, dynamic>),
      tax: TaxPolicy.fromJson(j['tax'] as Map<String, dynamic>),
      discount: DiscountPolicy.fromJson(j['discount'] as Map<String, dynamic>),
      rounding: MoneyRounding.values.byName(j['rounding'] as String),
      effectiveAt: DateTime.parse(j['effectiveAt'] as String),
      expiresAt: j['expiresAt'] == null
          ? null
          : DateTime.parse(j['expiresAt'] as String),
      inputBilling: (j['inputBilling'] as List)
          .map((e) => InputBillingRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      extras: (j['extras'] as List)
          .map(
            (e) => PriceComponent(
              id: e['id'] as String,
              label: e['label'] as String,
              strategy: PricingStrategy.fromJson(
                e['strategy'] as Map<String, dynamic>,
              ),
              perOrder: e['perOrder'] as bool,
              enabledBy: e['enabledBy'] as String?,
            ),
          )
          .toList(),
    );
  }
}

final class UniversalPricingRequest {
  UniversalPricingRequest({
    required Map<String, InputValue> inputs,
    this.quantity = 1,
  }) : inputs = Map.unmodifiable(inputs) {
    if (quantity < 1 || quantity > 1000000) {
      throw ArgumentError('Quantity must be 1–1000000');
    }
  }
  final Map<String, InputValue> inputs;
  final int quantity;
  Map<String, Object?> toJson() => {
    'inputs': inputs.map((k, v) => MapEntry(k, v.toJson())),
    'quantity': quantity,
  };
  factory UniversalPricingRequest.fromJson(Map<String, dynamic> j) =>
      UniversalPricingRequest(
        inputs: (j['inputs'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, InputValue.fromJson(v as Map<String, dynamic>)),
        ),
        quantity: j['quantity'] as int,
      );
}

final class FinancialAmounts {
  const FinancialAmounts({
    required this.subtotal,
    required this.discount,
    required this.net,
    required this.tax,
    required this.total,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.netMinor,
    required this.taxMinor,
    required this.totalMinor,
  });
  final Exact subtotal, discount, net, tax, total;
  final BigInt subtotalMinor, discountMinor, netMinor, taxMinor, totalMinor;
  Map<String, Object?> toJson() => {
    'subtotal': '$subtotal',
    'discount': '$discount',
    'net': '$net',
    'tax': '$tax',
    'total': '$total',
    'subtotalMinor': '$subtotalMinor',
    'discountMinor': '$discountMinor',
    'netMinor': '$netMinor',
    'taxMinor': '$taxMinor',
    'totalMinor': '$totalMinor',
  };
}

final class DiscountCalculator {
  Exact calculate(Exact amount, int quantity, DiscountPolicy policy) {
    final discount = quantity >= policy.minimumQuantity
        ? amount * policy.percent / Exact.integer(100) + policy.fixedPerLine
        : Exact.zero;
    if (discount > amount) {
      throw StateError('Configured discount exceeds selling amount');
    }
    return discount;
  }
}

final class TaxCalculator {
  ({Exact net, Exact tax}) calculate(Exact amount, TaxPolicy policy) {
    final factor = policy.percent / Exact.integer(100);
    final net = policy.behavior == TaxBehavior.inclusive
        ? amount / (Exact.one + factor)
        : amount;
    return (
      net: net,
      tax: policy.behavior == TaxBehavior.exempt ? Exact.zero : net * factor,
    );
  }
}

final class FinancialRounding {
  FinancialAmounts calculate({
    required Exact gross,
    required Exact discount,
    required TaxPolicy tax,
    required Currency currency,
    required MoneyRounding rounding,
  }) {
    final calculator = TaxCalculator();
    final subtotal = calculator.calculate(gross, tax).net;
    final after = calculator.calculate(gross - discount, tax);
    final total = after.net + after.tax;
    final subMinor = currency.minor(subtotal, rounding);
    final netMinor = currency.minor(after.net, rounding);
    final totalMinor = currency.minor(total, rounding);
    return FinancialAmounts(
      subtotal: subtotal,
      discount: subtotal - after.net,
      net: after.net,
      tax: after.tax,
      total: total,
      subtotalMinor: subMinor,
      discountMinor: subMinor - netMinor,
      netMinor: netMinor,
      taxMinor: totalMinor - netMinor,
      totalMinor: totalMinor,
    );
  }
}

final class PricingResult {
  PricingResult({
    required this.rule,
    required this.calculatedAt,
    required this.request,
    required this.inputs,
    required Map<String, MeasuredValue> billableInputs,
    required List<StrategyCharge> base,
    required List<StrategyCharge> extras,
    required this.unitBaseAmount,
    required this.orderBaseAmount,
    required this.extraAmount,
    required this.amounts,
    required List<String> warnings,
  }) : billableInputs = Map.unmodifiable(billableInputs),
       base = List.unmodifiable(base),
       extras = List.unmodifiable(extras),
       warnings = List.unmodifiable(warnings);
  final UniversalPricingRule rule;
  final DateTime calculatedAt;
  final UniversalPricingRequest request;
  final ValidatedInputs inputs;
  final Map<String, MeasuredValue> billableInputs;
  final List<StrategyCharge> base, extras;
  final Exact unitBaseAmount, orderBaseAmount, extraAmount;
  final FinancialAmounts amounts;
  final List<String> warnings;

  /// Internal replay snapshot; future customer rendering must allowlist fields.
  Map<String, Object?> toJson() => {
    'snapshotVersion': 1,
    'engineVersion': UniversalPricingEngine.version,
    'calculatedAt': calculatedAt.toUtc().toIso8601String(),
    'rule': rule.toJson(),
    'request': request.toJson(),
    'normalizedInputs': inputs.numbers.map((k, v) => MapEntry(k, v.toJson())),
    'billableInputs': billableInputs.map((k, v) => MapEntry(k, v.toJson())),
    'resolvedInputs': inputs.values.map((k, v) => MapEntry(k, v.toJson())),
    'base': base.map((c) => c.toJson()).toList(),
    'extras': extras.map((c) => c.toJson()).toList(),
    'unitBaseAmount': '$unitBaseAmount',
    'orderBaseAmount': '$orderBaseAmount',
    'extraAmount': '$extraAmount',
    'amounts': amounts.toJson(),
    'warnings': warnings,
  };
  String get snapshotJson => canonicalJson(toJson());
}

/// No storage, platform calls, clocks, network, or stock writes. Caller supplies
/// an authorized immutable definition and explicit eligibility time.
final class UniversalPricingEngine {
  static const version = 'universal-1';
  PricingResult calculate(
    UniversalPricingRule rule,
    UniversalPricingRequest request, {
    required DateTime at,
  }) {
    if (at.isBefore(rule.effectiveAt) ||
        (rule.expiresAt != null && !at.isBefore(rule.expiresAt!))) {
      throw StateError('Pricing rule is not effective or has expired');
    }
    final inputs = rule.schema.validate(request.inputs);
    final billable = Map<String, MeasuredValue>.from(inputs.numbers);
    final warnings = [...inputs.warnings];
    for (final adjustment in rule.inputBilling) {
      final measured = billable[adjustment.fieldId];
      if (measured == null) continue;
      final unit = rule.schema.units.registry.require(adjustment.unit);
      var value = (measured.value / unit.canonicalFactor).max(
        adjustment.minimum,
      );
      if (adjustment.increment != null) {
        value = value.ceilTo(adjustment.increment!);
      }
      final canonical = unit.normalize(value);
      final field = rule.schema.fields.singleWhere(
        (f) => f.id == adjustment.fieldId,
      );
      final display =
          value *
          unit.canonicalFactor /
          rule.schema.units.registry
              .require(field.defaultUnit!)
              .canonicalFactor;
      if (field.maximum != null && display > field.maximum!) {
        throw ArgumentError('Billable ${field.label} exceeds permitted size');
      }
      if (canonical.value != measured.value) {
        warnings.add('${field.label} billed as $value ${adjustment.unit}');
      }
      billable[adjustment.fieldId] = canonical;
    }
    final context = StrategyContext(
      rule.schema,
      rule.rateLookup,
      ValidatedInputs(
        inputs.values,
        billable,
        inputs.visibleFields,
        inputs.warnings,
      ),
      request.quantity,
    );
    final base = rule.strategy.calculate(context);
    if (base.isEmpty) throw StateError('Select at least one priced component');
    final extras = rule.extras.isEmpty
        ? <StrategyCharge>[]
        : ComponentStrategy(rule.extras).calculate(context);
    if ([...base, ...extras].any((c) => c.amount < Exact.zero)) {
      throw StateError('Negative selling contribution');
    }
    Exact sum(Iterable<Exact> values) =>
        values.fold(Exact.zero, (a, b) => a + b);
    final quantity = Exact.integer(request.quantity);
    final unitBase = sum(base.where((c) => !c.perOrder).map((c) => c.amount));
    final orderBase = sum(base.where((c) => c.perOrder).map((c) => c.amount));
    final extra = sum(
      extras.map((c) => c.amount * (c.perOrder ? Exact.one : quantity)),
    );
    final gross = unitBase * quantity + orderBase + extra;
    final discount = DiscountCalculator().calculate(
      gross,
      request.quantity,
      rule.discount,
    );
    final amounts = FinancialRounding().calculate(
      gross: gross,
      discount: discount,
      tax: rule.tax,
      currency: rule.currency,
      rounding: rule.rounding,
    );
    return PricingResult(
      rule: rule,
      calculatedAt: at.toUtc(),
      request: request,
      inputs: inputs,
      billableInputs: billable,
      base: base,
      extras: extras,
      unitBaseAmount: unitBase,
      orderBaseAmount: orderBase,
      extraAmount: extra,
      amounts: amounts,
      warnings: [
        ...warnings,
        ...base.expand((c) => c.policies),
        ...extras.expand((c) => c.policies),
      ],
    );
  }
}
