import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/features/customers/data/local_customer_repository.dart';
import 'package:hyner/features/customers/domain/customer.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test('v11 upgrade adds only indexes and preserves rows, preferences and backup format', () async {
    final folder = await Directory.systemTemp.createTemp(
      'hyner-index-upgrade-',
    );
    final store = LocalBusinessDatabase(
      factory: databaseFactoryFfi,
      directory: folder.path,
    );
    addTearDown(() async {
      await store.close();
      await folder.delete(recursive: true);
    });
    final people = LocalCustomerRepository(store);
    await people.save(
      'owner',
      const CustomerDraft(
        name: 'Buyer',
        phone: '9876543210',
        whatsappOptIn: false,
      ),
    );
    final db = await store.databaseFor('owner');
    await db.insert('sales', {
      'id': 'unchanged',
      'currency': 'INR',
      'lines': jsonEncode([
        {
          'sku': 'A',
          'name': 'Panel',
          'quantity': 2,
          'unitPriceMinor': 12555,
          'unitCostMinor': 10000,
        },
      ]),
      'customerName': 'Buyer',
      'paymentStatus': 'partial',
      'paidMinor': 5005,
      'createdAt': '2026-11-10T00:00:00.000Z',
      'followupAt': '2026-11-12T00:00:00.000Z',
    });
    await db.insert('settings', {
      'key': 'billFontColors',
      'value': '{"businessName":12986408}',
    });
    final originalSales = await db.query('sales');
    final originalCustomers = await db.query('customers');
    final originalSettings = await db.query('settings');
    final path = db.path;
    for (final name in [
      'sales_customer_created',
      'sales_followup_due',
      'sales_currency_created',
    ]) {
      await db.execute('DROP INDEX $name');
    }
    await store.close();
    final old = await databaseFactoryFfi.openDatabase(path);
    await old.setVersion(11);
    await old.close();
    final upgraded = await store.databaseFor('owner');
    expect(await upgraded.getVersion(), 12);
    expect(await upgraded.query('sales'), originalSales);
    expect(await upgraded.query('customers'), originalCustomers);
    expect(await upgraded.query('settings'), originalSettings);
    final indexes = (await upgraded.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index'",
    )).map((row) => row['name']).toSet();
    expect(
      indexes,
      containsAll([
        'sales_customer_created',
        'sales_followup_due',
        'sales_currency_created',
      ]),
    );
    expect((await store.exportFor('owner'))['schemaVersion'], 10);
    final followupPlan = (await upgraded.rawQuery(
      'EXPLAIN QUERY PLAN SELECT * FROM sales WHERE followupAt IS NOT NULL ORDER BY followupAt ASC',
    )).map((row) => row['detail']).join(' ');
    expect(followupPlan, contains('sales_followup_due'));
    expect(followupPlan, isNot(contains('TEMP B-TREE')));
    final customerPlan = (await upgraded.rawQuery(
      'EXPLAIN QUERY PLAN SELECT * FROM sales WHERE customerId = ? ORDER BY createdAt DESC,id DESC',
      ['buyer'],
    )).map((row) => row['detail']).join(' ');
    expect(customerPlan, contains('sales_customer_created'));
    final reportPlan = (await upgraded.rawQuery(
      'EXPLAIN QUERY PLAN SELECT * FROM sales WHERE currency = ? AND createdAt >= ? AND createdAt < ? ORDER BY createdAt DESC',
      ['INR', '2026-11-01', '2026-12-01'],
    )).map((row) => row['detail']).join(' ');
    expect(reportPlan, contains('sales_currency_created'));
  });
}
