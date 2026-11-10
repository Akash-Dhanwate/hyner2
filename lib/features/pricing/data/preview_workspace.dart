import '../application/workspace.dart';
import '../domain/pricing_models.dart';
import '../domain/pricing_repository.dart';
import '../domain/serialization.dart';
import '../domain/universal/rate_card.dart';

/// Browser-only, explicitly transient preview. No browser persistence, cloud
/// business identity, auth role, or Firestore access is inferred here.
QuickPriceWorkspace createPreviewWorkspace() {
  final values = PreviewValues();
  return QuickPriceWorkspace(
    businessId: 'browser-preview',
    values: values,
    repository: PreviewRepository(values),
    preview: true,
  );
}

class PreviewValues implements WorkspaceValues {
  final Map<String, String> _values = {};
  final Set<String> _policies = {};
  @override
  Future<Map<String, dynamic>?> read(String key) async =>
      _values[key] == null ? null : jsonObject(_values[key]!);
  @override
  Future<void> write(String key, Map<String, dynamic>? value) async {
    validateWorkspaceValue(value);
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = canonicalJson(value);
    }
  }

  @override
  Future<void> approve(TaxPolicy policy) async {
    _policies.add(canonicalJson(policy.toJson()));
  }

  @override
  Future<bool> isApproved(String businessId, TaxPolicy policy) async =>
      businessId == 'browser-preview' &&
      _policies.contains(canonicalJson(policy.toJson()));
}

class PreviewRepository implements UniversalRateCardRepository {
  PreviewRepository(this.values);
  final PreviewValues values;
  final Map<String, UniversalStoredDraft> _drafts = {};
  final Map<String, List<PublishedUniversalRateCard>> _versions = {};
  final Set<String> _archived = {};
  Future<void> _tail = Future.value();
  Future<T> _write<T>(Future<T> Function() operation) {
    final next = _tail.then((_) => operation());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  void _limit(int value) {
    if (value < 1 || value > 50) throw ArgumentError('Page size must be 1–50');
  }

  UniversalStoredDraft _editable(String id, int revision) {
    final draft = _drafts[id];
    if (draft == null || _archived.contains(id)) {
      throw StateError('Profile is unavailable or archived');
    }
    if (draft.revision != revision) {
      throw StateError('Draft changed; reload before saving or publishing');
    }
    return draft;
  }

  @override
  Future<List<PricingProfileSummary>> profiles({
    String afterId = '',
    int limit = 20,
  }) async {
    _limit(limit);
    final ids = _drafts.keys.where((id) => id.compareTo(afterId) > 0).toList()
      ..sort();
    return ids
        .take(limit)
        .map(
          (id) => PricingProfileSummary(
            id,
            _drafts[id]!.card.name,
            _archived.contains(id)
                ? 'archived'
                : (_versions[id]?.isNotEmpty ?? false)
                ? 'published'
                : 'draft',
          ),
        )
        .toList();
  }

  @override
  Future<UniversalStoredDraft> createProfile(
    String id,
    UniversalRateCardDraft card,
  ) => _write(() async {
    validateId(id);
    card.validateForBusiness('browser-preview');
    if (_drafts.containsKey(id)) throw StateError('Profile already exists');
    return _drafts[id] = UniversalStoredDraft(id, 1, card);
  });
  @override
  Future<UniversalStoredDraft> readDraft(String id) async =>
      _drafts[id] ?? (throw StateError('Profile not found'));
  @override
  Future<UniversalStoredDraft> saveDraft(
    String id,
    UniversalRateCardDraft card, {
    required int expectedRevision,
  }) => _write(() async {
    _editable(id, expectedRevision);
    card.validateForBusiness('browser-preview');
    return _drafts[id] = UniversalStoredDraft(id, expectedRevision + 1, card);
  });
  @override
  Future<PublishedUniversalRateCard> publish(
    String id, {
    required int expectedRevision,
    required DateTime effectiveAt,
    DateTime? expiresAt,
  }) => _write(() async {
    final draft = _editable(id, expectedRevision);
    draft.card.validateForBusiness('browser-preview', publishing: true);
    for (final product in draft.card.products) {
      if (!await values.isApproved('browser-preview', product.rule.tax)) {
        throw StateError('Review and confirm the tax treatment');
      }
    }
    final versions = _versions[id] ?? [];
    if (versions.isNotEmpty &&
        effectiveAt.isBefore(versions.last.effectiveAt)) {
      throw StateError('Effective date precedes the latest version');
    }
    final version = versions.length + 1;
    final cardJson = jsonObject(canonicalJson(draft.card.toJson()));
    for (final product in cardJson['products'] as List) {
      final rule = product['rule'] as Map<String, dynamic>;
      rule['version'] = version;
      rule['effectiveAt'] = effectiveAt.toUtc().toIso8601String();
      rule['expiresAt'] = expiresAt?.toUtc().toIso8601String();
    }
    final card = UniversalRateCardDraft.fromJson(cardJson);
    final result = PublishedUniversalRateCard(
      businessId: 'browser-preview',
      profileId: id,
      version: version,
      card: card,
      effectiveAt: effectiveAt,
      expiresAt: expiresAt,
      publishedAt: DateTime.now().toUtc(),
      publishedBy: 'preview-owner',
    );
    _versions[id] = [...versions, result];
    _drafts[id] = UniversalStoredDraft(id, expectedRevision + 1, card);
    return result;
  });
  @override
  Future<PublishedUniversalRateCard?> activeCard(
    String id, {
    required DateTime at,
  }) async {
    if (_archived.contains(id)) return null;
    final active = (_versions[id] ?? [])
        .where((v) => !v.effectiveAt.isAfter(at))
        .lastOrNull;
    return active != null &&
            (active.expiresAt == null || at.isBefore(active.expiresAt!))
        ? active
        : null;
  }

  @override
  Future<PublishedUniversalRateCard> readVersion(
    String id,
    int version,
  ) async =>
      (_versions[id] ?? []).where((v) => v.version == version).firstOrNull ??
      (throw StateError('Version unavailable'));
  @override
  Future<List<PublishedUniversalRateCard>> history(
    String id, {
    int beforeVersion = 2147483647,
    int limit = 20,
  }) async {
    _limit(limit);
    return (_versions[id] ?? []).reversed
        .where((v) => v.version < beforeVersion)
        .take(limit)
        .toList();
  }

  @override
  Future<void> archive(String id) => _write(() async {
    _editable(id, (await readDraft(id)).revision);
    _archived.add(id);
  });
}
