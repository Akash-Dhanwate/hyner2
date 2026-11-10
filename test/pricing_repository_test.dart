import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/pricing_database.dart' show PricingDatabase;
import 'package:hyner/features/pricing/data/local_rate_card_repository.dart';
import 'package:hyner/features/pricing/domain/door_template.dart';
import 'package:hyner/features/pricing/domain/exact.dart';
import 'package:hyner/features/pricing/domain/measurements.dart';
import 'package:hyner/features/pricing/domain/pricing_engine.dart';
import 'package:hyner/features/pricing/domain/pricing_models.dart';
import 'package:hyner/features/pricing/domain/pricing_repository.dart';
import 'package:hyner/features/pricing/domain/serialization.dart';

final now = DateTime.utc(2026, 11, 8);
final tax = TaxPolicy(
  reference: 'tax-exempt-v1',
  behavior: TaxBehavior.exempt,
  percent: Exact.zero,
);

class ApprovedTaxes implements BusinessTaxPolicies {
  bool approved = true;
  @override
  Future<bool> isApproved(String businessId, TaxPolicy policy) async =>
      approved && canonicalJson(policy.toJson()) == canonicalJson(tax.toJson());
}

RateCardDraft card([String rate = '150']) => RateCardDraft(
  name: 'Door rates',
  currency: Currency('INR', 2),
  categories: [PricingCategory(id: 'door', name: 'Door')],
  rules: [
    PricingRule(
      id: 'door-rule',
      categoryId: 'door',
      method: PricingMethod.squareFoot,
      rate: Exact.parse(rate),
      tax: tax,
    ),
  ],
);
PricingSession owner([String business = 'business-a']) => PricingSession(
  businessId: business,
  actorId: 'owner',
  permissions: PricingPermission.values.toSet(),
);
LocalRateCardRepository repository(
  PricingDatabase db, {
  PricingSession? session,
  ApprovedTaxes? taxes,
}) => LocalRateCardRepository(
  db,
  session ?? owner(),
  taxes ?? ApprovedTaxes(),
  clock: () => now,
);

