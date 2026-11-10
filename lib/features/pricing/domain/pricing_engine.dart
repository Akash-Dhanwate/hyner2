import 'exact.dart';
import 'measurements.dart';
import 'pricing_models.dart';
import 'serialization.dart';

final class PricingInput {
  PricingInput({
    required this.categoryId,
    this.variantId,
    required this.dimensions,
    this.quantity = 1,
    this.weightKilograms,
    Set<String> selectedAddonIds = const {},
    Map<String, Exact> addonQuantities = const {},
  }) : selectedAddonIds = Set.unmodifiable(selectedAddonIds),
       addonQuantities = Map.unmodifiable(addonQuantities) {
    if (quantity < 1 || quantity > 1000000) {
      throw ArgumentError('Quantity must be between 1 and 1000000');
    }
    if (weightKilograms != null &&
        (weightKilograms! <= Exact.zero ||
            weightKilograms! > Exact.integer(1000000))) {
      throw ArgumentError('Enter a positive weight within supported limits');
    }
    if (addonQuantities.values.any(
      (v) => v <= Exact.zero || v > Exact.integer(1000000),
    )) {
      throw ArgumentError(
        'Add-on quantities must be positive and within supported limits',
      );
    }
  }
  final String categoryId;
  final String? variantId;
  final Dimensions dimensions;
  final int quantity;
  final Exact? weightKilograms;
  final Set<String> selectedAddonIds;
  final Map<String, Exact> addonQuantities;
  factory PricingInput.fromJson(Map<String, dynamic> json) => PricingInput(
    categoryId: json['categoryId'] as String,
    variantId: json['variantId'] as String?,
    dimensions: Dimensions.fromJson(json['dimensions'] as Map<String, dynamic>),
    quantity: json['quantity'] as int,
    weightKilograms: json['weightKilograms'] == null
        ? null
        : Exact.parse(json['weightKilograms'] as String),
    selectedAddonIds: Set<String>.from(json['selectedAddonIds'] as List),
    addonQuantities: (json['addonQuantities'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, Exact.parse(value as String)),
    ),
  );
  Map<String, Object?> toJson() => {
    'categoryId': categoryId,
    'variantId': variantId,
    'dimensions': dimensions.toJson(),
    'quantity': quantity,
    'weightKilograms': weightKilograms?.toString(),
    'selectedAddonIds': selectedAddonIds.toList()..sort(),
    'addonQuantities': addonQuantities.map((k, v) => MapEntry(k, '$v')),
  };
}

final class PriceBreakdown {
  PriceBreakdown({
    required this.input,
    required this.rateCard,
    required this.rule,
    required this.billableDimensions,
    required this.measuredQuantity,
    required this.billableQuantity,
    required this.unitBasePrice,
    required this.basePrice,
    required Map<String, Exact> addonAmounts,
    required this.discount,
    required this.excludingTax,
    required this.tax,
    required this.includingTax,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.netMinor,
    required this.taxMinor,
    required this.totalMinor,
    required List<String> policies,
  }) : addonAmounts = Map.unmodifiable(addonAmounts),
       policies = List.unmodifiable(policies);
  final PricingInput input;
  final PublishedRateCard rateCard;
  final PricingRule rule;
  final Dimensions billableDimensions;
  final Exact measuredQuantity;
  final Exact billableQuantity;
  final Exact unitBasePrice;
  final Exact basePrice;
  final Map<String, Exact> addonAmounts;
  final Exact discount;
  final Exact excludingTax;
  final Exact tax;
  final Exact includingTax;
  final BigInt subtotalMinor;
  final BigInt discountMinor;
  final BigInt netMinor;
  final BigInt taxMinor;
  final BigInt totalMinor;
  final List<String> policies;

