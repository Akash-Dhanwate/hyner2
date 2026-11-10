import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/storage/pricing_database.dart';
import '../domain/pricing_models.dart' show validateId;
import '../domain/pricing_repository.dart';
import '../domain/serialization.dart';
import '../domain/universal/engine.dart';
import '../domain/universal/rate_card.dart';

/// Local persistence only. The app supplies a trusted local-owner or authorized
/// business session; a Firebase initialization result is never a session.
final class LocalUniversalRateCardRepository
    implements UniversalRateCardRepository {
  LocalUniversalRateCardRepository(
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
  List<Variable> _scope(String id) {
    validateId(id);
    return [Variable(_business), Variable(id)];
  }

  void _limit(int limit) {
    if (limit < 1 || limit > 50) throw ArgumentError('Page size must be 1–50');
  }

  String _snapshot(UniversalRateCardDraft card) {
    card.validateForBusiness(_business);
    final json = canonicalJson(card.toJson());
    if (utf8.encode(json).length > 1024 * 1024) {
      throw ArgumentError('Rate card exceeds the 1 MiB local snapshot limit');
    }
    return json;
  }

  @override
  Future<List<PricingProfileSummary>> profiles({
    String afterId = '',
    int limit = 20,
  }) async {
    _session.require(PricingPermission.viewPublished);
    _limit(limit);
    final owner = _session.permissions.contains(PricingPermission.editDraft);
    final rows = await _db
        .customSelect(
          'SELECT id,name,status FROM universal_pricing_profiles WHERE business_id = ? AND id > ? '
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
  Future<UniversalStoredDraft> createProfile(
    String id,
    UniversalRateCardDraft card,
  ) async {
    _session.require(PricingPermission.createProfile);
    validateId(id);
    final json = _snapshot(card);
    return _db.transaction(() async {
      final now = _clock().millisecondsSinceEpoch;
      await _db.customStatement(
        'INSERT INTO universal_pricing_profiles (business_id,id,name,created_at,updated_at) VALUES (?,?,?,?,?)',
        [_business, id, card.name, now, now],
      );
      await _db.customStatement(
        'INSERT INTO universal_pricing_drafts VALUES (?,?,?,?)',
        [_business, id, 1, json],
      );
      await _audit(id, 'create_profile', null, json);
      return UniversalStoredDraft(id, 1, card);
    });
  }

  @override
  Future<UniversalStoredDraft> readDraft(String id) {
    _session.require(PricingPermission.editDraft);
    return _readDraft(id);
  }

  Future<UniversalStoredDraft> _readDraft(String id) async {
    final row = await _db
        .customSelect(
          'SELECT revision,snapshot_json FROM universal_pricing_drafts WHERE business_id = ? AND profile_id = ? LIMIT 1',
          variables: _scope(id),
        )
        .getSingleOrNull();
    if (row == null) {
      throw StateError('Pricing profile not found in this business');
    }
    final card = UniversalRateCardDraft.fromJson(
      jsonObject(row.read<String>('snapshot_json')),
    );
    card.validateForBusiness(_business);
    return UniversalStoredDraft(id, row.read<int>('revision'), card);
  }

  Future<UniversalStoredDraft> _editable(String id, int revision) async {
    final row = await _db
        .customSelect(
          'SELECT status FROM universal_pricing_profiles WHERE business_id = ? AND id = ? LIMIT 1',
          variables: _scope(id),
        )
        .getSingleOrNull();
    if (row == null || row.read<String>('status') == 'archived') {
      throw StateError('Profile is unavailable or archived');
    }
    final draft = await _readDraft(id);
    if (draft.revision != revision) {
      throw StateError('Draft changed; reload before saving or publishing');
    }
    return draft;
  }

  @override
  Future<UniversalStoredDraft> saveDraft(
    String id,
    UniversalRateCardDraft card, {
    required int expectedRevision,
  }) async {
    _session.require(PricingPermission.editDraft);
    final json = _snapshot(card);
    return _db.transaction(() async {
      final before = await _editable(id, expectedRevision);
      await _db.customStatement(
        'UPDATE universal_pricing_drafts SET revision = revision + 1,snapshot_json = ? WHERE business_id = ? AND profile_id = ?',
        [json, _business, id],
      );
      await _db.customStatement(
        'UPDATE universal_pricing_profiles SET name = ?,updated_at = ? WHERE business_id = ? AND id = ?',
        [card.name, _clock().millisecondsSinceEpoch, _business, id],
      );
      await _audit(id, 'edit_draft', _snapshot(before.card), json);
      return UniversalStoredDraft(id, expectedRevision + 1, card);
    });
  }

  @override
  Future<PublishedUniversalRateCard> publish(
    String id, {
    required int expectedRevision,
    required DateTime effectiveAt,
    DateTime? expiresAt,
  }) async {
    _session.require(PricingPermission.publish);
    if (expiresAt != null && !expiresAt.isAfter(effectiveAt)) {
      throw ArgumentError('Expiry must follow effective date');
    }
    // SQLite metadata uses epoch milliseconds. Normalize snapshot precision too.
    final effective = DateTime.fromMillisecondsSinceEpoch(
      effectiveAt.millisecondsSinceEpoch,
      isUtc: true,
    );
    final expiry = expiresAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            expiresAt.millisecondsSinceEpoch,
            isUtc: true,
          );
    if (expiry != null && !expiry.isAfter(effective)) {
      throw ArgumentError('Expiry must differ by at least one millisecond');
    }
    return _db.transaction(() async {
      final draft = await _editable(id, expectedRevision);
      draft.card.validateForBusiness(_business, publishing: true);
      for (final product in draft.card.products) {
        if (!await _taxPolicies.isApproved(_business, product.rule.tax)) {
          throw StateError('Tax policy is not approved for this business');
        }
      }
      final previous = await _db
          .customSelect(
            'SELECT version,effective_at,snapshot_json FROM universal_pricing_versions WHERE business_id = ? AND profile_id = ? ORDER BY version DESC LIMIT 1',
            variables: _scope(id),
          )
          .getSingleOrNull();
      if (previous != null &&
          effective.millisecondsSinceEpoch <
              previous.read<int>('effective_at')) {
        throw StateError(
          'A new version cannot precede the last published effective date',
        );
      }
      final version = (previous?.read<int>('version') ?? 0) + 1;
      final rebased = UniversalRateCardDraft.fromJson(
        Map<String, dynamic>.from(draft.card.toJson())
          ..['products'] = [
            for (final product in draft.card.products)
              product
                  .withRule(
                    UniversalPricingRule.fromJson(
                      Map<String, dynamic>.from(product.rule.toJson())
                        ..['version'] = version
                        ..['effectiveAt'] = effective.toIso8601String()
                        ..['expiresAt'] = expiry?.toIso8601String(),
                    ),
                  )
                  .toJson(),
          ],
      );
      _snapshot(rebased);
      final published = PublishedUniversalRateCard(
        businessId: _business,
        profileId: id,
        version: version,
        card: rebased,
        effectiveAt: effective,
        expiresAt: expiry,
        publishedAt: _clock().toUtc(),
        publishedBy: _session.actorId,
      );
      final json = canonicalJson(published.toJson());
      await _db.customStatement(
        'INSERT INTO universal_pricing_versions (business_id,profile_id,version,engine_version,effective_at,expires_at,published_at,published_by,snapshot_json) VALUES (?,?,?,?,?,?,?,?,?)',
        [
          _business,
          id,
          version,
          UniversalPricingEngine.version,
          effective.millisecondsSinceEpoch,
          expiry?.millisecondsSinceEpoch,
          published.publishedAt.millisecondsSinceEpoch,
          _session.actorId,
          json,
        ],
      );
      final prefix = <Object?>[_business, id, version];
      for (final category in rebased.categories) {
        await _db.customStatement(
          'INSERT INTO universal_pricing_categories VALUES (?,?,?,?,?,?,?)',
          [
            ...prefix,
            category.id,
            category.parentId,
            category.name,
            category.sortOrder,
          ],
        );
      }
      for (final product in rebased.products) {
        final rule = product.rule;
        final productPrefix = [...prefix, product.id];
        await _db.customStatement(
          'INSERT INTO universal_pricing_products VALUES (?,?,?,?,?,?,?,?,?,?)',
          [
            ...productPrefix,
            product.categoryId,
            product.name,
            rule.id,
            rule.strategy.kind.name,
            canonicalJson(product.attributes),
            canonicalJson(rule.toJson()),
          ],
        );
        for (final field in rule.schema.fields) {
          await _db.customStatement(
            'INSERT INTO universal_pricing_inputs VALUES (?,?,?,?,?,?,?)',
            [
              ...productPrefix,
              field.id,
              field.displayOrder,
              canonicalJson(field.toJson()),
            ],
          );
        }
        for (final rate in rule.rateLookup.rates) {
          await _db.customStatement(
            'INSERT INTO universal_pricing_rates VALUES (?,?,?,?,?,?,?,?,?)',
            [
              ...productPrefix,
              rate.id,
              rate.key,
              '${rate.amount}',
              rate.unit,
              canonicalJson(rate.selectors),
            ],
          );
        }
        await _db.customStatement(
          'INSERT INTO universal_pricing_unit_systems VALUES (?,?,?,?,?)',
          [...productPrefix, canonicalJson(rule.schema.units.toJson())],
        );
        for (final dimension in rule.inputBilling) {
          await _db.customStatement(
            'INSERT INTO universal_pricing_dimension_rules VALUES (?,?,?,?,?,?)',
            [
              ...productPrefix,
              dimension.fieldId,
              canonicalJson(dimension.toJson()),
            ],
          );
        }
        for (final addon in rule.extras) {
          await _db.customStatement(
            'INSERT INTO universal_pricing_addons VALUES (?,?,?,?,?,?)',
            [...productPrefix, addon.id, canonicalJson(addon.toJson())],
          );
        }
      }
      await _db.customStatement(
        'UPDATE universal_pricing_versions SET sealed = 1 WHERE business_id = ? AND profile_id = ? AND version = ?',
        prefix,
      );
      await _db.customStatement(
        "UPDATE universal_pricing_profiles SET status = 'published',updated_at = ? WHERE business_id = ? AND id = ?",
        [_clock().millisecondsSinceEpoch, _business, id],
      );
      await _db.customStatement(
        'UPDATE universal_pricing_drafts SET revision = revision + 1,snapshot_json = ? WHERE business_id = ? AND profile_id = ?',
        [_snapshot(rebased), _business, id],
      );
      await _audit(
        id,
        'publish',
        previous?.read<String>('snapshot_json'),
        json,
      );
      return published;
    });
  }

  PublishedUniversalRateCard _decode(QueryRow row, String id) {
    final card = PublishedUniversalRateCard.fromJson(
      jsonObject(row.read<String>('snapshot_json')),
    );
    if (card.businessId != _business ||
        card.profileId != id ||
        card.version != row.read<int>('version')) {
      throw StateError(
        'Stored rate-card identity does not match this business',
      );
    }
    return card;
  }

  @override
  Future<PublishedUniversalRateCard?> activeCard(
    String id, {
    required DateTime at,
  }) async {
    _session.require(PricingPermission.viewPublished);
    final row = await _db
        .customSelect(
          'SELECT v.* FROM universal_pricing_versions v JOIN universal_pricing_profiles p ON p.business_id = v.business_id AND p.id = v.profile_id '
          "WHERE v.business_id = ? AND v.profile_id = ? AND p.status = 'published' AND v.sealed = 1 AND v.effective_at <= ? ORDER BY v.effective_at DESC,v.version DESC LIMIT 1",
          variables: [..._scope(id), Variable(at.millisecondsSinceEpoch)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    final expiry = row.readNullable<int>('expires_at');
    // Never fall back to a superseded version when the latest one expires.
    if (expiry != null && at.millisecondsSinceEpoch >= expiry) return null;
    return _decode(row, id);
  }

  @override
  Future<PublishedUniversalRateCard> readVersion(String id, int version) async {
    _session.require(PricingPermission.viewPublished);
    final row = await _db
        .customSelect(
          'SELECT version,snapshot_json FROM universal_pricing_versions WHERE business_id = ? AND profile_id = ? AND version = ? AND sealed = 1 LIMIT 1',
          variables: [..._scope(id), Variable(version)],
        )
        .getSingleOrNull();
    if (row == null) {
      throw StateError('Published rate-card version is unavailable');
    }
    return _decode(row, id);
  }

  @override
  Future<List<PublishedUniversalRateCard>> history(
    String id, {
    int beforeVersion = 2147483647,
    int limit = 20,
  }) async {
    _session.require(PricingPermission.viewPublished);
    _limit(limit);
    final rows = await _db
        .customSelect(
          'SELECT version,snapshot_json FROM universal_pricing_versions WHERE business_id = ? AND profile_id = ? AND version < ? AND sealed = 1 ORDER BY version DESC LIMIT ?',
          variables: [..._scope(id), Variable(beforeVersion), Variable(limit)],
        )
        .get();
    return rows.map((r) => _decode(r, id)).toList();
  }

  @override
  Future<void> archive(String id) async {
    _session.require(PricingPermission.publish);
    await _db.transaction(() async {
      final draft = await _readDraft(id);
      await _editable(id, draft.revision);
      await _db.customStatement(
        "UPDATE universal_pricing_profiles SET status = 'archived',updated_at = ? WHERE business_id = ? AND id = ?",
        [_clock().millisecondsSinceEpoch, _business, id],
      );
      await _audit(
        id,
        'archive',
        _snapshot(draft.card),
        canonicalJson({'status': 'archived'}),
      );
    });
  }

  Future<void> _audit(String id, String action, String? before, String after) =>
      _db.customStatement(
        'INSERT INTO universal_pricing_audit_events (business_id,actor_uid,action,profile_id,before_snapshot,after_snapshot,created_at) VALUES (?,?,?,?,?,?,?)',
        [
          _business,
          _session.actorId,
          action,
          id,
          before,
          after,
          _clock().millisecondsSinceEpoch,
        ],
      );
}
