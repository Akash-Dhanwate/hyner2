import 'exact.dart';
import 'measurements.dart';

enum PricingMethod {
  piece,
  squareFoot,
  squareMetre,
  runningFoot,
  metre,
  cubicMetre,
  kilogram,
  quantityTier,
  dimensionRange,
  customFormula,
  composite,
}

enum AddonMethod {
  perOrder,
  perItem,
  perSquareFoot,
  perRunningFoot,
  percentage,
  quantity,
}

enum TaxBehavior { exclusive, inclusive, exempt }

final class DimensionRange {
  DimensionRange(this.minimum, this.maximum) {
    if (minimum <= Exact.zero || maximum < minimum) {
      throw ArgumentError('Invalid dimension range');
    }
  }
  final Exact minimum;
  final Exact maximum;
  Map<String, Object?> toJson() => {
    'minimum': '$minimum',
    'maximum': '$maximum',
  };
  factory DimensionRange.fromJson(Map<String, dynamic> j) => DimensionRange(
    Exact.parse(j['minimum'] as String),
    Exact.parse(j['maximum'] as String),
  );
}

final class BillingPolicy {
  BillingPolicy({
    Exact? minimumMeasure,
    this.measureIncrement,
    this.dimensionIncrementMetres,
    Exact? minimumPrice,
    this.minimumQuantity = 1,
    List<Dimensions> stockedSizes = const [],
    Map<Axis, DimensionRange> ranges = const {},
  }) : minimumMeasure = minimumMeasure ?? Exact.zero,
       minimumPrice = minimumPrice ?? Exact.zero,
       stockedSizes = List.unmodifiable(stockedSizes),
       ranges = Map.unmodifiable(ranges) {
    if (this.minimumMeasure < Exact.zero ||
        this.minimumPrice < Exact.zero ||
        minimumQuantity < 1 ||
        (measureIncrement != null && measureIncrement! <= Exact.zero) ||
        (dimensionIncrementMetres != null &&
            dimensionIncrementMetres! <= Exact.zero)) {
      throw ArgumentError('Invalid billable-size policy');
    }
    if (stockedSizes.length > 200) {
      throw ArgumentError('At most 200 stocked sizes');
    }
  }
  final Exact minimumMeasure;
  final Exact? measureIncrement;
  final Exact? dimensionIncrementMetres;
  final Exact minimumPrice;
  final int minimumQuantity;
  final List<Dimensions> stockedSizes;
  final Map<Axis, DimensionRange> ranges;
  Map<String, Object?> toJson() => {
    'minimumMeasure': '$minimumMeasure',
    'measureIncrement': measureIncrement?.toString(),
    'dimensionIncrementMetres': dimensionIncrementMetres?.toString(),
    'minimumPrice': '$minimumPrice',
    'minimumQuantity': minimumQuantity,
    'stockedSizes': stockedSizes.map((e) => e.toJson()).toList(),
    'ranges': ranges.map((k, v) => MapEntry(k.name, v.toJson())),
  };
  factory BillingPolicy.fromJson(Map<String, dynamic> j) => BillingPolicy(
    minimumMeasure: Exact.parse(j['minimumMeasure'] as String),
    minimumPrice: Exact.parse(j['minimumPrice'] as String),
    measureIncrement: j['measureIncrement'] == null
        ? null
        : Exact.parse(j['measureIncrement'] as String),
    dimensionIncrementMetres: j['dimensionIncrementMetres'] == null
        ? null
        : Exact.parse(j['dimensionIncrementMetres'] as String),
    minimumQuantity: j['minimumQuantity'] as int,
    stockedSizes: (j['stockedSizes'] as List)
        .map((e) => Dimensions.fromJson(e as Map<String, dynamic>))
        .toList(),
    ranges: (j['ranges'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(
        Axis.values.byName(k),
        DimensionRange.fromJson(v as Map<String, dynamic>),
      ),
    ),
  );
}

/// Supplied by the business's validated tax configuration; no tax rate defaults.
final class TaxPolicy {
  TaxPolicy({
    required this.reference,
    required this.behavior,
    required this.percent,
  }) {
    if (reference.trim().isEmpty ||
        percent < Exact.zero ||
        percent > Exact.integer(100) ||
        (behavior == TaxBehavior.exempt && percent != Exact.zero)) {
      throw ArgumentError('Invalid tax policy');
    }
  }
  final String reference;
  final TaxBehavior behavior;
  final Exact percent;
  Map<String, Object?> toJson() => {
    'reference': reference,
    'behavior': behavior.name,
    'percent': '$percent',
  };
  factory TaxPolicy.fromJson(Map<String, dynamic> j) => TaxPolicy(
    reference: j['reference'] as String,
    behavior: TaxBehavior.values.byName(j['behavior'] as String),
    percent: Exact.parse(j['percent'] as String),
  );
}

/// An approved automatic discount stored in an immutable rule, not a seller override.
final class DiscountPolicy {
  DiscountPolicy({
    this.minimumQuantity = 1,
    Exact? fixedPerLine,
    Exact? percent,
  }) : fixedPerLine = fixedPerLine ?? Exact.zero,
       percent = percent ?? Exact.zero {
    if (minimumQuantity < 1 ||
        this.fixedPerLine < Exact.zero ||
        this.percent < Exact.zero ||
        this.percent > Exact.integer(100)) {
      throw ArgumentError('Invalid discount');
    }
  }
  final int minimumQuantity;
  final Exact fixedPerLine;
  final Exact percent;
  Map<String, Object?> toJson() => {
    'minimumQuantity': minimumQuantity,
    'fixedPerLine': '$fixedPerLine',
    'percent': '$percent',
  };
  factory DiscountPolicy.fromJson(Map<String, dynamic> j) => DiscountPolicy(
    minimumQuantity: j['minimumQuantity'] as int,
    fixedPerLine: Exact.parse(j['fixedPerLine'] as String),
    percent: Exact.parse(j['percent'] as String),
  );
}

final class PricingAddon {
  PricingAddon({
    required this.id,
    required this.name,
    required this.method,
    required this.rate,
    this.required = false,
    this.included = false,
    this.defaultSelected = false,
  }) {
    validateId(id);
    validateName(name);
    if (rate < Exact.zero ||
        (method == AddonMethod.percentage && rate > Exact.integer(100))) {
      throw ArgumentError('Invalid add-on rate');
    }
  }
  final String id;
  final String name;
  final AddonMethod method;
  final Exact rate;
  final bool required;
  final bool included;
  final bool defaultSelected;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'method': method.name,
    'rate': '$rate',
    'required': required,
    'included': included,
    'defaultSelected': defaultSelected,
  };
  factory PricingAddon.fromJson(Map<String, dynamic> j) => PricingAddon(
    id: j['id'] as String,
    name: j['name'] as String,
    method: AddonMethod.values.byName(j['method'] as String),
    rate: Exact.parse(j['rate'] as String),
    required: j['required'] as bool,
    included: j['included'] as bool,
    defaultSelected: j['defaultSelected'] as bool,
  );
}

