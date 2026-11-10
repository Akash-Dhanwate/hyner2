import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/features/auth/data/device_access_repository.dart';
import 'package:hyner/features/customers/data/local_customer_repository.dart';
import 'package:hyner/features/customers/domain/customer.dart';
import 'package:hyner/features/reports/data/local_reports_repository.dart';
import 'package:hyner/features/sales/data/local_sales_repository.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/inventory/data/local_inventory_repository.dart';
import 'package:hyner/features/inventory/domain/inventory_repository.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'business/support/inventory_fakes.dart';

void main() {
  late Directory directory;
  late LocalBusinessDatabase store;
  late LocalInventoryRepository inventory;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('dashboard-inventory-');
    store = LocalBusinessDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    inventory = LocalInventoryRepository(store);
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<Product> save(
    String sku,
    String name, {
    String uid = 'alice',
    int stock = 4,
  }) async {
    await inventory.create(
      uid,
      ProductDraft(
        sku: sku,
        name: name,
        currency: 'INR',
        costMinor: 100,
        priceMinor: 250,
        openingStock: stock,
        reorderLevel: 1,
      ),
      'opening_$sku',
    );
    return inventory.get(uid, sku);
  }

  test('dashboard totals use saved customers and sales from only the selected workspace', () async {
    final product = await save('SALE', 'Sale product');
    final customers = LocalCustomerRepository(store);
    final customer = await customers.save(
      'alice',
      const CustomerDraft(name: 'Alice customer', phone: '9876543210'),
    );
    await customers.save(
      'bob',
      const CustomerDraft(name: 'Other workspace customer'),
    );
    await LocalSalesRepository(store).create(
      'alice',
      'bill-one',
      SaleDraft(
        currency: 'INR',
        customerId: customer.id,
        customerName: customer.name,
        customerPhone: customer.phone,
        lines: [SaleLine.fromProduct(product, 2)],
        initialPaymentMinor: 200,
      ),
    );
    await LocalSalesRepository(store)
        .recordPayment('alice', 'bill-one', 200, operationId: 'received');
    final report = await LocalReportsRepository(store).load(
      uid: 'alice',
      currency: 'INR',
      start: DateTime.utc(1970),
      endExclusive: DateTime.now().toUtc().add(const Duration(days: 1)),
    );
    expect((await customers.list('alice')).length, 1);
    expect(report.salesCount, 1);
    expect(report.revenueMinor, BigInt.from(500));
    expect(report.paidRevenueMinor, BigInt.from(200));
    expect(report.unpaidRevenueMinor, BigInt.from(300));
    expect(
      report.activity.any((point) => point.revenueMinor == BigInt.from(500)),
      isTrue,
    );
    expect((await inventory.get('alice', 'SALE')).quantity, 2);
  });

  test('saved products remain visible after reopening and separate from device and other accounts', () async {
    await save('ACCOUNT', 'Account product');
    await save('DEVICE', 'Device product', uid: deviceOwnerUid);
    await save('OTHER', 'Other account product', uid: 'bob');
    await store.close();
    store = LocalBusinessDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    inventory = LocalInventoryRepository(store);
    for (final pair in [
      ('alice', 'ACCOUNT'),
      (deviceOwnerUid, 'DEVICE'),
      ('bob', 'OTHER'),
    ]) {
      final page = await inventory.list(pair.$1, const InventoryQuery());
      expect(page.products.map((p) => p.sku), [pair.$2]);
      expect(page.products.single.quantity, 4);
    }
  });

  test(
    'SQLite pagination keeps accented names in its actual sort order',
    () async {
      for (var i = 0; i < 29; i++) {
        await save('ITEM_$i', 'Item ${i.toString().padLeft(2, '0')}');
      }
      await save('ACCENT', 'Éclair');
      await save('NEXT', 'Øyster');
      await save('LOWER', 'élan');
      await save('GREEK', 'Ωmega');
      final expected = await (await store.databaseFor('alice')).query(
        'products',
        columns: ['sku'],
        orderBy: 'name COLLATE NOCASE ASC, sku ASC',
      );
      final actual = <String>[];
      InventoryCursor? cursor;
      do {
        final page = await inventory.list(
          'alice',
          const InventoryQuery(),
          after: cursor,
        );
        actual.addAll(page.products.map((p) => p.sku));
        cursor = page.next;
      } while (cursor != null);
      expect(actual, expected.map((row) => row['sku']).toList());
      expect(actual.length, 33);
      expect(actual.toSet().length, 33);
    },
  );

  test('name and code prefixes ignore ASCII case and accented names match both cases', () async {
    await save('RICE_1', 'Rice bag');
    await save('ACCENT_A', 'Éclair');
    await save('ACCENT_B', 'école');
    final byName = await inventory.list(
      'alice',
      const InventoryQuery(search: ' rIcE '),
    );
    expect(byName.products.single.sku, 'RICE_1');
    final byCode = await inventory.list(
      'alice',
      const InventoryQuery(search: ' rice_ ', searchBy: ProductSearch.code),
    );
    expect(byCode.products.single.sku, 'RICE_1');
    for (final search in ['É', 'é']) {
      final page = await inventory.list(
        'alice',
        InventoryQuery(search: search),
      );
      expect(page.products.map((p) => p.sku).toSet(), {'ACCENT_A', 'ACCENT_B'});
    }
  });

  test('prefix wildcards are literal and archive filter does not erase active products', () async {
    await save('A_1', '100% Pure');
    await save('A11', '1000 Pure');
    final archived = await save('OLD', 'Archived product', stock: 0);
    await inventory.setArchived('alice', archived, true);
    final code = await inventory.list(
      'alice',
      const InventoryQuery(search: 'A_', searchBy: ProductSearch.code),
    );
    expect(code.products.map((p) => p.sku), ['A_1']);
    final name = await inventory.list(
      'alice',
      const InventoryQuery(search: '100%'),
    );
    expect(name.products.map((p) => p.sku), ['A_1']);
    expect(
      (await inventory.list(
        'alice',
        const InventoryQuery(archived: true),
      )).products.single.sku,
      'OLD',
    );
    expect(
      (await inventory.list(
        'alice',
        const InventoryQuery(),
      )).products.map((p) => p.sku).toSet(),
      {'A_1', 'A11'},
    );
  });

  test('manual import retry bypasses cooldown and failure notice belongs to its account', () async {
    final source = FakeInventory()..failure = inventoryInvalid('Offline');
    inventory = LocalInventoryRepository(store, legacySource: source);
    expect(
      (await inventory.list('alice', const InventoryQuery())).products,
      isEmpty,
    );
    expect(inventory.legacyImportFailedFor('alice'), isTrue);
    expect(inventory.legacyImportFailedFor(deviceOwnerUid), isFalse);
    final calls = source.listCalls;
    await inventory.list(deviceOwnerUid, const InventoryQuery());
    expect(source.listCalls, calls);
    source.failure = null;
    source.products('alice')['RECOVERED'] = inventoryFixture(sku: 'RECOVERED');
    inventory.allowLegacyImportRetry('alice');
    final page = await inventory.list('alice', const InventoryQuery());
    expect(page.products.single.sku, 'RECOVERED');
    expect(inventory.legacyImportFailedFor('alice'), isFalse);
    expect(
      (await inventory.list(deviceOwnerUid, const InventoryQuery())).products,
      isEmpty,
    );
  });
}
