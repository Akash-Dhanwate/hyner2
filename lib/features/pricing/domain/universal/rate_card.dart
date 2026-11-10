import '../exact.dart';
import '../pricing_models.dart' show PricingCategory, validateId, validateName;
import '../pricing_repository.dart';
import 'engine.dart';

/// A priceable category/variant, not an inventory record or stock movement.
final class UniversalProduct {
  UniversalProduct({
    required this.categoryId,
    required this.name,
    required this.rule,
    Map<String, String> attributes = const {},
  }) : attributes = Map.unmodifiable(attributes) {
    validateId(categoryId);
    validateName(name);
    if (attributes.length > 16) {
      throw ArgumentError('Too many variant attributes');
    }
    for (final entry in attributes.entries) {
      validateName(entry.key);
      validateName(entry.value);
    }
  }
  final String categoryId;
  final String name;
  final UniversalPricingRule rule;
  final Map<String, String> attributes;
  String get id => rule.productId;
  UniversalProduct withRule(UniversalPricingRule value) => UniversalProduct(
    categoryId: categoryId,
    name: name,
    rule: value,
    attributes: attributes,
  );
  Map<String, Object?> toJson() => {
    'categoryId': categoryId,
    'name': name,
    'attributes': attributes,
    'rule': rule.toJson(),
  };
  factory UniversalProduct.fromJson(Map<String, dynamic> json) =>
      UniversalProduct(
        categoryId: json['categoryId'] as String,
        name: json['name'] as String,
        attributes: Map<String, String>.from(json['attributes'] as Map),
        rule: UniversalPricingRule.fromJson(
          json['rule'] as Map<String, dynamic>,
        ),
      );
}

final class UniversalRateCardDraft {
  UniversalRateCardDraft({
    required this.name,
    required this.currency,
    this.description = '',
    this.industryTemplate = 'custom',
    List<PricingCategory> categories = const [],
    List<UniversalProduct> products = const [],
  }) : categories = List.unmodifiable(categories),
       products = List.unmodifiable(products) {
    validateName(name);
    validateId(industryTemplate);
    if (description.length > 2000 ||
        categories.length > 250 ||
        products.length > 500) {
      throw ArgumentError('Rate card exceeds supported limits');
    }
    final ids = categories.map((c) => c.id).toSet();
    if (ids.length != categories.length ||
        products.map((p) => p.id).toSet().length != products.length ||
        products.map((p) => p.rule.id).toSet().length != products.length) {
      throw ArgumentError('Duplicate category, product or rule identifier');
    }
    final parents = {for (final c in categories) c.id: c.parentId};
    for (final category in categories) {
      final visited = <String>{};
      String? cursor = category.id;
      while (cursor != null) {
        if (!ids.contains(cursor) || !visited.add(cursor)) {
          throw ArgumentError('Invalid category hierarchy');
        }
        cursor = parents[cursor];
      }
    }
    for (final product in products) {
      if (!ids.contains(product.categoryId) ||
          product.rule.currency.code != currency.code ||
          product.rule.currency.minorDigits != currency.minorDigits) {
        throw ArgumentError(
          'Product category or currency does not match its profile',
        );
      }
    }
  }
  final String name, description, industryTemplate;
  final Currency currency;
  final List<PricingCategory> categories;
  final List<UniversalProduct> products;

  void validateForBusiness(String businessId, {bool publishing = false}) {
    if (products.any((p) => p.rule.businessId != businessId)) {
      throw ArgumentError('Pricing rule belongs to another business');
    }
    if (publishing && products.isEmpty) {
      throw StateError('Add a product and its selling rate before publishing');
    }
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'engineVersion': UniversalPricingEngine.version,
    'name': name,
    'description': description,
    'industryTemplate': industryTemplate,
    'currency': currency.toJson(),
    'categories': categories.map((c) => c.toJson()).toList(),
    'products': products.map((p) => p.toJson()).toList(),
  };
  factory UniversalRateCardDraft.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 ||
        json['engineVersion'] != UniversalPricingEngine.version) {
      throw const FormatException('Unsupported rate-card format');
    }
    return UniversalRateCardDraft(
      name: json['name'] as String,
      description: json['description'] as String,
      industryTemplate: json['industryTemplate'] as String,
      currency: Currency.fromJson(json['currency'] as Map<String, dynamic>),
      categories: (json['categories'] as List)
          .map((c) => PricingCategory.fromJson(c as Map<String, dynamic>))
          .toList(),
      products: (json['products'] as List)
          .map((p) => UniversalProduct.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

final class UniversalStoredDraft {
  const UniversalStoredDraft(this.profileId, this.revision, this.card);
  final String profileId;
  final int revision;
  final UniversalRateCardDraft card;
}

final class PublishedUniversalRateCard {
  PublishedUniversalRateCard({
    required this.businessId,
    required this.profileId,
    required this.version,
    required this.card,
    required this.effectiveAt,
    required this.publishedAt,
    required this.publishedBy,
    this.expiresAt,
  }) {
    validateId(businessId);
    validateId(profileId);
    validateId(publishedBy);
    if (version < 1 ||
        version > 2147483647 ||
        (expiresAt != null && !expiresAt!.isAfter(effectiveAt))) {
      throw ArgumentError('Invalid published version');
    }
    card.validateForBusiness(businessId, publishing: true);
    for (final product in card.products) {
      final rule = product.rule;
      if (rule.version != version ||
          rule.effectiveAt != effectiveAt ||
          rule.expiresAt != expiresAt) {
        throw ArgumentError('Published rule does not match rate-card version');
      }
    }
  }
  final String businessId, profileId, publishedBy;
  final int version;
  final UniversalRateCardDraft card;
  final DateTime effectiveAt, publishedAt;
  final DateTime? expiresAt;
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
  factory PublishedUniversalRateCard.fromJson(Map<String, dynamic> json) =>
      PublishedUniversalRateCard(
        businessId: json['businessId'] as String,
        profileId: json['profileId'] as String,
        version: json['version'] as int,
        card: UniversalRateCardDraft.fromJson(
          json['card'] as Map<String, dynamic>,
        ),
        effectiveAt: DateTime.parse(json['effectiveAt'] as String),
        expiresAt: json['expiresAt'] == null
            ? null
            : DateTime.parse(json['expiresAt'] as String),
        publishedAt: DateTime.parse(json['publishedAt'] as String),
        publishedBy: json['publishedBy'] as String,
      );
}

abstract interface class UniversalRateCardRepository {
  Future<List<PricingProfileSummary>> profiles({
    String afterId = '',
    int limit = 20,
  });
  Future<UniversalStoredDraft> createProfile(
    String id,
    UniversalRateCardDraft card,
  );
  Future<UniversalStoredDraft> readDraft(String id);
  Future<UniversalStoredDraft> saveDraft(
    String id,
    UniversalRateCardDraft card, {
    required int expectedRevision,
  });
  Future<PublishedUniversalRateCard> publish(
    String id, {
    required int expectedRevision,
    required DateTime effectiveAt,
    DateTime? expiresAt,
  });
  Future<PublishedUniversalRateCard?> activeCard(
    String id, {
    required DateTime at,
  });
  Future<PublishedUniversalRateCard> readVersion(String id, int version);
  Future<List<PublishedUniversalRateCard>> history(
    String id, {
    int beforeVersion = 2147483647,
    int limit = 20,
  });
  Future<void> archive(String id);
}
