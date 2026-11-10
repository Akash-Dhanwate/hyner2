import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/pricing_database.dart' show PricingDatabase;
import 'package:hyner/features/pricing/data/local_universal_rate_card_repository.dart';
import 'package:hyner/features/pricing/domain/exact.dart';
import 'package:hyner/features/pricing/domain/pricing_models.dart';
import 'package:hyner/features/pricing/domain/pricing_repository.dart';
import 'package:hyner/features/pricing/domain/serialization.dart';
import 'package:hyner/features/pricing/domain/universal/rate_card.dart';
import 'package:hyner/features/pricing/domain/universal/universal_pricing.dart';

import 'support/universal_fixture.dart' as f;

class ApprovedTaxes implements BusinessTaxPolicies {
  bool approved = true;
  @override
  Future<bool> isApproved(String businessId, TaxPolicy policy) async =>
      approved &&
      policy.reference == 'approved-zero' &&
      policy.percent == Exact.zero;
}

PricingSession owner([String business = 'business']) => PricingSession(
  businessId: business,
  actorId: 'owner',
  permissions: PricingPermission.values.toSet(),
);

UniversalRateCardDraft card({
  String amount = '150',
  String business = 'business',
}) {
  final rule = f.rule(
    strategy: f.measured(
      StrategyKind.area,
      f.mul(f.ref('height'), f.ref('width')),
      'base',
      'ft2',
    ),
    rates: [f.rate('base', amount, 'ft2')],
    fields: [f.number('height', 'ft'), f.number('width', 'ft')],
  );
  return UniversalRateCardDraft(
    name: 'Door prices',
    currency: Currency('INR', 2),
    categories: [PricingCategory(id: 'doors', name: 'Doors')],
    products: [
      UniversalProduct(
        categoryId: 'doors',
        name: 'Flush door',
        attributes: const {'finish': 'Plain'},
        rule: UniversalPricingRule.fromJson(
          Map<String, dynamic>.from(rule.toJson())..['businessId'] = business,
        ),
      ),
    ],
  );
}

