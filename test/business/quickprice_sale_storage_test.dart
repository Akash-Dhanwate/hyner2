import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/features/inventory/data/local_inventory_repository.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/reports/data/local_reports_repository.dart';
import 'package:hyner/features/sales/data/local_sales_repository.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/sales/domain/sale_price_snapshot.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/quickprice_sales_fixture.dart';

void main() {
  late Directory directory;
  late LocalBusinessDatabase store;
  late LocalSalesRepository sales;
  late LocalInventoryRepository inventory;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hyner-quickprice-sale-');
    store = LocalBusinessDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    sales = LocalSalesRepository(store);
    inventory = LocalInventoryRepository(store);
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<Product> stock({
    String sku = 'A',
    int quantity = 10,
    int costMinor = 50,
  }) async {
    await inventory.create(
      'owner',
      ProductDraft(
        sku: sku,
        name: 'Measured panel',
        currency: 'INR',
        costMinor: costMinor,
        priceMinor: 100,
        openingStock: quantity,
        reorderLevel: 1,
      ),
      'opening_$sku',
    );
    return inventory.get('owner', sku);
  }

  test('six repeated measured lines persist exact snapshots with no fake inventory', () async {
    final lines = sixMeasuredLines();
    final draft = customSaleDraft(lines);
    final db = await store.databaseFor('owner');
    final version = await db.getVersion();
    await sales.create('owner', 'six_lines', draft);
    final saved = await sales.get('owner', 'six_lines');
    expect(saved.draft.lines, hasLength(6));
    expect(saved.draft.totalMinor, draft.totalMinor);
    expect(saved.draft.units, 18);
    expect(saved.draft.lines.every((line) => !line.stockTracked), isTrue);
    for (var i = 0; i < lines.length; i++) {
      expect(
        saved.draft.lines[i].pricing!.snapshotJson,
        lines[i].pricing!.snapshotJson,
      );
      expect(saved.draft.lines[i].parameters.single.value, 'QuickPrice');
    }
    expect(await db.query('products'), isEmpty);
    expect(await db.query('movements'), isEmpty);
    expect(await db.getVersion(), version);
    final raw =
        jsonDecode((await db.query('sales')).single['lines'] as String) as List;
    expect(raw.every((line) => (line as Map)['pricing'] is Map), isTrue);
    expect(
      (await sales.list('owner')).sales.single.draft.totalMinor,
      draft.totalMinor,
    );
    expect(
      (await sales.forCustomer('owner', saved.draft.customerId!)).single.id,
      saved.id,
    );

    await store.close();
    final reopened = await sales.get('owner', 'six_lines');
    expect(reopened.draft.matches(saved.draft), isTrue);
    expect(reopened.remainingMinor, draft.totalMinor);
  });

  test(
    'linked QuickPrice lines deduct stock once and snapshot purchase cost',
    () async {
      final product = await stock(quantity: 10);
      final quote = measuredSaleLine(0);
      final linked = SaleLine(
        sku: quote.sku,
        name: quote.name,
        unitPriceMinor: quote.unitPriceMinor,
        quantity: quote.quantity,
        pricing: quote.pricing,
        inventorySku: product.sku,
        parameters: quote.parameters,
      );
      final draft = customSaleDraft([linked]);

      await sales.create('owner', 'linked-quote', draft);
      await sales.create('owner', 'linked-quote', draft);

      final saved = await sales.get('owner', 'linked-quote');
      expect((await inventory.get('owner', product.sku)).quantity, 7);
      expect(saved.draft.lines.single.inventorySku, product.sku);
      expect(saved.draft.lines.single.unitCostMinor, 50);
      expect(saved.draft.lines.single.inventoryCostKnown, isTrue);
      final db = await store.databaseFor('owner');
      expect(
        await db.query('movements', where: 'type = ?', whereArgs: ['sale']),
        hasLength(1),
      );

      final report = await LocalReportsRepository(store).load(
        uid: 'owner',
        currency: 'INR',
        start: saved.createdAt.subtract(const Duration(days: 1)),
        endExclusive: saved.createdAt.add(const Duration(days: 1)),
      );
      expect(report.revenueMinor, BigInt.from(340));
      expect(report.costOfGoodsMinor, BigInt.from(150));
      expect(report.grossProfitMinor, BigInt.from(190));
      expect(report.uncostedSalesCount, 0);
      expect(report.topProducts.single.sku, product.sku);

      await sales.delete('owner', 'linked-quote', expectedPaidMinor: 0);
      expect((await inventory.get('owner', product.sku)).quantity, 10);
      expect(
        await db.query('movements', where: 'type = ?', whereArgs: ['sale']),
        hasLength(1),
      );
    },
  );

  test('selected QuickPrice variety deducts only its own stock item', () async {
    final solid = await stock(sku: 'DOOR-SOLID', quantity: 8);
    final grooved = await stock(sku: 'DOOR-GROOVED', quantity: 6);
    final quote = measuredSaleLine(
      2,
      result: measuredQuote(variety: 'premium', quantity: 2),
    );
    final linked = SaleLine(
      sku: quote.sku,
      name: quote.name,
      unitPriceMinor: quote.unitPriceMinor,
      quantity: quote.quantity,
      pricing: quote.pricing,
      inventorySku: grooved.sku,
      parameters: quote.parameters,
    );
    final draft = customSaleDraft([linked]);

    await sales.create('owner', 'grooved-sale', draft);
    await sales.create('owner', 'grooved-sale', draft);

    expect((await inventory.get('owner', solid.sku)).quantity, 8);
    expect((await inventory.get('owner', grooved.sku)).quantity, 4);
    expect(
      (await inventory.movements(
        'owner',
        grooved.sku,
      )).movements.where((movement) => movement.type == 'sale'),
      hasLength(1),
    );
  });

  test(
    'zero purchase cost stays uncosted instead of claiming full profit',
    () async {
      final product = await stock(sku: 'UNKNOWN-COST', costMinor: 0);
      final quote = measuredSaleLine(0);
      final linked = SaleLine(
        sku: quote.sku,
        name: quote.name,
        unitPriceMinor: quote.unitPriceMinor,
        quantity: quote.quantity,
        pricing: quote.pricing,
        inventorySku: product.sku,
        parameters: quote.parameters,
      );
      await sales.create('owner', 'unknown-cost', customSaleDraft([linked]));
      final sale = await sales.get('owner', 'unknown-cost');
      final report = await LocalReportsRepository(store).load(
        uid: 'owner',
        currency: 'INR',
        start: sale.createdAt.subtract(const Duration(days: 1)),
        endExclusive: sale.createdAt.add(const Duration(days: 1)),
      );
      expect(sale.draft.lines.single.inventoryCostKnown, isFalse);
      expect(report.uncostedSalesCount, 1);
      expect(report.trackedRevenueMinor, BigInt.zero);
      expect(report.grossProfitMinor, BigInt.zero);
    },
  );

  test('concurrent retries and canonical JSON apply mixed stock once', () async {
    final product = await stock();
    final custom = measuredSaleLine(0);
    final draft = customSaleDraft([custom, SaleLine.fromProduct(product, 2)]);
    await Future.wait([
      sales.create('owner', 'retry', draft),
      sales.create('owner', 'retry', draft),
    ]);
    final saved = await sales.get('owner', 'retry');
    final json = custom.pricing!.toJson();
    final reordered = Map<String, dynamic>.fromEntries(
      json.entries.toList().reversed,
    );
    final snapshot = SalePriceSnapshot.fromJson(reordered);
    await sales.create(
      'owner',
      'retry',
      customSaleDraft([
        SaleLine.fromProduct(product, 2),
        SaleLine(
          sku: custom.sku,
          name: custom.name,
          unitPriceMinor: snapshot.unitPriceMinor,
          quantity: snapshot.quantity,
          parameters: custom.parameters,
          pricing: snapshot,
        ),
      ]),
    );
    expect((await inventory.get('owner', 'A')).quantity, 8);
    final db = await store.databaseFor('owner');
    expect(await db.query('sales'), hasLength(1));
    expect(await db.query('customers'), hasLength(1));
    expect(
      await db.query('movements', where: 'type = ?', whereArgs: ['sale']),
      hasLength(1),
    );
    expect(saved.draft.totalMinor, 540);

    // Identical final money does not make different measured inputs retryable.
    final changed = measuredSaleLine(
      0,
      result: measuredQuote(width: '2', height: '0.5'),
    );
    await expectLater(
      sales.create(
        'owner',
        'retry',
        customSaleDraft([changed, SaleLine.fromProduct(product, 2)]),
      ),
      throwsA(isA<AppFailure>()),
    );
    expect((await inventory.get('owner', 'A')).quantity, 8);
  });

  test(
    'custom lines never link by a matching name or even a matching code',
    () async {
      final custom = measuredSaleLine(0);
      await stock(); // Same name as the measured line.
      await stock(
        sku: custom.sku,
      ); // Deliberate collision proves the pricing flag controls stock.
      await sales.create('owner', 'custom_only', customSaleDraft([custom]));
      expect((await inventory.get('owner', 'A')).quantity, 10);
      expect((await inventory.get('owner', custom.sku)).quantity, 10);
      final db = await store.databaseFor('owner');
      expect(await db.query('products'), hasLength(2));
      expect(
        await db.query('movements', where: 'type = ?', whereArgs: ['sale']),
        isEmpty,
      );
    },
  );

  test('missing or insufficient real stock rolls back custom bill, customer and stock moves', () async {
    final product = await stock();
    final db = await store.databaseFor('owner');
    for (final invalid in [
      SaleLine(
        sku: 'MISSING',
        name: 'Missing stock',
        unitPriceMinor: 10,
        quantity: 1,
      ),
      SaleLine.fromProduct(product, 11),
    ]) {
      final draft = customSaleDraft([
        measuredSaleLine(0),
        if (invalid.sku != product.sku) SaleLine.fromProduct(product, 2),
        invalid,
      ]);
      await expectLater(
        sales.create('owner', 'rollback', draft),
        throwsA(isA<AppFailure>()),
      );
      expect(await db.query('sales'), isEmpty);
      expect(await db.query('customers'), isEmpty);
      expect((await inventory.get('owner', 'A')).quantity, 10);
      expect(
        await db.query('movements', where: 'type = ?', whereArgs: ['sale']),
        isEmpty,
      );
    }
  });

  test('restore, reports and idempotent payments use exact money and unknown custom cost', () async {
    final custom = measuredSaleLine(0); // 340, displayed 113 × 3 = 339.
    final product = await stock();
    await sales.create('owner', 'custom', customSaleDraft([custom]));
    await sales.create(
      'owner',
      'stock',
      customSaleDraft([SaleLine.fromProduct(product, 2)]),
    );
    await sales.recordPayment('owner', 'custom', 100, operationId: 'payment1');
    await sales.recordPayment('owner', 'custom', 100, operationId: 'payment1');
    final snapshot = await store.exportFor('owner');
    await store.restoreFor('owner', snapshot);
    final restored = await sales.get('owner', 'custom');
    expect(restored.draft.totalMinor, 340);
    expect(restored.paidMinor, 100);
    expect(restored.remainingMinor, 240);
    expect(restored.payments, hasLength(1));
    expect(restored.paymentStatus, PaymentStatus.partial);
    expect(
      restored.draft.lines.single.pricing!.snapshotJson,
      custom.pricing!.snapshotJson,
    );
    expect((await inventory.get('owner', 'A')).quantity, 8);
    final date = restored.createdAt;
    final report = await LocalReportsRepository(store).load(
      uid: 'owner',
      currency: 'INR',
      start: date.subtract(const Duration(days: 1)),
      endExclusive: date.add(const Duration(days: 1)),
    );
    expect(report.revenueMinor, BigInt.from(540));
    expect(report.paidRevenueMinor, BigInt.from(100));
    expect(report.unpaidRevenueMinor, BigInt.from(440));
    expect(report.uncostedSalesCount, 1);
    expect(report.trackedRevenueMinor, BigInt.from(200));
    expect(report.costOfGoodsMinor, BigInt.from(100));
    expect(report.grossProfitMinor, BigInt.from(100));
    expect(
      report.topProducts
          .singleWhere((line) => line.sku == custom.sku)
          .revenueMinor,
      BigInt.from(340),
    );
    expect(
      report.salesRecords
          .singleWhere((sale) => sale.reference == 'custom')
          .remainingMinor,
      BigInt.from(240),
    );
    await sales.markPaid('owner', 'custom');
    final paid = await sales.get('owner', 'custom');
    expect(paid.paidMinor, 340);
    expect(paid.remainingMinor, 0);
    expect(paid.paymentStatus, PaymentStatus.paid);
    await sales.create('owner', 'custom', customSaleDraft([custom]));
    expect((await sales.get('owner', 'custom')).payments, hasLength(2));
    expect((await sales.remainingPayments('owner')).map((sale) => sale.id), [
      'stock',
    ]);
  });

  test(
    'legacy restore derives payment defaults from exact custom total',
    () async {
      await sales.create(
        'owner',
        'legacy',
        customSaleDraft([measuredSaleLine(0)]),
      );
      final snapshot = await store.exportFor('owner');
      final tables = Map<String, Object?>.from(snapshot['tables'] as Map);
      tables['sales'] = [
        for (final row in tables['sales'] as List)
          Map<String, Object?>.from(row as Map)
            ..remove('initialPaymentMinor')
            ..remove('expectedPaymentMinor'),
      ];
      await store.restoreFor('owner', {...snapshot, 'tables': tables});
      final restored = await sales.get('owner', 'legacy');
      expect(restored.draft.firstPaymentMinor, 340);
      expect(restored.expectedPaymentMinor, 340);
      await sales.markPaid('owner', 'legacy');
      expect((await sales.get('owner', 'legacy')).paidMinor, 340);
    },
  );

  test('tampered persisted quote fails reads instead of recomputing rounded unit totals', () async {
    await sales.create(
      'owner',
      'tampered',
      customSaleDraft([measuredSaleLine(0)]),
    );
    final db = await store.databaseFor('owner');
    final row = (await db.query('sales')).single;
    final lines = jsonDecode(row['lines'] as String) as List;
    ((lines.single as Map)['pricing']['amounts'] as Map)['taxMinor'] = '1';
    await db.update(
      'sales',
      {'lines': jsonEncode(lines)},
      where: 'id = ?',
      whereArgs: ['tampered'],
    );
    await expectLater(
      sales.get('owner', 'tampered'),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.reference,
          'reference',
          isNot('sales/not-found'),
        ),
      ),
    );
    await expectLater(
      sales.recordPayment('owner', 'tampered', 1),
      throwsA(isA<AppFailure>()),
    );
    expect((await db.query('sales')).single['paidMinor'], 0);
  });

  test(
    'only a missing bill get carries the checkout not-found reference',
    () async {
      await expectLater(
        sales.get('owner', 'missing'),
        throwsA(
          isA<AppFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                FailureKind.invalidData,
              )
              .having(
                (failure) => failure.message,
                'message',
                'This sale could not be found. Refresh sales.',
              )
              .having(
                (failure) => failure.reference,
                'reference',
                'sales/not-found',
              ),
        ),
      );
      await expectLater(
        sales.get('', 'missing'),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.reference,
            'reference',
            isNull,
          ),
        ),
      );
      await expectLater(
        sales.recordPayment('owner', 'missing', 1),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.reference,
            'reference',
            isNull,
          ),
        ),
      );
    },
  );
}