final class PricingCategory {
  PricingCategory({
    required this.id,
    required this.name,
    this.parentId,
    this.sortOrder = 0,
    this.active = true,
  }) {
    validateId(id);
    validateName(name);
    if (parentId != null) validateId(parentId!);
  }
  final String id;
  final String name;
  final String? parentId;
  final int sortOrder;
  final bool active;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'parentId': parentId,
    'sortOrder': sortOrder,
    'active': active,
  };
  factory PricingCategory.fromJson(Map<String, dynamic> j) => PricingCategory(
    id: j['id'] as String,
    name: j['name'] as String,
    parentId: j['parentId'] as String?,
    sortOrder: j['sortOrder'] as int,
    active: j['active'] as bool,
  );
}

final class PricingVariant {
  PricingVariant({
    required this.id,
    required this.categoryId,
    required this.name,
    Map<String, String> attributes = const {},
    this.active = true,
  }) : attributes = Map.unmodifiable(attributes) {
    validateId(id);
    validateId(categoryId);
    validateName(name);
    if (attributes.length > 20 ||
        attributes.entries.any(
          (e) => e.key.length > 80 || e.value.length > 200,
        )) {
      throw ArgumentError('Variant attributes too large');
    }
  }
  final String id;
  final String categoryId;
  final String name;
  final Map<String, String> attributes;
  final bool active;
  Map<String, Object?> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'name': name,
    'attributes': attributes,
    'active': active,
  };
  factory PricingVariant.fromJson(Map<String, dynamic> j) => PricingVariant(
    id: j['id'] as String,
    categoryId: j['categoryId'] as String,
    name: j['name'] as String,
    attributes: Map<String, String>.from(j['attributes'] as Map),
    active: j['active'] as bool,
  );
}

