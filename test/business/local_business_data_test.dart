import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/features/inventory/data/local_inventory_repository.dart';
import 'package:hyner/features/inventory/domain/inventory_repository.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/purchases/data/local_purchase_repository.dart';
import 'package:hyner/features/purchases/domain/purchase.dart';
import 'package:hyner/features/reports/data/local_reports_repository.dart';
import 'package:hyner/features/sales/data/local_sales_repository.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/inventory_fakes.dart';

void main() {
  late Directory directory;
  late LocalBusinessDatabase store;
  late LocalInventoryRepository inventory;
  late LocalSalesRepository sales;
  late LocalPurchaseRepository purchases;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hyner-business-data-');
    store = LocalBusinessDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    inventory = LocalInventoryRepository(store);
    sales = LocalSalesRepository(store);
    purchases = LocalPurchaseRepository(store);
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<Product> seed(
    String sku, {
    String uid = 'alice',
    int units = 10,
  }) async {
    await inventory.create(
      uid,
      ProductDraft(
        sku: sku,
        name: 'Item $sku',
        currency: 'INR',
        costMinor: 50,
        priceMinor: 100,
        openingStock: units,
        reorderLevel: 1,
      ),
      'opening_$sku',
    );
    return inventory.get(uid, sku);
  }

  SaleDraft bill(Product product, {int quantity = 1, int? initialPayment}) =>
      SaleDraft(
        currency: 'INR',
        initialPaymentMinor: initialPayment,
        customerName: 'Test Buyer',
        customerPhone: '9876543210',
        lines: [SaleLine.fromProduct(product, quantity)],
      );

  test(
    'payment retries and concurrent taps record one partial payment',
    () async {
      final product = await seed('A');
      await sales.create('alice', 'pay_bill', bill(product, quantity: 10));
      await Future.wait([
        sales.recordPayment('alice', 'pay_bill', 100, operationId: 'payment1'),
        sales.recordPayment('alice', 'pay_bill', 100, operationId: 'payment1'),
      ]);
      final saved = await sales.get('alice', 'pay_bill');
      expect(saved.paidMinor, 100);
      expect(saved.remainingMinor, 900);
      expect(saved.payments.length, 1);
      await expectLater(
        sales.recordPayment('alice', 'pay_bill', 200, operationId: 'payment1'),
        throwsA(isA<AppFailure>()),
      );
      await sales.recordPayment(
        'alice',
        'pay_bill',
        100,
        operationId: 'payment2',
      );
      expect((await sales.get('alice', 'pay_bill')).paidMinor, 200);
      expect((await inventory.get('alice', 'A')).quantity, 0);
    },
  );

  test(
    'zero first payment round-trips and retries deduct stock once',
    () async {
      final product = await seed('A');
      final draft = bill(product, initialPayment: 0);
      await Future.wait([
        sales.create('alice', 'bill1', draft),
        sales.create('alice', 'bill1', draft),
      ]);
      await sales.create('alice', 'bill1', draft);
      expect((await sales.get('alice', 'bill1')).draft.firstPaymentMinor, 0);
      expect((await inventory.get('alice', 'A')).quantity, 9);
      final db = await store.databaseFor('alice');
      expect(await db.query('sales'), hasLength(1));
      expect(
        await db.query('movements', where: 'type = ?', whereArgs: ['sale']),
        hasLength(1),
      );
      await expectLater(
        sales.create('alice', 'bill1', bill(product)),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  test('shortage on final line rolls back all stock and history', () async {
    final a = await seed('A');
    final b = await seed('B', units: 1);
    await expectLater(
      sales.create(
        'alice',
        'shortage',
        SaleDraft(
          currency: 'INR',
          customerName: 'Test Buyer',
          customerPhone: '9876543210',
          lines: [SaleLine.fromProduct(a, 2), SaleLine.fromProduct(b, 2)],
        ),
      ),
      throwsA(isA<AppFailure>()),
    );
    expect((await inventory.get('alice', 'A')).quantity, 10);
    expect((await inventory.get('alice', 'B')).quantity, 1);
    final db = await store.databaseFor('alice');
    expect(await db.query('sales'), isEmpty);
    expect(await db.query('movements'), hasLength(2));
  });

  test(
    'reused opening ID cannot silently accept changed product details',
    () async {
      await seed('A');
      await expectLater(
        inventory.create(
          'alice',
          ProductDraft(
            sku: 'A',
            name: 'Changed item',
            currency: 'INR',
            costMinor: 50,
            priceMinor: 200,
            openingStock: 10,
            reorderLevel: 1,
          ),
          'opening_A',
        ),
        throwsA(isA<AppFailure>()),
      );
      expect((await inventory.get('alice', 'A')).priceMinor, 100);
    },
  );

  test('concurrent separate bills cannot oversell', () async {
    final product = await seed('A');
    final outcomes = await Future.wait(
      ['one', 'two'].map((id) async {
        try {
          await sales.create('alice', id, bill(product, quantity: 7));
          return true;
        } on AppFailure {
          return false;
        }
      }),
    );
    expect(outcomes.where((success) => success), hasLength(1));
    expect((await inventory.get('alice', 'A')).quantity, 3);
  });

  test(
    'account databases isolate identical product and operation IDs',
    () async {
      final alice = await seed('A');
      final bob = await seed('A', uid: 'bob');
      await sales.create('alice', 'same', bill(alice, quantity: 2));
      await sales.create('bob', 'same', bill(bob, quantity: 3));
      expect((await inventory.get('alice', 'A')).quantity, 8);
      expect((await inventory.get('bob', 'A')).quantity, 7);
      await expectLater(
        store.restoreFor('bob', await store.exportFor('alice')),
        throwsFormatException,
      );
      expect((await inventory.get('bob', 'A')).quantity, 7);
    },
  );

  test(
    'full sale/purchase/return IDs avoid truncated-prefix collisions',
    () async {
      final a = await seed('A', units: 20);
      final prefix = List.filled(40, 'a').join();
      for (final suffix in ['1', '2']) {
        await sales.create('alice', '$prefix$suffix', bill(a));
        await purchases.create(
          'alice',
          '$prefix$suffix',
          PurchaseDraft(
            currency: 'INR',
            lines: [
              const PurchaseLine(
                sku: 'A',
                name: 'Item A',
                quantity: 2,
                unitCostMinor: 50,
              ),
            ],
          ),
        );
        await purchases.recordReturn(
          'alice',
          '$prefix$suffix',
          {'A': 1},
          '  Damaged  ',
          '$prefix$suffix',
        );
        await purchases.recordReturn(
          'alice',
          '$prefix$suffix',
          {'A': 1},
          '  Damaged  ',
          '$prefix$suffix',
        );
      }
      expect((await inventory.get('alice', 'A')).quantity, 20);
      expect(
        await (await store.databaseFor('alice')).query('purchase_returns'),
        hasLength(2),
      );
    },
  );

  test('backup is one snapshot when a sale is queued concurrently', () async {
    final a = await seed('A');
    final exporting = store.exportFor('alice');
    final saving = sales.create('alice', 'concurrent', bill(a, quantity: 2));
    final snapshot = await exporting;
    await saving;
    final tables = snapshot['tables'] as Map;
    final sold = (tables['sales'] as List).isEmpty ? 0 : 2;
    expect((tables['products'] as List).single['quantity'], 10 - sold);
    expect((tables['movements'] as List).length, sold == 0 ? 1 : 2);
    await store.restoreFor('alice', snapshot);
    expect((await inventory.get('alice', 'A')).quantity, 10 - sold);
  });

  test('report reads sales and stock from the same transaction', () async {
    final a = await seed('A');
    final loading = LocalReportsRepository(store).load(
      uid: 'alice',
      currency: 'INR',
      start: DateTime.utc(2000),
      endExclusive: DateTime.utc(2100),
    );
    final saving = sales.create('alice', 'concurrent', bill(a, quantity: 2));
    final report = await loading;
    await saving;
    expect(
      report.inventoryValueMinor,
      BigInt.from((10 - report.soldUnits) * 50),
    );
  });

  test('missing/malformed backup tables cannot erase the register', () async {
    await seed('A');
    final snapshot = await store.exportFor('alice');
    for (final tables in [
      <String, Object?>{},
      {...snapshot['tables'] as Map, 'products': 'invalid'},
      {...snapshot['tables'] as Map}..remove('sales'),
    ]) {
      await expectLater(
        store.restoreFor('alice', {...snapshot, 'tables': tables}),
        throwsFormatException,
      );
      expect((await inventory.get('alice', 'A')).quantity, 10);
    }
    // A SQL failure halfway through replacement must also roll back deletes.
    await expectLater(
      store.restoreFor('alice', {
        ...snapshot,
        'tables': {
          ...snapshot['tables'] as Map,
          'sales': [
            {'id': 'broken'},
          ],
        },
      }),
      throwsA(anyOf(isA<DatabaseException>(), isA<FormatException>())),
    );
    expect((await inventory.get('alice', 'A')).quantity, 10);
  });

  test(
    'v1 backup restores old bill amounts with later module defaults',
    () async {
      final a = await seed('A');
      await sales.create('alice', 'old', bill(a));
      final snapshot = await store.exportFor('alice');
      final tables = Map<String, Object?>.from(snapshot['tables'] as Map);
      for (final key in [
        'bill_documents',
        'quotations',
        'purchase_orders',
        'accounting_entries',
      ]) {
        tables.remove(key);
      }
      tables['customers'] = [
        for (final row in tables['customers'] as List)
          Map<String, Object?>.from(row as Map)
            ..remove('identityKey')
            ..remove('address')
            ..remove('whatsappOptIn'),
      ];
      final oldBill =
          Map<String, Object?>.from((tables['sales'] as List).single as Map)
            ..['customerId'] = null
            ..remove('customerAddress')
            ..remove('initialPaymentMinor')
            ..remove('expectedPaymentMinor')
            ..remove('paidMinor')
            ..remove('payments')
            ..remove('followupAt');
      tables['sales'] = [oldBill];
      await store.restoreFor('alice', {
        ...snapshot,
        'version': 1,
        'tables': tables,
      });
      expect((await sales.get('alice', 'old')).draft.firstPaymentMinor, 100);
    },
  );

  for (final version in [1, 7]) {
    test(
      'schema v$version upgrades without losing records or stock history',
      () async {
        final a = await seed('A');
        await sales.create('alice', 'old', bill(a));
        final db = await store.databaseFor('alice');
        final path = db.path;
        await store.close();
        final oldDb = await databaseFactoryFfi.openDatabase(path);
        await oldDb.execute('DROP TABLE bill_documents');
        await oldDb.execute('DROP INDEX customers_identity');
        await oldDb.execute('ALTER TABLE customers DROP COLUMN identityKey');
        await oldDb.execute('ALTER TABLE movements RENAME TO saved_movements');
        await oldDb.execute('''CREATE TABLE movements (
        id TEXT PRIMARY KEY, sku TEXT NOT NULL, type TEXT NOT NULL,
        beforeQuantity INTEGER NOT NULL, afterQuantity INTEGER NOT NULL,
        delta INTEGER NOT NULL, reason TEXT NOT NULL, actorUid TEXT NOT NULL,
        revision INTEGER NOT NULL, createdAt TEXT NOT NULL)''');
        await oldDb.execute(
          'INSERT INTO movements SELECT * FROM saved_movements',
        );
        await oldDb.execute('DROP TABLE saved_movements');
        await oldDb.execute(
          'CREATE INDEX movements_product_date ON movements(sku, createdAt DESC, id DESC)',
        );
        if (version == 1) {
          await oldDb.execute('DROP INDEX IF EXISTS sales_followup_due');
          for (final table in [
            'suppliers',
            'purchases',
            'purchase_returns',
            'operating_expenses',
            'quotations',
            'purchase_orders',
            'accounting_entries',
          ]) {
            await oldDb.execute('DROP TABLE $table');
          }
          for (final column in ['parameters', 'pricingFormula']) {
            await oldDb.execute('ALTER TABLE products DROP COLUMN $column');
          }
          await oldDb.execute(
            'ALTER TABLE customers DROP COLUMN whatsappOptIn',
          );
          for (final column in [
            'initialPaymentMinor',
            'expectedPaymentMinor',
            'paidMinor',
            'payments',
            'followupAt',
          ]) {
            await oldDb.execute('ALTER TABLE sales DROP COLUMN $column');
          }
        }
        await oldDb.execute('ALTER TABLE customers DROP COLUMN address');
        await oldDb.execute('ALTER TABLE sales DROP COLUMN customerAddress');
        await oldDb.setVersion(version);
        await oldDb.close();
        final upgraded = await store.databaseFor('alice');
        expect(await upgraded.getVersion(), 12);
        expect((await inventory.get('alice', 'A')).quantity, 9);
        expect((await sales.get('alice', 'old')).draft.firstPaymentMinor, 100);
        expect(await upgraded.query('movements'), hasLength(2));
        final movement = Map<String, Object?>.from(
          (await upgraded.query('movements')).first,
        )..['sku'] = 'B';
        await upgraded.insert('movements', movement);
        expect(await upgraded.query('movements'), hasLength(3));
      },
    );
  }

  test(
    'legacy per-product IDs survive import even when shared by a cloud sale',
    () async {
      final source = FakeInventory();
      for (final sku in ['A', 'B']) {
        source.products('alice')[sku] = inventoryFixture(sku: sku);
        source.history['alice/$sku'] = [
          StockMovement(
            id: 'shared-sale',
            type: 'sale',
            beforeQuantity: 12,
            afterQuantity: 10,
            delta: -2,
            reason: 'Sale shared-sale',
            actorUid: 'alice',
            revision: 1,
            createdAt: DateTime.utc(2026),
          ),
        ];
      }
      final importing = LocalInventoryRepository(store, legacySource: source);
      await importing.list('alice', const InventoryQuery());
      for (final sku in ['A', 'B']) {
        expect(
          (await importing.movements('alice', sku)).movements.single.id,
          'shared-sale',
        );
      }
      expect(importing.legacyImportFailed, isFalse);
    },
  );

  test(
    'import preserves the entire ledger for an existing local SKU',
    () async {
      await seed('A');
      final source = FakeInventory();
      source.products('alice')['A'] = inventoryFixture(sku: 'A', quantity: 20);
      source.history['alice/A'] = [
        StockMovement(
          id: 'cloud-only',
          type: 'opening',
          beforeQuantity: 0,
          afterQuantity: 20,
          delta: 20,
          reason: 'Opening stock',
          actorUid: 'alice',
          revision: 1,
          createdAt: DateTime.utc(2026),
        ),
      ];
      final importing = LocalInventoryRepository(store, legacySource: source);
      expect((await importing.get('alice', 'A')).quantity, 10);
      expect(
        (await importing.movements('alice', 'A')).movements.single.id,
        'opening_A',
      );
    },
  );

  test('device-local-owner never contacts the legacy source', () async {
    final source = FakeInventory()..pendingList = Completer<InventoryPage>();
    final importing = LocalInventoryRepository(store, legacySource: source);
    expect(
      (await importing.list(
        'device-local-owner',
        const InventoryQuery(),
      )).products,
      isEmpty,
    );
    expect(source.listCalls, 0);
  });

  test('legacy timeout is bounded and retries are throttled', () async {
    final pending = Completer<InventoryPage>();
    final source = FakeInventory()..pendingList = pending;
    final importing = LocalInventoryRepository(
      store,
      legacySource: source,
      legacyImportTimeout: const Duration(milliseconds: 20),
    );
    await importing
        .list('alice', const InventoryQuery())
        .timeout(const Duration(seconds: 2));
    expect(importing.legacyImportFailed, isTrue);
    await importing.list('alice', const InventoryQuery());
    expect(source.listCalls, 1);
    pending.complete(InventoryPage([inventoryFixture(sku: 'A')], null));
    await Future<void>.delayed(Duration.zero);
    expect(await (await store.databaseFor('alice')).query('products'), isEmpty);
  });

  test('concurrent readers wait for the same in-flight import', () async {
    final pending = Completer<InventoryPage>();
    final source = FakeInventory()..pendingList = pending;
    final importing = LocalInventoryRepository(store, legacySource: source);
    final first = importing.list('alice', const InventoryQuery());
    while (source.listCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    var secondCompleted = false;
    final second = importing.list('alice', const InventoryQuery()).then((page) {
      secondCompleted = true;
      return page;
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(secondCompleted, isFalse);
    source.pendingList = null;
    source.products('alice')['A'] = inventoryFixture(sku: 'A');
    pending.complete(InventoryPage([inventoryFixture(sku: 'A')], null));
    expect((await first).products.single.sku, 'A');
    expect((await second).products.single.sku, 'A');
  });
}
