import 'package:drift/drift.dart';

import '../../../core/storage/pricing_database.dart';
import '../domain/pricing_models.dart';
import '../domain/pricing_repository.dart';
import '../domain/serialization.dart';

/// Scope is fixed at construction from the authenticated/local-owned session.
/// Public operations never accept a caller-selected business ID.
final class LocalRateCardRepository implements RateCardRepository {
  LocalRateCardRepository(
    this._db,
    this._session,
    this._taxPolicies, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final PricingDatabase _db;
  final PricingSession _session;
  final BusinessTaxPolicies _taxPolicies;
  final DateTime Function() _clock;
  String get _business => _session.businessId;
  List<Variable> _scope(String profileId) => [
    Variable(_business),
    Variable(profileId),
  ];

  @override
  Future<List<PricingProfileSummary>> profiles({
    String afterId = '',
    int limit = 20,
  }) async {
    _session.require(PricingPermission.viewPublished);
    if (limit < 1 || limit > 100) {
      throw ArgumentError('Page size must be 1–100');
    }
    final owner = _session.permissions.contains(PricingPermission.editDraft);
    final rows = await _db
        .customSelect(
          'SELECT id,name,status FROM pricing_profiles WHERE business_id = ? AND id > ? '
          "AND (? = 1 OR status = 'published') ORDER BY id LIMIT ?",
          variables: [
            Variable(_business),
            Variable(afterId),
            Variable(owner ? 1 : 0),
            Variable(limit),
          ],
        )
        .get();
    return rows
        .map(
          (r) => PricingProfileSummary(
            r.read<String>('id'),
            r.read<String>('name'),
            r.read<String>('status'),
          ),
        )
        .toList();
  }

  @override
  Future<StoredDraft> createProfile(
    String profileId,
    RateCardDraft card,
  ) async {
    _session.require(PricingPermission.createProfile);
    validateId(profileId);
    final json = _snapshot(card);
    return _db.transaction(() async {
      final now = _clock().millisecondsSinceEpoch;
      await _db.customStatement(
        'INSERT INTO pricing_profiles (business_id,id,name,created_at,updated_at) VALUES (?,?,?,?,?)',
        [_business, profileId, card.name, now, now],
      );
      await _db.customStatement('INSERT INTO pricing_drafts VALUES (?,?,?,?)', [
        _business,
        profileId,
        1,
        json,
      ]);
      await _audit(profileId, 'create_profile', null, json);
      return StoredDraft(profileId, 1, card);
    });
  }

  @override
  Future<StoredDraft> readDraft(String profileId) {
    _session.require(PricingPermission.editDraft);
    return _readDraft(profileId);
  }

  Future<StoredDraft> _readDraft(String profileId) async {
    final row = await _db
        .customSelect(
          'SELECT revision,snapshot_json FROM pricing_drafts WHERE business_id = ? AND profile_id = ? LIMIT 1',
          variables: _scope(profileId),
        )
        .getSingleOrNull();
    if (row == null) {
      throw StateError('Pricing profile not found in this business');
    }
    return StoredDraft(
      profileId,
      row.read<int>('revision'),
      RateCardDraft.fromJson(jsonObject(row.read<String>('snapshot_json'))),
    );
  }

  Future<void> _assertEditable(String profileId, int revision) async {
    final row = await _db
        .customSelect(
          'SELECT p.status,d.revision FROM pricing_profiles p JOIN pricing_drafts d ON p.business_id = d.business_id AND p.id = d.profile_id WHERE p.business_id = ? AND p.id = ? LIMIT 1',
          variables: _scope(profileId),
        )
        .getSingleOrNull();
    if (row == null || row.read<String>('status') == 'archived') {
      throw StateError('Profile is unavailable or archived');
    }
    if (row.read<int>('revision') != revision) {
      throw StateError('Draft changed; reload before saving or publishing');
    }
  }

  @override
  Future<StoredDraft> saveDraft(
    String profileId,
    RateCardDraft card, {
    required int expectedRevision,
  }) async {
    _session.require(PricingPermission.editDraft);
    final json = _snapshot(card);
    return _db.transaction(() async {
      await _assertEditable(profileId, expectedRevision);
      final old = await _readDraft(profileId);
      await _db.customStatement(
        'UPDATE pricing_drafts SET revision = revision + 1, snapshot_json = ? WHERE business_id = ? AND profile_id = ?',
        [json, _business, profileId],
      );
      await _db.customStatement(
        'UPDATE pricing_profiles SET name = ?, updated_at = ? WHERE business_id = ? AND id = ?',
        [card.name, _clock().millisecondsSinceEpoch, _business, profileId],
      );
      await _audit(profileId, 'edit_draft', _snapshot(old.card), json);
      return StoredDraft(profileId, expectedRevision + 1, card);
    });
  }

  @override
  Future<PublishedRateCard> publish(
    String profileId, {
    required int expectedRevision,
    required DateTime effectiveAt,
    DateTime? expiresAt,
  }) async {
    _session.require(PricingPermission.publish);
    if (expiresAt != null && !expiresAt.isAfter(effectiveAt)) {
      throw ArgumentError('Expiry must follow effective date');
    }
    return _db.transaction(() async {
      await _assertEditable(profileId, expectedRevision);
      final draft = await _readDraft(profileId);
      draft.card.validateForPublish();
      for (final rule in draft.card.rules) {
        if (!await _taxPolicies.isApproved(_business, rule.tax)) {
          throw StateError('Tax policy is not approved for this business');
        }
      }
      final previous = await _db
          .customSelect(
            'SELECT version,effective_at FROM pricing_rate_card_versions WHERE business_id = ? AND profile_id = ? ORDER BY version DESC LIMIT 1',
            variables: _scope(profileId),
          )
          .getSingleOrNull();
      if (previous != null &&
          effectiveAt.millisecondsSinceEpoch <
              previous.read<int>('effective_at')) {
        throw StateError(
          'A new version cannot precede the last published effective date',
        );
      }
      final version = (previous?.read<int>('version') ?? 0) + 1;
      final published = PublishedRateCard(
        businessId: _business,
        profileId: profileId,
        version: version,
        card: draft.card,
        effectiveAt: effectiveAt.toUtc(),
        expiresAt: expiresAt?.toUtc(),
        publishedAt: _clock().toUtc(),
        publishedBy: _session.actorId,
      );
      final json = canonicalJson(published.toJson());
      await _db.customStatement(
        'INSERT INTO pricing_rate_card_versions (business_id,profile_id,version,effective_at,expires_at,published_at,published_by,snapshot_json) VALUES (?,?,?,?,?,?,?,?)',
        [
          _business,
          profileId,
          version,
          effectiveAt.millisecondsSinceEpoch,
          expiresAt?.millisecondsSinceEpoch,
          published.publishedAt.millisecondsSinceEpoch,
          _session.actorId,
          json,
        ],
      );
      final prefix = <Object?>[_business, profileId, version];
      for (final c in draft.card.categories) {
        await _db.customStatement(
          'INSERT INTO pricing_categories VALUES (?,?,?,?,?,?,?,?)',
          [
            ...prefix,
            c.id,
            c.parentId,
            c.name,
            c.sortOrder,
            canonicalJson(c.toJson()),
          ],
        );
      }
      for (final v in draft.card.variants) {
        await _db.customStatement(
          'INSERT INTO pricing_variants VALUES (?,?,?,?,?,?)',
          [...prefix, v.id, v.categoryId, canonicalJson(v.toJson())],
        );
      }
      for (final a in draft.card.addons) {
        await _db.customStatement(
          'INSERT INTO pricing_addons VALUES (?,?,?,?,?,?)',
          [...prefix, a.id, a.name, canonicalJson(a.toJson())],
        );
      }
      for (final r in draft.card.rules) {
        await _db.customStatement(
          'INSERT INTO pricing_rule_versions VALUES (?,?,?,?,?,?,?,?,?)',
          [
            ...prefix,
            r.id,
            r.categoryId,
            r.variantId,
            r.method.name,
            '${r.rate}',
            canonicalJson(r.toJson()),
          ],
        );
        for (final addonId in r.addonIds) {
          await _db.customStatement(
            'INSERT INTO pricing_rule_addons VALUES (?,?,?,?,?)',
            [...prefix, r.id, addonId],
          );
        }
      }
      await _db.customStatement(
        'UPDATE pricing_rate_card_versions SET sealed = 1 WHERE business_id = ? AND profile_id = ? AND version = ?',
        prefix,
      );
      await _db.customStatement(
        "UPDATE pricing_profiles SET status = 'published', updated_at = ? WHERE business_id = ? AND id = ?",
        [_clock().millisecondsSinceEpoch, _business, profileId],
      );
      // A second tap with the same revision fails, rather than publishing twice.
      await _db.customStatement(
        'UPDATE pricing_drafts SET revision = revision + 1 WHERE business_id = ? AND profile_id = ?',
        [_business, profileId],
      );
      await _audit(
        profileId,
        'publish',
        previous == null ? null : canonicalJson({'version': version - 1}),
        json,
      );
      return published;
    });
  }

  @override
  Future<PublishedRateCard?> activeCard(
    String profileId, {
    required DateTime at,
  }) async {
    _session.require(PricingPermission.viewPublished);
    _session.require(PricingPermission.calculate);
    final row = await _db
        .customSelect(
          "SELECT v.snapshot_json FROM pricing_rate_card_versions v JOIN pricing_profiles p ON v.business_id = p.business_id AND v.profile_id = p.id WHERE v.business_id = ? AND v.profile_id = ? AND p.status = 'published' AND v.sealed = 1 AND v.effective_at <= ? ORDER BY v.effective_at DESC,v.version DESC LIMIT 1",
          variables: [
            ..._scope(profileId),
            Variable(at.millisecondsSinceEpoch),
          ],
        )
        .getSingleOrNull();
    if (row == null) return null;
    final card = PublishedRateCard.fromJson(
      jsonObject(row.read<String>('snapshot_json')),
    );
    if (card.expiresAt != null && !at.isBefore(card.expiresAt!)) {
      throw StateError('Latest approved rate card has expired');
    }
    return card;
  }

  @override
  Future<PublishedRateCard> readVersion(String profileId, int version) async {
    _session.require(PricingPermission.viewPublished);
    final row = await _db
        .customSelect(
          'SELECT snapshot_json FROM pricing_rate_card_versions WHERE business_id = ? AND profile_id = ? AND version = ? AND sealed = 1 LIMIT 1',
          variables: [..._scope(profileId), Variable(version)],
        )
        .getSingleOrNull();
    if (row == null) throw StateError('Published version not found');
    return PublishedRateCard.fromJson(
      jsonObject(row.read<String>('snapshot_json')),
    );
  }

  @override
  Future<List<PublishedRateCard>> history(
    String profileId, {
    int beforeVersion = 2147483647,
    int limit = 20,
  }) async {
    _session.require(PricingPermission.editDraft);
    if (limit < 1 || limit > 100) {
      throw ArgumentError('Page size must be 1–100');
    }
    final rows = await _db
        .customSelect(
          'SELECT snapshot_json FROM pricing_rate_card_versions WHERE business_id = ? AND profile_id = ? AND version < ? AND sealed = 1 ORDER BY version DESC LIMIT ?',
          variables: [
            ..._scope(profileId),
            Variable(beforeVersion),
            Variable(limit),
          ],
        )
        .get();
    return rows
        .map(
          (r) => PublishedRateCard.fromJson(
            jsonObject(r.read<String>('snapshot_json')),
          ),
        )
        .toList();
  }

  @override
  Future<void> archive(String profileId) async {
    _session.require(PricingPermission.publish);
    await _db.transaction(() async {
      final draft = await _readDraft(profileId);
      await _db.customStatement(
        "UPDATE pricing_profiles SET status = 'archived',updated_at = ? WHERE business_id = ? AND id = ?",
        [_clock().millisecondsSinceEpoch, _business, profileId],
      );
      await _audit(
        profileId,
        'archive',
        _snapshot(draft.card),
        canonicalJson({'status': 'archived'}),
      );
    });
  }

  String _snapshot(RateCardDraft card) {
    final json = canonicalJson(card.toJson());
    if (json.length > 2000000) {
      throw ArgumentError('Rate card exceeds local snapshot limit');
    }
    return json;
  }

  Future<void> _audit(
    String profileId,
    String action,
    String? before,
    String after,
  ) => _db.customStatement(
    'INSERT INTO pricing_audit_events (business_id,actor_uid,action,profile_id,before_snapshot,after_snapshot,created_at) VALUES (?,?,?,?,?,?,?)',
    [
      _business,
      _session.actorId,
      action,
      profileId,
      before,
      after,
      _clock().millisecondsSinceEpoch,
    ],
  );
}