final class PricingRule {
  PricingRule({
    required this.id,
    required this.categoryId,
    this.variantId,
    required this.method,
    required this.rate,
    required this.tax,
    BillingPolicy? billing,
    DiscountPolicy? discount,
    List<String> addonIds = const [],
    this.catalogProductId,
  }) : billing = billing ?? BillingPolicy(),
       discount = discount ?? DiscountPolicy(),
       addonIds = List.unmodifiable(addonIds) {
    validateId(id);
    validateId(categoryId);
    if (variantId != null) validateId(variantId!);
    if (rate < Exact.zero || rate > Exact.parse('1000000000000')) {
      throw ArgumentError('Rate outside supported range');
    }
  }
  final String id;
  final String categoryId;
  final String? variantId;
  final PricingMethod method;
  final Exact rate;
  final TaxPolicy tax;
  final BillingPolicy billing;
  final DiscountPolicy discount;
  final List<String> addonIds;
  final String? catalogProductId;
  bool get supported => method.index <= PricingMethod.kilogram.index;
  Map<String, Object?> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'variantId': variantId,
    'method': method.name,
    'rate': '$rate',
    'tax': tax.toJson(),
    'billing': billing.toJson(),
    'discount': discount.toJson(),
    'addonIds': addonIds,
    'catalogProductId': catalogProductId,
  };
  factory PricingRule.fromJson(Map<String, dynamic> j) => PricingRule(
    id: j['id'] as String,
    categoryId: j['categoryId'] as String,
    variantId: j['variantId'] as String?,
    method: PricingMethod.values.byName(j['method'] as String),
    rate: Exact.parse(j['rate'] as String),
    tax: TaxPolicy.fromJson(j['tax'] as Map<String, dynamic>),
    billing: BillingPolicy.fromJson(j['billing'] as Map<String, dynamic>),
    discount: DiscountPolicy.fromJson(j['discount'] as Map<String, dynamic>),
    addonIds: List<String>.from(j['addonIds'] as List),
    catalogProductId: j['catalogProductId'] as String?,
  );
}

final class RateCardDraft {
  RateCardDraft({
    required this.name,
    required this.currency,
    this.description = '',
    this.industryTemplate = 'custom',
    this.defaultUnit = LengthUnit.feetInches,
    this.defaultMethod = PricingMethod.squareFoot,
    this.rounding = MoneyRounding.halfUp,
    List<PricingCategory> categories = const [],
    List<PricingVariant> variants = const [],
    List<PricingRule> rules = const [],
    List<PricingAddon> addons = const [],
  }) : categories = List.unmodifiable(categories),
       variants = List.unmodifiable(variants),
       rules = List.unmodifiable(rules),
       addons = List.unmodifiable(addons) {
    validateName(name);
    if (description.length > 2000 ||
        industryTemplate.length > 80 ||
        categories.length > 1000 ||
        variants.length > 5000 ||
        rules.length > 6000 ||
        addons.length > 200) {
      throw ArgumentError('Rate card exceeds supported limits');
    }
    _unique(categories.map((e) => e.id));
    _unique(variants.map((e) => e.id));
    _unique(rules.map((e) => e.id));
    _unique(addons.map((e) => e.id));
    final categoryMap = {for (final c in categories) c.id: c};
    for (final c in categories) {
      final visited = <String>{c.id};
      var parent = c.parentId;
      while (parent != null) {
        if (!visited.add(parent) || !categoryMap.containsKey(parent)) {
          throw ArgumentError('Invalid category hierarchy');
        }
        parent = categoryMap[parent]!.parentId;
      }
    }
    final variantMap = {for (final v in variants) v.id: v};
    if (variants.any((v) => !categoryMap.containsKey(v.categoryId))) {
      throw ArgumentError('Unknown variant category');
    }
    final targets = <String>{};
    for (final r in rules) {
      if (!categoryMap.containsKey(r.categoryId) ||
          (r.variantId != null &&
              variantMap[r.variantId]?.categoryId != r.categoryId) ||
          !targets.add('${r.categoryId}/${r.variantId ?? ''}') ||
          r.addonIds.toSet().length != r.addonIds.length ||
          r.addonIds.any((id) => !addons.any((a) => a.id == id))) {
        throw ArgumentError('Invalid or ambiguous rule references');
      }
    }
  }
  final String name;
  final String description;
  final String industryTemplate;
  final Currency currency;
  final LengthUnit defaultUnit;
  final PricingMethod defaultMethod;
  final MoneyRounding rounding;
  final List<PricingCategory> categories;
  final List<PricingVariant> variants;
  final List<PricingRule> rules;
  final List<PricingAddon> addons;