  /// Internal snapshot. Future customer output must use an explicit allowlist.
  Map<String, Object?> toJson() => {
    'engineVersion': PricingEngine.version,
    'snapshotVersion': 1,
    'input': input.toJson(),
    'businessId': rateCard.businessId,
    'profileId': rateCard.profileId,
    'rateCardVersion': rateCard.version,
    'currency': rateCard.card.currency.toJson(),
    'moneyRounding': rateCard.card.rounding.name,
    'categoryName': rateCard.card.categories
        .firstWhere((c) => c.id == input.categoryId)
        .name,
    'variant': input.variantId == null
        ? null
        : rateCard.card.variants
              .firstWhere((v) => v.id == input.variantId)
              .toJson(),
    'rule': rule.toJson(),
    'addonDefinitions': rateCard.card.addons
        .where((a) => addonAmounts.containsKey(a.id))
        .map((a) => a.toJson())
        .toList(),
    'billableDimensions': billableDimensions.toJson(),
    'measuredQuantity': '$measuredQuantity',
    'billableQuantity': '$billableQuantity',
    'unitBasePrice': '$unitBasePrice',
    'basePrice': '$basePrice',
    'addonAmounts': addonAmounts.map((k, v) => MapEntry(k, '$v')),
    'discount': '$discount',
    'excludingTax': '$excludingTax',
    'tax': '$tax',
    'includingTax': '$includingTax',
    'subtotalMinor': '$subtotalMinor',
    'discountMinor': '$discountMinor',
    'netMinor': '$netMinor',
    'taxMinor': '$taxMinor',
    'totalMinor': '$totalMinor',
    'policies': policies,
  };
  String get snapshotJson => canonicalJson(toJson());
}

