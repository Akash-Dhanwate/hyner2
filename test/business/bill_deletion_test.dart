import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/features/inventory/data/local_inventory_repository.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/reports/data/local_reports_repository.dart';
import 'package:hyner/features/sales/data/local_bill_document_repository.dart';
import 'package:hyner/features/sales/data/local_sales_repository.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/sales/domain/sale_price_snapshot.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/universal_fixture.dart' as pricing;

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory folder;
  late LocalBusinessDatabase store;
  late LocalSalesRepository sales;
  late LocalInventoryRepository inventory;
  late LocalBillDocumentRepository documents;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('hyner-bill-deletion-');
    store = LocalBusinessDatabase(
      factory: databaseFactoryFfi,
      directory: folder.path,
    );
    sales = LocalSalesRepository(store);
    inventory = LocalInventoryRepository(store);
    documents = LocalBillDocumentRepository(store);
  });
  tearDown(() async {
    await store.close();
    await folder.delete(recursive: true);
  });
  Future<void> product(String sku, {int stock = 10}) => inventory.create(
    'owner',
    ProductDraft(
      sku: sku,
      name: sku,
      currency: 'INR',
      costMinor: 100,
      priceMinor: 200,
      openingStock: stock,
      reorderLevel: 1,
    ),
    'opening_$sku',
  );
  SaleDraft draft(List<SaleLine> lines) => SaleDraft(
    currency: 'INR',
    customerName: 'Buyer',
    customerPhone: '9876543210',
    lines: lines,
  );
  Future<SaleDraft> create({String id = 'bill1', int quantity = 2}) async {
    await product('DOOR');
    final d = draft([
      SaleLine.fromProduct(await inventory.get('owner', 'DOOR'), quantity),
    ]);
    await sales.create('owner', id, d);
    return d;
  }

  test('deleting a paid bill restores current stock once, removes documents/history/due/reports, preserves customer and other bills', () async {
    await create();
    final p = await inventory.get('owner', 'DOOR');
    await sales.create('owner', 'bill2', draft([SaleLine.fromProduct(p, 1)]));
    await sales.recordPayment('owner', 'bill1', 100, operationId: 'pay1');
    await sales.setFollowUp(
      'owner',
      'bill1',
      DateTime.now().add(const Duration(days: 2)),
    );
    await documents.saveDuplicate(
      'owner',
      'bill1',
      await File('test/fixtures/bill_duplicate.pdf').readAsBytes(),
    );
    final db = await store.databaseFor('owner');
    final customer = (await sales.get('owner', 'bill1')).draft.customerId!;
    final beforeCustomer = await db.query('customers');
    await sales.delete('owner', 'bill1', expectedPaidMinor: 100);
    await sales.delete('owner', 'bill1', expectedPaidMinor: 100);
    expect((await inventory.get('owner', 'DOOR')).quantity, 9);
    expect((await sales.list('owner')).sales.single.id, 'bill2');
    expect((await sales.recent('owner')).single.id, 'bill2');
    expect((await sales.forCustomer('owner', customer)).single.id, 'bill2');
    expect((await sales.remainingPayments('owner')).single.id, 'bill2');
    expect(await sales.scheduledFollowUps('owner'), isEmpty);
    expect(await documents.duplicate('owner', 'bill1'), isNull);
    expect(await db.query('customers'), beforeCustomer);
    final movements = (await inventory.movements('owner', 'DOOR')).movements;
    expect(
      movements.where((m) => m.reason.startsWith('Deleted bill')).single.delta,
      2,
    );
    expect(movements.where((m) => m.type == 'sale').length, 2);
    final report = await LocalReportsRepository(store).load(
      uid: 'owner',
      currency: 'INR',
      start: DateTime(2000),
      endExclusive: DateTime(2100),
    );
    expect(report.salesCount, 1);
    expect(report.revenueMinor, BigInt.from(200));
    expect(report.paidRevenueMinor, BigInt.zero);
    expect(report.unpaidRevenueMinor, BigInt.from(200));
    expect(report.grossProfitMinor, BigInt.from(100));
    await expectLater(
      sales.get('owner', 'bill1'),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.reference,
          'reference',
          'sales/deleted',
        ),
      ),
    );
    await expectLater(
      documents.saveDuplicate(
        'owner',
        'bill1',
        await File('test/fixtures/bill_duplicate.pdf').readAsBytes(),
      ),
      throwsStateError,
    );
  });

  test('deletion audit and retry protection survive backup/restore and block stale checkout creation', () async {
    final d = await create();
    await sales.delete('owner', 'bill1', expectedPaidMinor: 0);
    final snapshot = await store.exportFor('owner');
    final originalDb = await store.databaseFor('owner');
    await originalDb.delete('settings');
    await originalDb.update('products', {'quantity': 0});
    await store.restoreFor('owner', snapshot);
    await sales.delete('owner', 'bill1', expectedPaidMinor: 0);
    expect((await inventory.get('owner', 'DOOR')).quantity, 10);
    await expectLater(
      sales.create('owner', 'bill1', d),
      throwsA(isA<AppFailure>()),
    );
    final db = await store.databaseFor('owner');
    final audit = jsonDecode(
      (await db.query(
            'settings',
            where: 'key = ?',
            whereArgs: ['bill-deleted/bill1'],
          )).single['value']!
          as String,
    ) as Map;
    expect(audit['totalMinor'], 400);
    expect(audit['paidMinor'], 0);
  });

  test(
    'payment changes after confirmation block deletion without stock changes',
    () async {
      await create();
      await sales.recordPayment('owner', 'bill1', 100);
      await expectLater(
        sales.delete('owner', 'bill1', expectedPaidMinor: 0),
        throwsA(isA<AppFailure>()),
      );
      expect((await inventory.get('owner', 'DOOR')).quantity, 8);
      expect((await sales.get('owner', 'bill1')).paidMinor, 100);
    },
  );

  test(
    'a missing second inventory item rolls back all stock and deletion writes',
    () async {
      await product('FIRST');
      await product('SECOND');
      await sales.create(
        'owner',
        'bill1',
        draft([
          SaleLine.fromProduct(await inventory.get('owner', 'FIRST'), 2),
          SaleLine.fromProduct(await inventory.get('owner', 'SECOND'), 3),
        ]),
      );
      final db = await store.databaseFor('owner');
      await db.delete('products', where: 'sku = ?', whereArgs: ['SECOND']);
      await expectLater(
        sales.delete('owner', 'bill1', expectedPaidMinor: 0),
        throwsA(isA<AppFailure>()),
      );
      expect((await inventory.get('owner', 'FIRST')).quantity, 8);
      expect((await db.query('sales')).length, 1);
      expect(
        await db.query(
          'settings',
          where: 'key = ?',
          whereArgs: ['bill-deleted/bill1'],
        ),
        isEmpty,
      );
      expect(
        (await inventory.movements(
          'owner',
          'FIRST',
        )).movements.where((m) => m.reason.startsWith('Deleted bill')),
        isEmpty,
      );
    },
  );

  test('stock overflow blocks deletion and archived sold products are reactivated on restore', () async {
    await create(quantity: 10);
    final sold = await inventory.get('owner', 'DOOR');
    await inventory.setArchived('owner', sold, true);
    await sales.delete('owner', 'bill1', expectedPaidMinor: 0);
    final restored = await inventory.get('owner', 'DOOR');
    expect(restored.quantity, 10);
    expect(restored.archived, false);
    await sales.create(
      'owner',
      'bill2',
      draft([SaleLine.fromProduct(restored, 1)]),
    );
    final db = await store.databaseFor('owner');
    await db.update(
      'products',
      {'quantity': maxStock},
      where: 'sku = ?',
      whereArgs: ['DOOR'],
    );
    await expectLater(
      sales.delete('owner', 'bill2', expectedPaidMinor: 0),
      throwsA(isA<AppFailure>()),
    );
    expect((await inventory.get('owner', 'DOOR')).quantity, maxStock);
    expect((await sales.get('owner', 'bill2')).id, 'bill2');
  });

  test(
    'custom QuickPrice lines never change inventory even when their SKU exists',
    () async {
      final result = pricing.price(
        pricing.rule(
          strategy: pricing.piece('piece'),
          rates: [pricing.rate('piece', '12.50', 'piece')],
        ),
        quantity: 2,
      );
      final snapshot = SalePriceSnapshot.fromResult(result);
      await product('CUSTOM');
      await sales.create(
        'owner',
        'bill1',
        draft([
          SaleLine(
            sku: 'CUSTOM',
            name: 'Custom item',
            unitPriceMinor: snapshot.unitPriceMinor,
            quantity: snapshot.quantity,
            pricing: snapshot,
          ),
        ]),
      );
      await sales.delete('owner', 'bill1', expectedPaidMinor: 0);
      expect((await inventory.get('owner', 'CUSTOM')).quantity, 10);
      expect(
        (await inventory.movements('owner', 'CUSTOM')).movements.length,
        1,
      );
    },
  );

  test(
    'deletion is scoped to account and rejects invalid or unknown references',
    () async {
      await create();
      await expectLater(
        sales.delete('other', 'bill1', expectedPaidMinor: 0),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        sales.delete('owner', 'bad/id', expectedPaidMinor: 0),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        sales.delete('', 'bill1', expectedPaidMinor: 0),
        throwsA(isA<AppFailure>()),
      );
      expect((await sales.get('owner', 'bill1')).id, 'bill1');
      expect((await inventory.get('owner', 'DOOR')).quantity, 8);
    },
  );
}