  void validateForPublish() {
    if (rules.isEmpty || rules.any((r) => !r.supported)) {
      throw StateError('Configure supported pricing rules before publishing');
    }
    for (final c in categories.where((c) => c.active)) {
      final activeVariants = variants.where(
        (v) => v.categoryId == c.id && v.active,
      );
      // Parent categories may be navigation-only.
      if (categories.any((child) => child.parentId == c.id && child.active)) {
        continue;
      }
      if (activeVariants.isEmpty) {
        if (!rules.any((r) => r.categoryId == c.id && r.variantId == null)) {
          throw StateError('Missing rate for ${c.name}');
        }
      } else {
        for (final v in activeVariants) {
          if (!rules.any((r) => r.categoryId == c.id && r.variantId == v.id)) {
            throw StateError('Missing rate for ${v.name}');
          }
        }
      }
    }
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'name': name,
    'description': description,
    'industryTemplate': industryTemplate,
    'currency': currency.toJson(),
    'defaultUnit': defaultUnit.name,
    'defaultMethod': defaultMethod.name,
    'rounding': rounding.name,
    'categories': categories.map((e) => e.toJson()).toList(),
    'variants': variants.map((e) => e.toJson()).toList(),
    'rules': rules.map((e) => e.toJson()).toList(),
    'addons': addons.map((e) => e.toJson()).toList(),
  };
  factory RateCardDraft.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != 1) {
      throw const FormatException('Unsupported rate-card schema');
    }
    return RateCardDraft(
      name: j['name'] as String,
      description: j['description'] as String,
      industryTemplate: j['industryTemplate'] as String,
      currency: Currency.fromJson(j['currency'] as Map<String, dynamic>),
      defaultUnit: LengthUnit.values.byName(j['defaultUnit'] as String),
      defaultMethod: PricingMethod.values.byName(j['defaultMethod'] as String),
      rounding: MoneyRounding.values.byName(j['rounding'] as String),
      categories: (j['categories'] as List)
          .map((e) => PricingCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      variants: (j['variants'] as List)
          .map((e) => PricingVariant.fromJson(e as Map<String, dynamic>))
          .toList(),
      rules: (j['rules'] as List)
          .map((e) => PricingRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      addons: (j['addons'] as List)
          .map((e) => PricingAddon.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

final class PublishedRateCard {
  const PublishedRateCard({
    required this.businessId,
    required this.profileId,
    required this.version,
    required this.card,
    required this.effectiveAt,
    required this.publishedAt,
    required this.publishedBy,
    this.expiresAt,
  });
  final String businessId;
  final String profileId;
  final int version;
  final RateCardDraft card;
  final DateTime effectiveAt;
  final DateTime? expiresAt;
  final DateTime publishedAt;
  final String publishedBy;
  Map<String, Object?> toJson() => {
    'businessId': businessId,
    'profileId': profileId,
    'version': version,
    'card': card.toJson(),
    'effectiveAt': effectiveAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'publishedAt': publishedAt.toUtc().toIso8601String(),
    'publishedBy': publishedBy,
  };
  factory PublishedRateCard.fromJson(Map<String, dynamic> j) =>
      PublishedRateCard(
        businessId: j['businessId'] as String,
        profileId: j['profileId'] as String,
        version: j['version'] as int,
        card: RateCardDraft.fromJson(j['card'] as Map<String, dynamic>),
        effectiveAt: DateTime.parse(j['effectiveAt'] as String),
        expiresAt: j['expiresAt'] == null
            ? null
            : DateTime.parse(j['expiresAt'] as String),
        publishedAt: DateTime.parse(j['publishedAt'] as String),
        publishedBy: j['publishedBy'] as String,
      );
}

void validateId(String id) {
  if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(id)) {
    throw ArgumentError('Invalid ID');
  }
}

void validateName(String name) {
  if (name.trim().isEmpty || name.length > 120) {
    throw ArgumentError('Name must contain 1–120 characters');
  }
}

void _unique(Iterable<String> ids) {
  if (ids.toSet().length != ids.length) throw ArgumentError('Duplicate IDs');
}