void main() {
  late PricingDatabase db;
  late ApprovedTaxes taxes;
  late LocalUniversalRateCardRepository repo;
  setUp(() {
    db = PricingDatabase(NativeDatabase.memory());
    taxes = ApprovedTaxes();
    repo = LocalUniversalRateCardRepository(
      db,
      owner(),
      taxes,
      clock: () => f.at,
    );
  });
  tearDown(() => db.close());

  test('publishes normalized definitions and restores an exact working calculation', () async {
    await repo.createProfile('doors', card());
    final published = await repo.publish(
      'doors',
      expectedRevision: 1,
      effectiveAt: f.at,
    );
    final restored = (await repo.activeCard('doors', at: f.at))!;
    expect(canonicalJson(restored.toJson()), canonicalJson(published.toJson()));
    final result = f.price(
      restored.card.products.single.rule,
      inputs: {'height': f.n('7', 'ft'), 'width': f.n('3', 'ft')},
      quantity: 3,
    );
    expect(result.amounts.totalMinor, BigInt.from(945000));
    expect((await repo.readDraft('doors')).revision, 2);
    for (final table in ['categories', 'products', 'rates', 'unit_systems']) {
      expect(
        await db.customSelect('SELECT * FROM universal_pricing_$table').get(),
        hasLength(1),
      );
    }
    expect(
      await db.customSelect('SELECT * FROM universal_pricing_inputs').get(),
      hasLength(2),
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test(
    'empty configuration persists without invented rates and cannot publish',
    () async {
      final empty = UniversalRateCardDraft(
        name: 'New shop',
        currency: Currency('INR', 2),
      );
      await repo.createProfile('empty', empty);
      expect((await repo.readDraft('empty')).card.products, isEmpty);
      await expectLater(
        repo.publish('empty', expectedRevision: 1, effectiveAt: f.at),
        throwsStateError,
      );
      expect(await repo.activeCard('empty', at: f.at), isNull);
    },
  );

  test(
    'new rates leave historical calculation snapshots byte-for-byte stable',
    () async {
      await repo.createProfile('doors', card());
      final original = await repo.publish(
        'doors',
        expectedRevision: 1,
        effectiveAt: f.at,
      );
      final inputs = {'height': f.n('7', 'ft'), 'width': f.n('3', 'ft')};
      final snapshot = f
          .price(original.card.products.single.rule, inputs: inputs)
          .snapshotJson;
      final draft = await repo.saveDraft(
        'doors',
        card(amount: '200'),
        expectedRevision: 2,
      );
      final next = await repo.publish(
        'doors',
        expectedRevision: draft.revision,
        effectiveAt: f.at,
      );
      expect(next.version, 2);
      expect(
        f
            .price(next.card.products.single.rule, inputs: inputs)
            .amounts
            .totalMinor,
        BigInt.from(420000),
      );
      final old = await repo.readVersion('doors', 1);
      expect(
        f.price(old.card.products.single.rule, inputs: inputs).snapshotJson,
        snapshot,
      );
      expect((await repo.history('doors', limit: 1)).single.version, 2);
      expect((await repo.history('doors', beforeVersion: 2)).single.version, 1);
    },
  );

  test(
    'stale edits and double publish do not overwrite or duplicate versions',
    () async {
      await repo.createProfile('doors', card());
      await repo.saveDraft('doors', card(amount: '170'), expectedRevision: 1);
      await expectLater(
        repo.saveDraft('doors', card(), expectedRevision: 1),
        throwsStateError,
      );
      final attempts = await Future.wait([
        for (var i = 0; i < 2; i++)
          repo
              .publish('doors', expectedRevision: 2, effectiveAt: f.at)
              .then<Object>((value) => value, onError: (Object e) => e),
      ]);
      expect(attempts.whereType<PublishedUniversalRateCard>(), hasLength(1));
      expect(attempts.whereType<StateError>(), hasLength(1));
      expect(await repo.history('doors'), hasLength(1));
    },
  );

  test(
    'cashiers read published rates but cannot edit, publish or archive',
    () async {
      await repo.createProfile('draft', card());
      await repo.createProfile('doors', card());
      await repo.publish('doors', expectedRevision: 1, effectiveAt: f.at);
      final cashier = LocalUniversalRateCardRepository(
        db,
        PricingSession(
          businessId: 'business',
          actorId: 'cashier',
          permissions: PricingPermission.cashier,
        ),
        taxes,
      );
      expect((await cashier.profiles()).single.id, 'doors');
      expect(() => cashier.readDraft('doors'), throwsStateError);
      await expectLater(cashier.createProfile('bad', card()), throwsStateError);
      await expectLater(
        cashier.saveDraft('doors', card(), expectedRevision: 2),
        throwsStateError,
      );
      await expectLater(
        cashier.publish('doors', expectedRevision: 2, effectiveAt: f.at),
        throwsStateError,
      );
      await expectLater(cashier.archive('doors'), throwsStateError);
      expect(await cashier.activeCard('doors', at: f.at), isNotNull);
    },
  );

  test(
    'business scoping applies to writes, reads, history and identical IDs',
    () async {
      await repo.createProfile('doors', card());
      await repo.publish('doors', expectedRevision: 1, effectiveAt: f.at);
      final other = LocalUniversalRateCardRepository(db, owner('other'), taxes);
      expect(await other.profiles(), isEmpty);
      expect(await other.activeCard('doors', at: f.at), isNull);
      expect(await other.history('doors'), isEmpty);
      await expectLater(other.readVersion('doors', 1), throwsStateError);
      await expectLater(
        other.createProfile('doors', card()),
        throwsArgumentError,
      );
      await other.createProfile(
        'doors',
        card(business: 'other', amount: '500'),
      );
      expect(
        (await repo.readDraft('doors'))
            .card
            .products
            .single
            .rule
            .rateLookup
            .rates
            .single
            .amount,
        f.e('150'),
      );
      expect(
        (await other.readDraft('doors'))
            .card
            .products
            .single
            .rule
            .rateLookup
            .rates
            .single
            .amount,
        f.e('500'),
      );
    },
  );

  test('unapproved tax and failed child insertion roll back publication atomically', () async {
    await repo.createProfile('doors', card());
    taxes.approved = false;
    await expectLater(
      repo.publish('doors', expectedRevision: 1, effectiveAt: f.at),
      throwsStateError,
    );
    taxes.approved = true;
    await db.customStatement(
      "CREATE TRIGGER fail_rates BEFORE INSERT ON universal_pricing_rates BEGIN SELECT RAISE(ABORT, 'simulated failure'); END",
    );
    await expectLater(
      repo.publish('doors', expectedRevision: 1, effectiveAt: f.at),
      throwsA(anything),
    );
    expect(await repo.history('doors'), isEmpty);
    expect((await repo.readDraft('doors')).revision, 1);
    expect((await repo.profiles()).single.status, 'draft');
    expect(
      await db.customSelect('SELECT * FROM universal_pricing_categories').get(),
      isEmpty,
    );
    expect(
      await db
          .customSelect('SELECT * FROM universal_pricing_audit_events')
          .get(),
      hasLength(1),
    );
  });

  test(
    'effective dates, expiry and archive never fall back to stale rates',
    () async {
      await repo.createProfile('doors', card());
      await repo.publish('doors', expectedRevision: 1, effectiveAt: f.at);
      final tomorrow = f.at.add(const Duration(days: 1));
      final expiry = tomorrow.add(const Duration(days: 1));
      await repo.publish(
        'doors',
        expectedRevision: 2,
        effectiveAt: tomorrow,
        expiresAt: expiry,
      );
      expect((await repo.activeCard('doors', at: f.at))!.version, 1);
      expect((await repo.activeCard('doors', at: tomorrow))!.version, 2);
      expect(await repo.activeCard('doors', at: expiry), isNull);
      await expectLater(
        repo.publish('doors', expectedRevision: 3, effectiveAt: f.at),
        throwsStateError,
      );
      await repo.archive('doors');
      expect(await repo.activeCard('doors', at: tomorrow), isNull);
      expect(await repo.readVersion('doors', 1), isNotNull);
      await expectLater(
        repo.saveDraft('doors', card(), expectedRevision: 3),
        throwsStateError,
      );
    },
  );

  test(
    'published rows and audit events are immutable even through raw SQL',
    () async {
      await repo.createProfile('doors', card());
      await repo.publish('doors', expectedRevision: 1, effectiveAt: f.at);
      for (final table in [
        'versions',
        'categories',
        'products',
        'inputs',
        'rates',
        'unit_systems',
        'audit_events',
      ]) {
        await expectLater(
          db.customStatement('DELETE FROM universal_pricing_$table'),
          throwsA(predicate((e) => '$e'.contains('immutable'))),
        );
      }
      await expectLater(
        db.customStatement('UPDATE universal_pricing_versions SET sealed = 0'),
        throwsA(anything),
      );
      await expectLater(
        db.customStatement(
          "UPDATE universal_pricing_rates SET amount_decimal = '0'",
        ),
        throwsA(anything),
      );
      expect(await repo.history('doors'), hasLength(1));
    },
  );

  test('repository queries are bounded', () async {
    await expectLater(repo.profiles(limit: 0), throwsArgumentError);
    await expectLater(repo.history('doors', limit: 51), throwsArgumentError);
    await repo.createProfile('a', card());
    await repo.createProfile('b', card());
    expect((await repo.profiles(limit: 1)).single.id, 'a');
    expect((await repo.profiles(afterId: 'a', limit: 1)).single.id, 'b');
  });

  test('on-disk drafts and published rules survive close and reopen', () async {
    final dir = await Directory.systemTemp.createTemp('hyner-universal-');
    final file = File('${dir.path}/prices.sqlite');
    var disk = PricingDatabase(NativeDatabase(file));
    try {
      var store = LocalUniversalRateCardRepository(disk, owner(), taxes);
      await store.createProfile('doors', card());
      final original = await store.publish(
        'doors',
        expectedRevision: 1,
        effectiveAt: f.at,
      );
      await disk.close();
      disk = PricingDatabase(NativeDatabase(file));
      store = LocalUniversalRateCardRepository(disk, owner(), taxes);
      expect(
        canonicalJson((await store.readVersion('doors', 1)).toJson()),
        canonicalJson(original.toJson()),
      );
      expect((await store.readDraft('doors')).revision, 2);
    } finally {
      await disk.close();
      await dir.delete(recursive: true);
    }
  });

  test(
    'v2 migration preserves legacy snapshots and unrelated inventory data',
    () async {
      final migrated = PricingDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              File('test/fixtures/pricing_schema_v2.sql').readAsStringSync(),
            );
            raw.execute(
              "INSERT INTO pricing_profiles VALUES ('old-business','old','Old','published',1,2)",
            );
            raw.execute(
              "INSERT INTO pricing_drafts VALUES ('old-business','old',3,'original-draft')",
            );
            raw.execute(
              "INSERT INTO pricing_rate_card_versions VALUES ('old-business','old',1,1,NULL,2,'owner','original-published',1)",
            );
            raw.execute(
              'CREATE TABLE stock_records (sku TEXT PRIMARY KEY, quantity INTEGER)',
            );
            raw.execute("INSERT INTO stock_records VALUES ('hinge',42)");
          },
        ),
      );
      try {
        final store = LocalUniversalRateCardRepository(
          migrated,
          owner(),
          taxes,
        );
        await store.createProfile('new', card());
        await store.publish('new', expectedRevision: 1, effectiveAt: f.at);
        expect(
          (await migrated
                  .customSelect(
                    'SELECT snapshot_json FROM pricing_rate_card_versions',
                  )
                  .getSingle())
              .read<String>('snapshot_json'),
          'original-published',
        );
        expect(
          (await migrated
                  .customSelect('SELECT snapshot_json FROM pricing_drafts')
                  .getSingle())
              .read<String>('snapshot_json'),
          'original-draft',
        );
        expect(
          (await migrated
                  .customSelect('SELECT quantity FROM stock_records')
                  .getSingle())
              .read<int>('quantity'),
          42,
        );
        expect(
          (await migrated.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          4,
        );
        expect(
          await migrated.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        await expectLater(
          migrated.customStatement('DELETE FROM pricing_rate_card_versions'),
          throwsA(anything),
        );
      } finally {
        await migrated.close();
      }
    },
  );
}
