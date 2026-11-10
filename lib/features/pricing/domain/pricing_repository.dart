import 'pricing_models.dart';

enum PricingPermission {
  calculate('pricing.calculate'),
  viewPublished('pricing.view_published'),
  createProfile('pricing.create_profile'),
  editDraft('pricing.edit_draft'),
  publish('pricing.publish'),
  viewCost('pricing.view_cost'),
  overrideRate('pricing.override_rate'),
  approveDiscount('pricing.approve_discount'),
  createEstimate('pricing.create_estimate'),
  shareEstimate('pricing.share_estimate'),
  convertToSale('pricing.convert_to_sale'),
  importRates('pricing.import_rates');

  const PricingPermission(this.key);
  final String key;
  static const cashier = {
    calculate,
    viewPublished,
    createEstimate,
    shareEstimate,
  };
}

/// Injected by the trusted business-session adapter. Never populate from forms
/// or mutable subscription preferences. This is a local guard, not a backend.
final class PricingSession {
  PricingSession({
    required this.businessId,
    required this.actorId,
    required Set<PricingPermission> permissions,
  }) : permissions = Set.unmodifiable(permissions) {
    validateId(businessId);
    validateId(actorId);
  }
  final String businessId;
  final String actorId;
  final Set<PricingPermission> permissions;
  void require(PricingPermission permission) {
    if (!permissions.contains(permission)) {
      throw StateError('Permission required: ${permission.key}');
    }
  }
}

final class StoredDraft {
  const StoredDraft(this.profileId, this.revision, this.card);
  final String profileId;
  final int revision;
  final RateCardDraft card;
}

final class PricingProfileSummary {
  const PricingProfileSummary(this.id, this.name, this.status);
  final String id;
  final String name;
  final String status;
}

/// Later business-tax module must verify the complete policy, including its
/// business ownership and rate, not just whether a reference exists.
abstract interface class BusinessTaxPolicies {
  Future<bool> isApproved(String businessId, TaxPolicy policy);
}

abstract interface class RateCardRepository {
  Future<List<PricingProfileSummary>> profiles({
    String afterId = '',
    int limit = 20,
  });
  Future<StoredDraft> createProfile(String profileId, RateCardDraft card);
  Future<StoredDraft> readDraft(String profileId);
  Future<StoredDraft> saveDraft(
    String profileId,
    RateCardDraft card, {
    required int expectedRevision,
  });
  Future<PublishedRateCard> publish(
    String profileId, {
    required int expectedRevision,
    required DateTime effectiveAt,
    DateTime? expiresAt,
  });
  Future<PublishedRateCard?> activeCard(
    String profileId, {
    required DateTime at,
  });
  Future<PublishedRateCard> readVersion(String profileId, int version);
  Future<List<PublishedRateCard>> history(
    String profileId, {
    int beforeVersion = 2147483647,
    int limit = 20,
  });
  Future<void> archive(String profileId);
}
