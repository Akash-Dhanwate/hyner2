import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/features/customers/data/customer_rows.dart';
import 'package:hyner/features/customers/domain/customer.dart';
import 'package:hyner/features/reports/data/local_reports_repository.dart';
import 'package:hyner/features/sales/data/local_bill_document_repository.dart';
import 'package:hyner/features/sales/data/local_sales_repository.dart';
import 'package:hyner/features/sales/domain/sales_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory folder;
  late LocalBusinessDatabase store;
  late LocalSalesRepository sales;
  var now = DateTime.utc(2026, 11, 12, 12);
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('hyner-sales-refinement-');
    store = LocalBusinessDatabase(
      factory: databaseFactoryFfi,
      directory: folder.path,
    );
    now = DateTime.utc(2026, 11, 12, 12);
    sales = LocalSalesRepository(store, clock: () => now);
  });
  tearDown(() async {
    await store.close();
    await folder.delete(recursive: true);
  });
  Future<void> bill(
    String id, {
    DateTime? at,
    String name = 'Sudeep',
    String phone = '+91 98765 43210',
    int price = 16500,
  }) async {
    final db = await store.databaseFor('owner');
    await db.insert('sales', {
      'id': id,
      'currency': 'INR',
      'lines': jsonEncode([
        {
          'sku': 'DOOR',
          'name': 'Door',
          'unitPriceMinor': price,
          'unitCostMinor': 15000,
          'quantity': 2,
          'parameters': [],
        },
      ]),
      'customerId': 'person',
      'customerName': name,
      'customerPhone': phone,
      'customerAddress': 'Market Road',
      'paymentStatus': 'partial',
      'paidMinor': 1000,
      'expectedPaymentMinor': price * 2 - 1000,
      'initialPaymentMinor': 1000,
      'payments': jsonEncode([
        {'amountMinor': 1000, 'createdAt': now.toIso8601String()},
      ]),
      'createdAt': (at ?? now).toIso8601String(),
    });
  }

  test('search reaches old bills, normalizes mobiles and matches exact formatted bill totals', () async {
    for (var i = 0; i < 85; i++) {
      await bill(
        'bill-$i',
        at: now.subtract(Duration(minutes: i)),
        name: i == 80 ? 'Laminated Sudeep' : 'Customer $i',
        phone: i == 80 ? '+91 (87654) 32109' : '9000000000',
        price: i == 80 ? 1250000 : 16500,
      );
    }
    expect(
      (await sales.list('owner', search: 'sUdEeP')).sales.single.id,
      'bill-80',
    );
    expect(
      (await sales.list('owner', search: '8765432109')).sales.single.id,
      'bill-80',
    );
    expect(
      (await sales.list('owner', search: '₹25,000.00')).sales.single.id,
      'bill-80',
    );
    expect((await sales.list('owner', search: '25000.01')).sales, isEmpty);
    expect((await sales.list('owner', search: '%_')).sales, isEmpty);
    final ids = <String>[];
    SalesCursor? cursor;
    do {
      final page = await sales.list('owner', search: 'customer', after: cursor);
      ids.addAll(page.sales.map((s) => s.id));
      cursor = page.next;
    } while (cursor != null);
    expect(ids.toSet().length, 84);
    expect(ids.length, 84);
    expect((await sales.recent('owner')).map((s) => s.id), [
      'bill-0',
      'bill-1',
      'bill-2',
    ]);
    expect((await sales.list('other', search: 'Sudeep')).sales, isEmpty);
  });

  test('contact-only correction preserves all money, stock, links and archived bytes; audit survives backup', () async {
    await bill('contact');
    final db = await store.databaseFor('owner');
    await saveCustomerRow(
      db,
      const CustomerDraft(
        name: 'Sudeep',
        phone: '+91 98765 43210',
        whatsappOptIn: false,
      ),
      id: 'person',
      at: now,
    );
    final docs = LocalBillDocumentRepository(store);
    final bytes = await File('test/fixtures/bill_duplicate.pdf').readAsBytes();
    await docs.saveDuplicate('owner', 'contact', bytes);
    final before = Map<String, Object?>.from((await db.query('sales')).single);
    await sales.updateContact(
      'owner',
      'contact',
      name: 'Sudip',
      phone: '9876543211',
      expectedName: 'Sudeep',
      expectedPhone: '+91 98765 43210',
    );
    final after = Map<String, Object?>.from((await db.query('sales')).single);
    expect(after.remove('customerName'), 'Sudip');
    expect(after.remove('customerPhone'), '9876543211');
    before.remove('customerName');
    before.remove('customerPhone');
    expect(after, before);
    expect(await db.query('movements'), isEmpty);
    expect((await db.query('customers')).single['name'], 'Sudeep');
    expect((await db.query('customers')).single['whatsappOptIn'], 0);
    expect(
      (await sales.forCustomer('owner', 'person')).single.draft.customerName,
      'Sudip',
    );
    expect(await docs.duplicate('owner', 'contact'), bytes);
    final audit = await db.query(
      'settings',
      where: 'key LIKE ?',
      whereArgs: ['bill-contact-edit/contact/%'],
    );
    expect(audit, hasLength(1));
    expect(
      jsonDecode(audit.single['value']! as String)['previousName'],
      'Sudeep',
    );
    final backup = await store.exportFor('owner');
    await store.restoreFor('owner', backup);
    expect(
      (await sales.get('owner', 'contact')).draft.customerPhone,
      '9876543211',
    );
    expect(
      await db.query(
        'settings',
        where: 'key LIKE ?',
        whereArgs: ['bill-contact-edit/contact/%'],
      ),
      audit,
    );
  });

  test('seven-day cutoff is checked atomically including boundary and clock-before-creation', () async {
    final created = now;
    await bill('timed');
    now = created
        .add(const Duration(days: 7))
        .subtract(const Duration(microseconds: 1));
    await sales.updateContact(
      'owner',
      'timed',
      name: 'Sudip',
      phone: '9876543211',
      expectedName: 'Sudeep',
      expectedPhone: '+91 98765 43210',
    );
    now = created.add(const Duration(days: 7));
    await expectLater(
      sales.updateContact(
        'owner',
        'timed',
        name: 'Changed',
        phone: '9876543212',
        expectedName: 'Sudip',
        expectedPhone: '9876543211',
      ),
      throwsA(anything),
    );
    now = created.subtract(const Duration(seconds: 1));
    await expectLater(
      sales.updateContact(
        'owner',
        'timed',
        name: 'Changed',
        phone: '9876543212',
        expectedName: 'Sudip',
        expectedPhone: '9876543211',
      ),
      throwsA(anything),
    );
    expect((await sales.get('owner', 'timed')).draft.customerName, 'Sudip');
  });

  test(
    'invalid, stale and cross-account edits cannot overwrite contacts',
    () async {
      await bill('safe');
      await expectLater(
        sales.updateContact(
          'owner',
          'safe',
          name: '',
          phone: '123',
          expectedName: 'Sudeep',
          expectedPhone: '+91 98765 43210',
        ),
        throwsA(anything),
      );
      await sales.updateContact(
        'owner',
        'safe',
        name: 'First edit',
        phone: '9876543211',
        expectedName: 'Sudeep',
        expectedPhone: '+91 98765 43210',
      );
      await expectLater(
        sales.updateContact(
          'owner',
          'safe',
          name: 'Stale edit',
          phone: '9876543212',
          expectedName: 'Sudeep',
          expectedPhone: '+91 98765 43210',
        ),
        throwsA(anything),
      );
      await expectLater(
        sales.updateContact(
          'other',
          'safe',
          name: 'Other edit',
          phone: '9876543212',
          expectedName: 'First edit',
          expectedPhone: '9876543211',
        ),
        throwsA(anything),
      );
      expect(
        (await sales.get('owner', 'safe')).draft.customerName,
        'First edit',
      );
    },
  );

  test('earnings subtract saved buying costs once and recorded operating expenses; receipts remain independent', () async {
    await bill('profit');
    final db = await store.databaseFor('owner');
    await db.insert('operating_expenses', {
      'id': 'rent',
      'category': 'Rent',
      'description': 'Synthetic expense',
      'currency': 'INR',
      'amountMinor': 1000,
      'occurredAt': now.toIso8601String(),
      'createdAt': now.toIso8601String(),
    });
    await db.insert('purchases', {
      'id': 'stock-purchase',
      'currency': 'INR',
      'items': jsonEncode([
        {'sku': 'DOOR', 'quantity': 10, 'unitCostMinor': 15000},
      ]),
      'paymentStatus': 'paid',
      'createdAt': now.toIso8601String(),
    });
    final report = await LocalReportsRepository(store).load(
      uid: 'owner',
      currency: 'INR',
      start: DateTime.utc(2026, 11, 1),
      endExclusive: DateTime.utc(2026, 12, 1),
    );
    expect(report.revenueMinor, BigInt.from(33000));
    expect(report.costOfGoodsMinor, BigInt.from(30000));
    expect(report.grossProfitMinor, BigInt.from(3000));
    expect(report.purchaseSpendMinor, BigInt.from(150000));
    expect(report.earningsAfterCostsMinor, BigInt.from(2000));
    expect(report.paidRevenueMinor, BigInt.from(1000));
    expect(report.unpaidRevenueMinor, BigInt.from(32000));
    expect(report.hasIncompleteCosts, isFalse);
  });
}
