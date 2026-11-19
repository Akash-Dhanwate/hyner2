import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/features/inventory/data/local_inventory_repository.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/purchases/data/local_purchase_repository.dart';
import 'package:hyner/features/purchases/domain/purchase.dart';
import 'package:hyner/features/reports/data/local_reports_repository.dart';
import 'package:hyner/features/sales/data/bill_pdf_filename.dart';
import 'package:hyner/features/sales/data/local_financial_repository.dart';
import 'package:hyner/features/sales/data/local_sales_repository.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/quickprice_sales_fixture.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory directory;
  late LocalBusinessDatabase store;
  late LocalSalesRepository sales;
  late LocalInventoryRepository inventory;
  late LocalFinancialRepository financial;
  final now = DateTime.utc(2026, 11, 17, 12);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hyner-launch-finance-');
    store = LocalBusinessDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    sales = LocalSalesRepository(store, clock: () => now);
    inventory = LocalInventoryRepository(store);
    financial = LocalFinancialRepository(store, clock: () => now);
    await inventory.create(
      'owner',
      ProductDraft(
        sku: 'DOOR',
        name: 'Door',
        currency: 'INR',
        costMinor: 40,
        priceMinor: 100,
        openingStock: 100,
        reorderLevel: 5,
      ),
      'opening',
    );
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });
  Future<SaleDraft> draft({int quantity = 3, String? replaces}) async =>
      SaleDraft(
        currency: 'INR',
        customerName: 'Asha Patil',
        customerPhone: '9876543210',
        replacesSaleId: replaces,
        lines: [
          SaleLine.fromProduct(await inventory.get('owner', 'DOOR'), quantity),
        ],
      );

  test(
    'numbers are workspace scoped, retry safe and never reused after deletion',
    () async {
      final d = await draft();
      await Future.wait([
        sales.create('owner', 'bill_a', d),
        sales.create('owner', 'bill_a', d),
      ]);
      expect((await sales.get('owner', 'bill_a')).billNumber, 1);
      await sales.create('owner', 'bill_b', d);
      expect((await sales.get('owner', 'bill_b')).billNumber, 2);
      await sales.delete('owner', 'bill_a', expectedPaidMinor: 0);
      await sales.create('owner', 'bill_c', d);
      expect((await sales.get('owner', 'bill_c')).billNumber, 3);
      expect(
        (await sales.list('owner', search: '3')).sales.map((s) => s.id),
        contains('bill_c'),
      );
      expect(
        billPdfFilename(
          customerName: 'Asha Patil',
          customerPhone: '9876543210',
          saleId: 'bill_c',
          billNumber: 3,
        ),
        'Asha Patil - Bill 3.pdf',
      );
      await inventory.create(
        'other',
        ProductDraft(
          sku: 'DOOR',
          name: 'Door',
          currency: 'INR',
          costMinor: 40,
          priceMinor: 100,
          openingStock: 100,
          reorderLevel: 5,
        ),
        'opening',
      );
      await sales.create('other', 'bill_x', d);
      expect((await sales.get('other', 'bill_x')).billNumber, 1);
    },
  );

  test('partial returns credit exactly once, refunds reduce net receipts and excess returns fail atomically', () async {
    await sales.create('owner', 'bill', await draft());
    await financial.recordPayment(
      'owner',
      'sale',
      'bill',
      300,
      operationId: 'receipt',
      date: now,
      method: 'upi',
      note: 'Verified',
    );
    final original = await sales.get('owner', 'bill');
    await financial.recordReturn(
      'owner',
      original,
      {'DOOR': 1},
      operationId: 'return1',
      reason: 'Customer return',
      restock: true,
    );
    await financial.recordReturn(
      'owner',
      original,
      {'DOOR': 1},
      operationId: 'return1',
      reason: 'Customer return',
      restock: true,
    );
    expect((await inventory.get('owner', 'DOOR')).quantity, 98);
    expect((await sales.get('owner', 'bill')).refundDueMinor, 100);
    await financial.recordPayment(
      'owner',
      'sale',
      'bill',
      100,
      operationId: 'refund',
      date: now,
      refund: true,
    );
    final after = await sales.get('owner', 'bill');
    expect(after.paidMinor, 200);
    expect(after.refundDueMinor, 0);
    expect(after.remainingMinor, 0);
    await expectLater(
      financial.recordReturn(
        'owner',
        original,
        {'DOOR': 3},
        operationId: 'too_many',
        reason: 'Bad return',
        restock: true,
      ),
      throwsA(anything),
    );
    expect((await inventory.get('owner', 'DOOR')).quantity, 98);
    expect((await financial.returns('owner', 'bill')).length, 1);
    expect((await financial.entries('owner', 'sale', 'bill')).length, 2);
  });

  test('void after partial return restores only outstanding units and keeps receipt history and replacement chain', () async {
    await sales.create('owner', 'original', await draft());
    final saved = await sales.get('owner', 'original');
    await financial.recordReturn(
      'owner',
      saved,
      {'DOOR': 1},
      operationId: 'ret',
      reason: 'Returned',
      restock: false,
    );
    await financial.voidBill(
      'owner',
      'original',
      reason: 'Wrong bill',
      expectedPaidMinor: 0,
    );
    await financial.voidBill(
      'owner',
      'original',
      reason: 'Retry',
      expectedPaidMinor: 0,
    );
    expect((await inventory.get('owner', 'DOOR')).quantity, 99);
    final original = await sales.get('owner', 'original');
    expect(original.isVoid, isTrue);
    expect(original.billNumber, 1);
    await sales.create(
      'owner',
      'replacement',
      await draft(quantity: 2, replaces: 'original'),
    );
    final replacement = await sales.get('owner', 'replacement');
    expect(replacement.replacesSaleId, 'original');
    expect(replacement.billNumber, 2);
    await expectLater(
      sales.create('owner', 'replacement2', await draft(replaces: 'original')),
      throwsA(anything),
    );
    expect((await inventory.get('owner', 'DOOR')).quantity, 97);
  });

  test('receipt correction appends a reversal, never permits a second reversal and preserves the original', () async {
    await sales.create('owner', 'bill', await draft());
    await financial.recordPayment(
      'owner',
      'sale',
      'bill',
      120,
      operationId: 'receipt',
      date: now,
      method: 'card',
    );
    await financial.reversePayment(
      'owner',
      'receipt',
      operationId: 'reversal',
      reason: 'Wrong amount',
      date: now,
    );
    await financial.reversePayment(
      'owner',
      'receipt',
      operationId: 'reversal',
      reason: 'Wrong amount',
      date: now,
    );
    await expectLater(
      financial.reversePayment(
        'owner',
        'receipt',
        operationId: 'reversal2',
        reason: 'Again',
        date: now,
      ),
      throwsA(anything),
    );
    expect((await financial.entries('owner', 'sale', 'bill')).length, 2);
    expect((await sales.get('owner', 'bill')).paidMinor, 0);
    expect((await sales.get('owner', 'bill')).remainingMinor, 300);
  });

  test('collection-date report includes old bills and return-adjusted sales and profit', () async {
    await sales.create('owner', 'bill', await draft());
    final db = await store.databaseFor('owner');
    await db.update(
      'sales',
      {'createdAt': DateTime.utc(2026, 10, 1).toIso8601String()},
      where: 'id = ?',
      whereArgs: ['bill'],
    );
    await financial.recordPayment(
      'owner',
      'sale',
      'bill',
      200,
      operationId: 'receipt',
      date: now,
      method: 'bank',
    );
    await financial.recordReturn(
      'owner',
      await sales.get('owner', 'bill'),
      {'DOOR': 1},
      operationId: 'ret',
      reason: 'Return',
      restock: true,
    );
    final reports = LocalReportsRepository(store);
    final current = await reports.load(
      uid: 'owner',
      currency: 'INR',
      start: DateTime.utc(2026, 11, 17),
      endExclusive: DateTime.utc(2026, 11, 18),
    );
    expect(current.salesCount, 0);
    expect(current.collectedMinor, 200);
    expect(current.customerReturnMinor, 100);
    final all = await reports.load(
      uid: 'owner',
      currency: 'INR',
      start: DateTime.utc(2026, 1),
      endExclusive: DateTime.utc(2026, 12),
    );
    expect(all.revenueMinor, BigInt.from(200));
    expect(all.costOfGoodsMinor, BigInt.from(80));
    expect(all.grossProfitMinor, BigInt.from(120));
  });

  test(
    'supplier partial payment, purchase return credit and refund reconcile',
    () async {
      final purchases = LocalPurchaseRepository(store);
      await purchases.create(
        'owner',
        'purchase',
        PurchaseDraft(
          currency: 'INR',
          lines: const [
            PurchaseLine(
              sku: 'DOOR',
              name: 'Door',
              quantity: 5,
              unitCostMinor: 40,
            ),
          ],
        ),
      );
      await financial.recordPayment(
        'owner',
        'purchase',
        'purchase',
        120,
        operationId: 'supplier1',
        date: now,
      );
      expect(
        (await financial.balance('owner', 'purchase', 'purchase')).dueMinor,
        80,
      );
      await purchases.recordReturn(
        'owner',
        'purchase',
        {'DOOR': 3},
        'Faulty',
        'purchase_return',
      );
      final credit = await financial.balance('owner', 'purchase', 'purchase');
      expect(credit.dueMinor, 0);
      expect(credit.refundDueMinor, 40);
      await financial.recordPayment(
        'owner',
        'purchase',
        'purchase',
        40,
        operationId: 'supplier_refund',
        date: now,
        refund: true,
      );
      expect(
        (await financial.balance(
          'owner',
          'purchase',
          'purchase',
        )).refundDueMinor,
        0,
      );
    },
  );
  test(
    'concurrent distinct bills allocate unique consecutive numbers',
    () async {
      final d = await draft(quantity: 1);
      await Future.wait([
        for (var i = 0; i < 12; i++) sales.create('owner', 'concurrent_$i', d),
      ]);
      final numbers = (await sales.list(
        'owner',
      )).sales.map((s) => s.billNumber!).toList()..sort();
      expect(numbers, List.generate(12, (i) => i + 1));
      expect((await inventory.get('owner', 'DOOR')).quantity, 88);
    },
  );

  test(
    'partial measured returns preserve exact gross and tax rounding',
    () async {
      final line = measuredSaleLine(1);
      await sales.create('owner', 'measured', customSaleDraft([line]));
      final original = await sales.get('owner', 'measured');
      for (var i = 0; i < line.quantity; i++) {
        await financial.recordReturn(
          'owner',
          original,
          {line.sku: 1},
          operationId: 'measured_return_$i',
          reason: 'Measured return',
          restock: false,
        );
      }
      final records = await financial.returns('owner', 'measured');
      expect(
        records.fold<int>(0, (sum, r) => sum + (r['totalMinor'] as int)),
        line.totalMinor,
      );
      expect(
        records.fold<int>(0, (sum, r) => sum + (r['taxMinor'] as int)),
        line.pricing!.taxMinor,
      );
      expect((await sales.get('owner', 'measured')).netTotalMinor, 0);
    },
  );

  test(
    'non-restocked returns retain their known cost as an auditable loss',
    () async {
      await sales.create('owner', 'damaged', await draft());
      await financial.recordReturn(
        'owner',
        await sales.get('owner', 'damaged'),
        {'DOOR': 1},
        operationId: 'damaged_return',
        reason: 'Damaged',
        restock: false,
      );
      final report = await LocalReportsRepository(store).load(
        uid: 'owner',
        currency: 'INR',
        start: DateTime.utc(2020),
        endExclusive: DateTime.utc(2030),
      );
      expect(report.revenueMinor, BigInt.from(200));
      expect(report.costOfGoodsMinor, BigInt.from(80));
      expect(report.operatingExpensesMinor, BigInt.from(40));
      expect(report.earningsAfterCostsMinor, BigInt.from(80));
      expect((await inventory.get('owner', 'DOOR')).quantity, 97);
    },
  );

  test(
    'schema 13 bills gain chronological numbers and legacy payment balances',
    () async {
      await sales.create('owner', 'later', await draft(quantity: 1));
      await sales.create('owner', 'earlier', await draft(quantity: 1));
      final path = (await store.databaseFor('owner')).path;
      await store.close();
      final old = await databaseFactoryFfi.openDatabase(path);
      await old.update(
        'sales',
        {
          'createdAt': DateTime.utc(2025).toIso8601String(),
          'paymentStatus': 'paid',
          'paidMinor': 0,
        },
        where: 'id = ?',
        whereArgs: ['earlier'],
      );
      await old.execute('DROP INDEX sales_bill_number');
      for (final column in [
        'billNumber',
        'billState',
        'creditMinor',
        'voidReason',
        'voidedAt',
        'replacesSaleId',
      ]) {
        await old.execute('ALTER TABLE sales DROP COLUMN $column');
      }
      await old.execute('DROP TABLE sale_returns');
      await old.execute('DROP TABLE financial_entries');
      await old.delete(
        'settings',
        where: 'key = ?',
        whereArgs: ['bill-sequence'],
      );
      await old.setVersion(13);
      await old.close();
      final first = await sales.get('owner', 'earlier');
      expect(first.billNumber, 1);
      expect(first.paidMinor, 100);
      expect(first.remainingMinor, 0);
      expect((await sales.get('owner', 'later')).billNumber, 2);
      expect(
        (await financial.entries('owner', 'sale', 'earlier')).single.kind,
        'opening_balance',
      );
      final report = await LocalReportsRepository(store).load(
        uid: 'owner',
        currency: 'INR',
        start: DateTime.utc(2020),
        endExclusive: DateTime.utc(2030),
      );
      expect(report.collectedMinor, 0);
    },
  );
}