/// Pure local calculation. Time is explicit for deterministic eligibility checks.
final class PricingEngine {
  static const version = 'quickprice-1';
  PriceBreakdown calculate(
    PublishedRateCard published,
    PricingInput input, {
    required DateTime at,
  }) {
    if (at.isBefore(published.effectiveAt) ||
        (published.expiresAt != null && !at.isBefore(published.expiresAt!))) {
      throw StateError('This rate card is not effective or has expired');
    }
    final card = published.card;
    final categories = card.categories.where(
      (c) => c.id == input.categoryId && c.active,
    );
    if (categories.isEmpty) throw StateError('Select an active category');
    final variants = card.variants.where(
      (v) => v.categoryId == input.categoryId && v.active,
    );
    if ((input.variantId != null &&
            !variants.any((v) => v.id == input.variantId)) ||
        (input.variantId == null && variants.isNotEmpty)) {
      throw StateError('Select an applicable variant');
    }
    final rules = card.rules.where(
      (r) => r.categoryId == input.categoryId && r.variantId == input.variantId,
    );
    if (rules.length != 1) {
      throw StateError('No unambiguous approved rate is available');
    }
    final rule = rules.single;
    if (!rule.supported) {
      throw UnsupportedError(
        'This pricing method requires an advanced engine version',
      );
    }
    if (input.quantity < rule.billing.minimumQuantity) {
      throw ArgumentError(
        'Minimum quantity is ${rule.billing.minimumQuantity}',
      );
    }
    _checkRanges(rule, input.dimensions);
    final measured = _measure(
      rule.method,
      input.dimensions,
      input.weightKilograms,
    );
    final policies = <String>[];
    var dimensions = input.dimensions;
    final step = rule.billing.dimensionIncrementMetres;
    if (step != null) {
      dimensions = Dimensions(
        dimensions.metres.map((k, v) => MapEntry(k, v.ceilTo(step))),
        enteredUnit: dimensions.enteredUnit,
      );
      policies.add('Dimensions rounded upward to $step metres');
    }
    if (rule.billing.stockedSizes.isNotEmpty) {
      final candidates = rule.billing.stockedSizes
          .where(
            (size) => dimensions.metres.entries.every(
              (e) =>
                  size.metres.containsKey(e.key) &&
                  size.metres[e.key]! >= e.value,
            ),
          )
          .toList();
      if (candidates.isEmpty) {
        throw ArgumentError('No stocked size fits these dimensions');
      }
      candidates.sort((a, b) {
        final comparison = _measure(
          rule.method,
          a,
          input.weightKilograms,
        ).compareTo(_measure(rule.method, b, input.weightKilograms));
        return comparison != 0
            ? comparison
            : canonicalJson(a.toJson()).compareTo(canonicalJson(b.toJson()));
      });
      dimensions = Dimensions(
        candidates.first.metres,
        enteredUnit: input.dimensions.enteredUnit,
      );
      policies.add('Next fitting stocked size (smallest chargeable measure)');
    }
    _checkRanges(rule, dimensions);
    var billable = _measure(rule.method, dimensions, input.weightKilograms);
    if (billable < rule.billing.minimumMeasure) {
      billable = rule.billing.minimumMeasure;
      policies.add('Minimum billable measure: $billable ${rule.method.name}');
    }
    if (rule.billing.measureIncrement != null) {
      billable = billable.ceilTo(rule.billing.measureIncrement!);
      policies.add(
        'Billable measure rounded upward to ${rule.billing.measureIncrement} ${rule.method.name}',
      );
    }
    final rawUnit = billable * rule.rate;
    final unit = rawUnit.max(rule.billing.minimumPrice);
    if (unit != rawUnit) {
      policies.add('Minimum per-item charge: ${rule.billing.minimumPrice}');
    }
    final base = unit * Exact.integer(input.quantity);
    if (input.selectedAddonIds.any((id) => !rule.addonIds.contains(id)) ||
        input.addonQuantities.keys.any((id) => !rule.addonIds.contains(id))) {
      throw ArgumentError('Add-on does not apply to this product');
    }
    final addons = <String, Exact>{};
    for (final addon in card.addons.where(
      (a) => rule.addonIds.contains(a.id),
    )) {
      if (!addon.required &&
          !addon.included &&
          !input.selectedAddonIds.contains(addon.id)) {
        continue;
      }
      final quantity = Exact.integer(input.quantity);
      addons[addon.id] = addon.included
          ? Exact.zero
          : switch (addon.method) {
              AddonMethod.perOrder => addon.rate,
              AddonMethod.perItem => addon.rate * quantity,
              AddonMethod.perSquareFoot =>
                addon.rate * dimensions.squareFeet * quantity,
              AddonMethod.perRunningFoot =>
                addon.rate *
                    LengthUnit.feet.fromMetres(
                      dimensions.require(Axis.height),
                    ) *
                    quantity,
              AddonMethod.percentage => base * addon.rate / Exact.integer(100),
              AddonMethod.quantity =>
                addon.rate *
                    (input.addonQuantities[addon.id] ??
                        (throw ArgumentError(
                          'Enter quantity for ${addon.name}',
                        ))),
            };
    }
    final gross = base + addons.values.fold(Exact.zero, (a, b) => a + b);
    var discount = Exact.zero;
    if (input.quantity >= rule.discount.minimumQuantity) {
      discount =
          gross * rule.discount.percent / Exact.integer(100) +
          rule.discount.fixedPerLine;
    }
    if (discount > gross) {
      throw StateError('Configured discount exceeds the selling amount');
    }
    final discounted = gross - discount;
    final multiplier = Exact.one + rule.tax.percent / Exact.integer(100);
    final net = rule.tax.behavior == TaxBehavior.inclusive
        ? discounted / multiplier
        : discounted;
    final tax = rule.tax.behavior == TaxBehavior.exempt
        ? Exact.zero
        : net * rule.tax.percent / Exact.integer(100);
    final total = net + tax;
    final subtotal = rule.tax.behavior == TaxBehavior.inclusive
        ? gross / multiplier
        : gross;
    BigInt minor(Exact value) => card.currency.minor(value, card.rounding);
    final netMinor = minor(net);
    final totalMinor = minor(total);
    // Allocate rounding residual to tax and discount so all displayed sums agree.
    return PriceBreakdown(
      input: input,
      rateCard: published,
      rule: rule,
      billableDimensions: dimensions,
      measuredQuantity: measured,
      billableQuantity: billable,
      unitBasePrice: unit,
      basePrice: base,
      addonAmounts: addons,
      discount: discount,
      excludingTax: net,
      tax: tax,
      includingTax: total,
      subtotalMinor: minor(subtotal),
      discountMinor: minor(subtotal) - netMinor,
      netMinor: netMinor,
      taxMinor: totalMinor - netMinor,
      totalMinor: totalMinor,
      policies: policies,
    );
  }

  Exact _measure(PricingMethod method, Dimensions d, Exact? weight) =>
      switch (method) {
        PricingMethod.piece => Exact.one,
        PricingMethod.squareFoot => d.squareFeet,
        PricingMethod.squareMetre => d.squareMetres,
        PricingMethod.runningFoot => LengthUnit.feet.fromMetres(
          d.require(Axis.height),
        ),
        PricingMethod.metre => d.require(Axis.height),
        PricingMethod.cubicMetre => d.cubicMetres,
        PricingMethod.kilogram =>
          weight ?? (throw ArgumentError('Enter weight in kilograms')),
        _ => throw UnsupportedError('Advanced pricing method is not enabled'),
      };
  void _checkRanges(PricingRule rule, Dimensions dimensions) {
    for (final entry in rule.billing.ranges.entries) {
      final value = dimensions.require(entry.key);
      if (value < entry.value.minimum || value > entry.value.maximum) {
        throw ArgumentError('${entry.key.name} is outside the permitted range');
      }
    }
  }
}