void main() {
  late PricingDatabase db;
  late LocalRateCardRepository repo;
  setUp(() {
    db = PricingDatabase(NativeDatabase.memory());
    repo = repository(db);
  });
  tearDown(() => db.close());

  test(
    'profile listing is scoped, bounded and hides drafts from cashiers',
    () async {
      await repo.createProfile('a', card());
      await repo.createProfile('b', card());
      await repo.publish('b', expectedRevision: 1, effectiveAt: now);
      expect((await repo.profiles(limit: 1)).single.id, 'a');
      expect((await repo.profiles(afterId: 'a')).single.id, 'b');
      final cashier = repository(
        db,
        session: PricingSession(
          businessId: 'business-a',
          actorId: 'cashier',
          permissions: PricingPermission.cashier,
        ),
      );
      expect((await cashier.profiles()).single.id, 'b');
      expect(
        await repository(db, session: owner('business-b')).profiles(),
        isEmpty,
      );
      await expectLater(repo.profiles(limit: 101), throwsArgumentError);
      await repo.archive('b');
      expect(await cashier.profiles(), isEmpty);
    },
  );

  test('calculation inputs replay from deterministic JSON after process boundaries', () async {
    await repo.createProfile('doors', card());
    final published = await repo.publish(
      'doors',
      expectedRevision: 1,
      effectiveAt: now,
    );
    final input = PricingInput(
      categoryId: 'door',
      quantity: 3,
      dimensions: Dimensions.entered({
        Axis.height: Exact.integer(84),
        Axis.width: Exact.integer(36),
      }, LengthUnit.inches),
    );
    final restored = PricingInput.fromJson(
      jsonObject(canonicalJson(input.toJson())),
    );
    expect(
      PricingEngine().calculate(published, restored, at: now).snapshotJson,
      PricingEngine().calculate(published, input, at: now).snapshotJson,
    );
  });

  test(
    'fresh database persists draft and normalized immutable publication',
    () async {
      final draft = await repo.createProfile('doors', card());
      expect(draft.revision, 1);
      expect(await repo.activeCard('doors', at: now), isNull);
      final published = await repo.publish(
        'doors',
        expectedRevision: 1,
        effectiveAt: now,
      );
      expect(published.version, 1);
      expect((await repo.readDraft('doors')).revision, 2);
      expect(
        canonicalJson((await repo.activeCard('doors', at: now))!.toJson()),
        canonicalJson(published.toJson()),
      );
      expect(
        await db.customSelect('SELECT * FROM pricing_categories').get(),
        hasLength(1),
      );
      expect(
        await db.customSelect('SELECT * FROM pricing_rule_versions').get(),
        hasLength(1),
      );
      expect(
        await db.customSelect('SELECT * FROM pricing_audit_events').get(),
        hasLength(2),
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test(
    'door template is editable but cannot publish missing merchant rates',
    () async {
      await repo.createProfile('doors', doorTemplate(Currency('INR', 2)));
      await expectLater(
        repo.publish('doors', expectedRevision: 1, effectiveAt: now),
        throwsStateError,
      );
      expect(await repo.history('doors'), isEmpty);
      expect((await repo.readDraft('doors')).revision, 1);
    },
  );

  test(
    'draft save and publishing reject stale revisions and duplicate taps',
    () async {
      await repo.createProfile('doors', card());
      await repo.saveDraft('doors', card('200'), expectedRevision: 1);
      await expectLater(
        repo.saveDraft('doors', card('1'), expectedRevision: 1),
        throwsStateError,
      );
      await expectLater(
        repo.publish('doors', expectedRevision: 1, effectiveAt: now),
        throwsStateError,
      );
      await repo.publish('doors', expectedRevision: 2, effectiveAt: now);
      await expectLater(
        repo.publish('doors', expectedRevision: 2, effectiveAt: now),
        throwsStateError,
      );
      expect(await repo.history('doors'), hasLength(1));
    },
  );

  test('concurrent publication has one winner', () async {
    await repo.createProfile('doors', card());
    Future<bool> attempt() async {
      try {
        await repo.publish('doors', expectedRevision: 1, effectiveAt: now);
        return true;
      } on StateError {
        return false;
      }
    }

    final results = await Future.wait([attempt(), attempt()]);
    expect(results.where((value) => value), hasLength(1));
    expect(await repo.history('doors'), hasLength(1));
  });

  test(
    'cashier can load published rates but cannot read drafts or mutate rates',
    () async {
      await repo.createProfile('doors', card());
      await repo.publish('doors', expectedRevision: 1, effectiveAt: now);
      final cashier = repository(
        db,
        session: PricingSession(
          businessId: 'business-a',
          actorId: 'cashier',
          permissions: PricingPermission.cashier,
        ),
      );
      expect(await cashier.activeCard('doors', at: now), isNotNull);
      expect(() => cashier.readDraft('doors'), throwsStateError);
      await expectLater(
        cashier.saveDraft('doors', card('1'), expectedRevision: 2),
        throwsStateError,
      );
      await expectLater(
        cashier.publish('doors', expectedRevision: 2, effectiveAt: now),
        throwsStateError,
      );
      await expectLater(
        cashier.createProfile('other', card()),
        throwsStateError,
      );
      await expectLater(cashier.archive('doors'), throwsStateError);
      expect(
        PricingPermission.cashier,
        isNot(contains(PricingPermission.convertToSale)),
      );
      expect(
        PricingPermission.cashier,
        isNot(contains(PricingPermission.viewCost)),
      );
    },
  );

  test(
    'same profile ID is isolated across businesses on every repository path',
    () async {
      await repo.createProfile('doors', card());
      await repo.publish('doors', expectedRevision: 1, effectiveAt: now);
      final other = repository(db, session: owner('business-b'));
      expect(await other.activeCard('doors', at: now), isNull);
      await expectLater(other.readVersion('doors', 1), throwsStateError);
      await expectLater(other.readDraft('doors'), throwsStateError);
      await expectLater(
        other.saveDraft('doors', card(), expectedRevision: 2),
        throwsStateError,
      );
      await expectLater(
        other.publish('doors', expectedRevision: 2, effectiveAt: now),
        throwsStateError,
      );
      await expectLater(other.archive('doors'), throwsStateError);
      expect(await other.history('doors'), isEmpty);
      await other.createProfile('doors', card('500'));
      await other.publish('doors', expectedRevision: 1, effectiveAt: now);
      expect(
        (await other.readVersion('doors', 1)).card.rules.single.rate,
        Exact.integer(500),
      );
      expect(
        (await repo.readVersion('doors', 1)).card.rules.single.rate,
        Exact.integer(150),
      );
    },
  );

  test('failed tax validation rolls back publication and audit', () async {
    final taxes = ApprovedTaxes()..approved = false;
    final unapproved = repository(db, taxes: taxes);
    await unapproved.createProfile('doors', card());
    await expectLater(
      unapproved.publish('doors', expectedRevision: 1, effectiveAt: now),
      throwsStateError,
    );
    expect(await repo.history('doors'), isEmpty);
    expect((await repo.readDraft('doors')).revision, 1);
    expect(
      await db.customSelect('SELECT * FROM pricing_audit_events').get(),
      hasLength(1),
    );
    taxes.approved = true;
    expect(
      (await unapproved.publish(
        'doors',
        expectedRevision: 1,
        effectiveAt: now,
      )).version,
      1,
    );
  });

  test(
    'scheduled versions switch at effective date; expiry cannot fall back',
    () async {
      await repo.createProfile('doors', card());
      await repo.publish('doors', expectedRevision: 1, effectiveAt: now);
      final tomorrow = now.add(const Duration(days: 1));
      final expiry = now.add(const Duration(days: 2));
      await repo.saveDraft('doors', card('200'), expectedRevision: 2);
      await repo.publish(
        'doors',
        expectedRevision: 3,
        effectiveAt: tomorrow,
        expiresAt: expiry,
      );
      expect((await repo.activeCard('doors', at: now))!.version, 1);
      expect((await repo.activeCard('doors', at: tomorrow))!.version, 2);
      await expectLater(repo.activeCard('doors', at: expiry), throwsStateError);
      await expectLater(
        repo.publish('doors', expectedRevision: 4, effectiveAt: now),
        throwsStateError,
      );
      expect(
        await repo.activeCard(
          'doors',
          at: now.subtract(const Duration(seconds: 1)),
        ),
        isNull,
      );
    },
  );

  test(
    'historical snapshot and result survive later rate changes and archive',
    () async {
      await repo.createProfile('doors', card());
      final first = await repo.publish(
        'doors',
        expectedRevision: 1,
        effectiveAt: now,
      );
      final input = PricingInput(
        categoryId: 'door',
        quantity: 3,
        dimensions: Dimensions.entered({
          Axis.height: Exact.integer(84),
          Axis.width: Exact.integer(36),
        }, LengthUnit.inches),
      );
      final snapshot = PricingEngine()
          .calculate(first, input, at: now)
          .snapshotJson;
      await repo.saveDraft('doors', card('200'), expectedRevision: 2);
      await repo.publish('doors', expectedRevision: 3, effectiveAt: now);
      final loaded = await repo.readVersion('doors', 1);
      expect(
        PricingEngine().calculate(loaded, input, at: now).snapshotJson,
        snapshot,
      );
      expect(
        PricingEngine()
            .calculate(
              (await repo.activeCard('doors', at: now))!,
              input,
              at: now,
            )
            .totalMinor,
        BigInt.from(1260000),
      );
      await repo.archive('doors');
      expect(await repo.activeCard('doors', at: now), isNull);
      expect((await repo.readVersion('doors', 1)).version, 1);
      await expectLater(
        repo.saveDraft('doors', card(), expectedRevision: 4),
        throwsStateError,
      );
    },
  );

  test(
    'database rejects mutation, deletion and late inserts into sealed cards',
    () async {
      await repo.createProfile('doors', card());
      await repo.publish('doors', expectedRevision: 1, effectiveAt: now);
      for (final sql in [
        "UPDATE pricing_rate_card_versions SET sealed = 0",
        "DELETE FROM pricing_rate_card_versions",
        "UPDATE pricing_categories SET name = 'Tampered'",
        "DELETE FROM pricing_rule_versions",
        "INSERT INTO pricing_categories VALUES ('business-a','doors',1,'extra',NULL,'Extra',1,'{}')",
        "UPDATE pricing_audit_events SET actor_uid = 'other'",
        "DELETE FROM pricing_audit_events",
        "INSERT INTO pricing_drafts VALUES ('business-b','doors',1,'{}')",
      ]) {
        await expectLater(db.customStatement(sql), throwsA(isA<Exception>()));
      }
      expect(
        (await repo.readVersion('doors', 1)).card.categories.single.name,
        'Door',
      );
    },
  );

  test('history is bounded and uses version cursor', () async {
    await repo.createProfile('doors', card());
    await repo.publish('doors', expectedRevision: 1, effectiveAt: now);
    await repo.publish('doors', expectedRevision: 2, effectiveAt: now);
    expect((await repo.history('doors', limit: 1)).single.version, 2);
    expect(
      (await repo.history('doors', beforeVersion: 2, limit: 1)).single.version,
      1,
    );
    await expectLater(repo.history('doors', limit: 1000), throwsArgumentError);
  });

  test(
    'file-backed drafts and published rules survive closing/reopening',
    () async {
      final temp = await Directory.systemTemp.createTemp('hyner-pricing-test-');
      final file = File('${temp.path}/pricing.sqlite');
      final firstDb = PricingDatabase(NativeDatabase(file));
      try {
        final firstRepo = repository(firstDb);
        await firstRepo.createProfile('doors', card());
        await firstRepo.publish('doors', expectedRevision: 1, effectiveAt: now);
      } finally {
        await firstDb.close();
      }
      final secondDb = PricingDatabase(NativeDatabase(file));
      try {
        final secondRepo = repository(secondDb);
        expect((await secondRepo.readDraft('doors')).revision, 2);
        expect(
          (await secondRepo.activeCard(
            'doors',
            at: now,
          ))!.card.rules.single.rate,
          Exact.integer(150),
        );
      } finally {
        await secondDb.close();
        await temp.delete(recursive: true);
      }
    },
  );

  test(
    'v1 to current migration preserves drafts and unrelated business records',
    () async {
      final original = canonicalJson(card().toJson());
      final migrated = PricingDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              File('test/fixtures/pricing_schema_v1.sql').readAsStringSync(),
            );
            raw.execute(
              "INSERT INTO pricing_profiles VALUES ('business-a','doors','Door rates','draft',1,2)",
            );
            raw.execute(
              "INSERT INTO pricing_drafts VALUES ('business-a','doors',7,?)",
              [original],
            );
            raw.execute(
              'CREATE TABLE unrelated_records (id TEXT PRIMARY KEY, value TEXT NOT NULL)',
            );
            raw.execute(
              "INSERT INTO unrelated_records VALUES ('stock','unchanged')",
            );
          },
        ),
      );
      try {
        final migratedRepo = repository(migrated);
        final draft = await migratedRepo.readDraft('doors');
        expect(draft.revision, 7);
        expect(canonicalJson(draft.card.toJson()), original);
        expect(
          (await migrated
                  .customSelect('SELECT value FROM unrelated_records')
                  .getSingle())
              .read<String>('value'),
          'unchanged',
        );
        expect(
          (await migrated.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          4,
        );
        await migratedRepo.publish(
          'doors',
          expectedRevision: 7,
          effectiveAt: now,
        );
        expect(
          await migrated.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await migrated.close();
      }
    },
  );
}
