import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/features/customers/data/local_customer_repository.dart';
import 'package:hyner/features/customers/domain/customer.dart';
import 'package:hyner/features/inventory/data/local_inventory_repository.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/sales/data/local_sales_repository.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/settings/data/local_payment_settings_repository.dart';
import 'package:hyner/features/settings/domain/payment_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late LocalBusinessDatabase store;
  late LocalSalesRepository sales;
  late LocalCustomerRepository customers;
  late LocalInventoryRepository inventory;
  late Product product;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hyner-customer-bill-');
    store = LocalBusinessDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    sales = LocalSalesRepository(store);
    customers = LocalCustomerRepository(store);
    inventory = LocalInventoryRepository(store);
    await inventory.create(
      'owner',
      ProductDraft(
        sku: 'A',
        name: 'Item A',
        currency: 'INR',
        costMinor: 50,
        priceMinor: 100,
        openingStock: 10,
        reorderLevel: 1,
      ),
      'opening',
    );
    product = await inventory.get('owner', 'A');
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  SaleDraft draft({
    String? name = 'Asha Buyer',
    String? phone = '9876543210',
    String? address = '42 Market Road',
  }) => SaleDraft(
    currency: 'INR',
    customerName: name,
    customerPhone: phone,
    customerAddress: address,
    initialPaymentMinor: 0,
    lines: [SaleLine.fromProduct(product, 2)],
  );

  test(
    'contact/address snapshots persist and same bill saves/stock apply once',
    () async {
      await Future.wait([
        sales.create('owner', 'bill', draft()),
        sales.create('owner', 'bill', draft()),
      ]);
      await sales.create('owner', 'bill', draft());
      final saved = await sales.get('owner', 'bill');
      expect(saved.draft.customerName, 'Asha Buyer');
      expect(saved.draft.customerPhone, '9876543210');
      expect(saved.draft.customerAddress, '42 Market Road');
      expect(saved.draft.firstPaymentMinor, 0);
      expect((await inventory.get('owner', 'A')).quantity, 8);
      final db = await store.databaseFor('owner');
      expect(await db.query('sales'), hasLength(1));
      final people = await customers.list('owner');
      expect(people, hasLength(1));
      expect(saved.draft.customerId, people.single.id);
      expect(people.single.address, '42 Market Road');
      expect(
        (await sales.forCustomer('owner', people.single.id)).single.id,
        'bill',
      );
      expect(
        await db.query('movements', where: 'type = ?', whereArgs: ['sale']),
        hasLength(1),
      );
      await expectLater(
        sales.create('owner', 'bill', draft(address: 'Different address')),
        throwsA(isA<AppFailure>()),
      );
      expect((await inventory.get('owner', 'A')).quantity, 8);
    },
  );

  test(
    'new anonymous/incomplete contacts fail without stock or bill changes',
    () async {
      for (final invalid in [
        draft(name: null),
        draft(phone: ''),
        draft(phone: '123'),
        draft(phone: 'not a phone'),
      ]) {
        await expectLater(
          sales.create('owner', 'invalid', invalid),
          throwsA(isA<AppFailure>()),
        );
      }
      expect((await inventory.get('owner', 'A')).quantity, 10);
      expect(await (await store.databaseFor('owner')).query('sales'), isEmpty);
      expect(await customers.list('owner'), isEmpty);
    },
  );

  test(
    'concurrent checkout and directory saves share the canonical contact',
    () async {
      await Future.wait([
        sales.create('owner', 'first', draft()),
        sales.create(
          'owner',
          'second',
          draft(
            name: 'ASHA   Buyer',
            phone: '(987) 654-3210',
            address: 'Other road',
          ),
        ),
        customers.save(
          'owner',
          const CustomerDraft(name: 'asha buyer', phone: '98765 43210'),
        ),
      ]);
      final person = (await customers.list('owner')).single;
      expect((await sales.get('owner', 'first')).draft.customerId, person.id);
      expect((await sales.get('owner', 'second')).draft.customerId, person.id);
      expect(await sales.forCustomer('owner', person.id), hasLength(2));
      expect((await inventory.get('owner', 'A')).quantity, 6);
      expect(
        (await sales.get('owner', 'second')).draft.customerName,
        'ASHA   Buyer',
      );
      expect(
        (await sales.get('owner', 'second')).draft.customerPhone,
        '(987) 654-3210',
      );
    },
  );

  test('identity requires both name and mobile; incomplete directory contacts stay separate', () async {
    await sales.create('owner', 'one', draft());
    await sales.create('owner', 'two', draft(phone: '9123456780'));
    await sales.create('owner', 'three', draft(name: 'Another Buyer'));
    final people = await customers.list('owner');
    expect(people, hasLength(3));
    expect(people.map((person) => person.id).toSet(), hasLength(3));
    for (var i = 0; i < 2; i++) {
      await customers.save('owner', const CustomerDraft(name: 'No Mobile'));
    }
    final db = await store.databaseFor('owner');
    expect(
      await db.query('customers', where: 'identityKey IS NULL'),
      hasLength(2),
    );
  });

  test('checkout preserves directory contact and consent while retaining bill snapshots', () async {
    final person = await customers.save(
      'owner',
      const CustomerDraft(
        name: 'Asha Buyer',
        phone: '9876543210',
        address: 'Directory address',
        notes: 'Private directory note',
        whatsappOptIn: true,
      ),
    );
    final db = await store.databaseFor('owner');
    final before = (await db.query('customers')).single;
    final bill = draft(address: 'Bill address').linkedTo(person.id);
    await sales.create('owner', 'selected', bill);
    final after = (await db.query('customers')).single;
    expect({...after}..remove('updatedAt'), {...before}..remove('updatedAt'));
    expect(
      (await sales.get('owner', 'selected')).draft.customerAddress,
      'Bill address',
    );
    await customers.save(
      'owner',
      const CustomerDraft(
        name: 'New Directory Name',
        phone: '9123456780',
        address: 'New address',
      ),
      id: person.id,
    );
    final persisted = (await db.query('sales')).single;
    await sales.create('owner', 'selected', bill);
    expect((await db.query('sales')).single, persisted);
    expect((await inventory.get('owner', 'A')).quantity, 8);
  });

  test(
    'unlinked retry after directory edits uses the persisted bill link',
    () async {
      final bill = draft();
      await sales.create('owner', 'retry', bill);
      final person = (await customers.list('owner')).single;
      await customers.save(
        'owner',
        const CustomerDraft(name: 'Changed Name', phone: '9123456780'),
        id: person.id,
      );
      final db = await store.databaseFor('owner');
      final before = (await store.exportFor('owner'))['tables'];
      await sales.create('owner', 'retry', bill);
      expect((await store.exportFor('owner'))['tables'], before);
      final other = await customers.save(
        'owner',
        const CustomerDraft(name: 'Other Person', phone: '9988776655'),
      );
      await expectLater(
        sales.create('owner', 'retry', bill.linkedTo(other.id)),
        throwsA(isA<AppFailure>()),
      );
      expect((await db.query('sales')).single['customerId'], person.id);
      expect((await inventory.get('owner', 'A')).quantity, 8);
    },
  );

  test('failure on a later stock line rolls back customer creation and permits retry', () async {
    await inventory.create(
      'owner',
      ProductDraft(
        sku: 'B',
        name: 'Item B',
        currency: 'INR',
        costMinor: 50,
        priceMinor: 100,
        openingStock: 1,
        reorderLevel: 0,
      ),
      'opening_b',
    );
    final second = await inventory.get('owner', 'B');
    final before = (await store.exportFor('owner'))['tables'];
    await expectLater(
      sales.create(
        'owner',
        'rollback',
        SaleDraft(
          currency: 'INR',
          customerName: 'Asha Buyer',
          customerPhone: '9876543210',
          lines: [
            SaleLine.fromProduct(product, 2),
            SaleLine.fromProduct(second, 2),
          ],
        ),
      ),
      throwsA(isA<AppFailure>()),
    );
    expect((await store.exportFor('owner'))['tables'], before);
    expect(await customers.list('owner'), isEmpty);
    await sales.create('owner', 'rollback', draft());
    expect(await customers.list('owner'), hasLength(1));
    expect((await inventory.get('owner', 'A')).quantity, 8);
  });

  test(
    'SQL failure after stock writes rolls back both new and selected customers',
    () async {
      final person = await customers.save(
        'owner',
        const CustomerDraft(name: 'Selected'),
      );
      final db = await store.databaseFor('owner');
      await db.execute("""
      CREATE TRIGGER reject_bill BEFORE INSERT ON sales
      BEGIN SELECT RAISE(ABORT, 'injected bill failure'); END
    """);
      for (final bill in [draft(), draft().linkedTo(person.id)]) {
        final before = (await store.exportFor('owner'))['tables'];
        await expectLater(
          sales.create('owner', 'sql_failure', bill),
          throwsA(isA<DatabaseException>()),
        );
        expect((await store.exportFor('owner'))['tables'], before);
      }
      await db.execute('DROP TRIGGER reject_bill');
      await sales.create('owner', 'sql_failure', draft());
      expect((await inventory.get('owner', 'A')).quantity, 8);
    },
  );

  test(
    'editing into another canonical identity fails without changing either row',
    () async {
      final first = await customers.save(
        'owner',
        const CustomerDraft(name: 'Asha Buyer', phone: '9876543210'),
      );
      await customers.save(
        'owner',
        const CustomerDraft(name: 'Other', phone: '9123456780'),
      );
      final before = (await store.exportFor('owner'))['tables'];
      await expectLater(
        customers.save(
          'owner',
          const CustomerDraft(name: 'OTHER', phone: '(912) 345-6780'),
          id: first.id,
        ),
        throwsFormatException,
      );
      expect((await store.exportFor('owner'))['tables'], before);
    },
  );

  test(
    'customer links are account scoped, including explicit foreign IDs',
    () async {
      await sales.create('owner', 'bill', draft());
      final ownerPerson = (await customers.list('owner')).single;
      await inventory.create(
        'other',
        ProductDraft(
          sku: 'A',
          name: 'Item A',
          currency: 'INR',
          costMinor: 50,
          priceMinor: 100,
          openingStock: 10,
          reorderLevel: 1,
        ),
        'opening',
      );
      await expectLater(
        sales.create('other', 'bill', draft().linkedTo(ownerPerson.id)),
        throwsFormatException,
      );
      expect(await customers.list('other'), isEmpty);
      expect((await inventory.get('other', 'A')).quantity, 10);
      await sales.create('other', 'bill', draft());
      final otherPerson = (await customers.list('other')).single;
      expect(otherPerson.id, isNot(ownerPerson.id));
      expect((await sales.forCustomer('other', ownerPerson.id)), isEmpty);
      expect(
        (await sales.forCustomer('owner', ownerPerson.id)).single.id,
        'bill',
      );
      await store.close();
      expect((await customers.list('owner')).single.id, ownerPerson.id);
      expect((await customers.list('other')).single.id, otherPerson.id);
    },
  );

  test(
    'customer address edits do not rewrite saved invoice snapshots',
    () async {
      final customer = await customers.save(
        'owner',
        const CustomerDraft(
          name: 'Existing Buyer',
          phone: '9876543210',
          address: 'Original Street',
        ),
      );
      final bill = SaleDraft(
        currency: 'INR',
        customerId: customer.id,
        customerName: customer.name,
        customerPhone: customer.phone,
        customerAddress: customer.address,
        lines: [SaleLine.fromProduct(product, 1)],
      );
      await sales.create('owner', 'linked', bill);
      await customers.save(
        'owner',
        const CustomerDraft(name: 'Edited Buyer', address: 'New Street'),
        id: customer.id,
      );
      expect((await customers.list('owner')).single.address, 'New Street');
      expect(
        (await sales.get('owner', 'linked')).draft.customerAddress,
        'Original Street',
      );
      expect(
        (await sales.get('owner', 'linked')).draft.customerName,
        'Existing Buyer',
      );
    },
  );

  test('history includes older duplicate identities without leaking another customer', () async {
    await sales.create('owner', 'recent', draft());
    final db = await store.databaseFor('owner');
    final primary = (await db.query('customers')).single;
    await db.insert('customers', {
      ...primary,
      'id': 'legacy-duplicate',
      'name': ' ASHA   Buyer ',
      'phone': '(987) 654-3210',
      'identityKey': null,
    });
    await sales.create('owner', 'older', draft());
    await db.update(
      'sales',
      {'customerId': 'legacy-duplicate'},
      where: 'id = ?',
      whereArgs: ['older'],
    );
    await sales.create('owner', 'unlinked', draft());
    await db.update(
      'sales',
      {'customerId': null},
      where: 'id = ?',
      whereArgs: ['unlinked'],
    );
    await sales.create('owner', 'different-phone', draft(phone: '9123456780'));
    for (final id in [primary['id']! as String, 'legacy-duplicate']) {
      expect(
        (await sales.forCustomer('owner', id)).map((sale) => sale.id),
        unorderedEquals(['recent', 'older', 'unlinked']),
      );
    }
    expect(
      (await sales.get('owner', 'older')).draft.customerId,
      'legacy-duplicate',
    );
    expect(
      (await sales.get('owner', 'older')).draft.lines.single.unitPriceMinor,
      100,
    );
  });

  test('v10 enables all updates once and later exclusions survive checkout and reopen', () async {
    final customer = await customers.save(
      'owner',
      const CustomerDraft(
        name: 'Asha Buyer',
        phone: '9876543210',
        whatsappOptIn: false,
      ),
    );
    final db = await store.databaseFor('owner');
    final path = db.path;
    await store.close();
    final old = await databaseFactoryFfi.openDatabase(path);
    await old.setVersion(10);
    await old.close();
    expect((await customers.list('owner')).single.whatsappOptIn, isTrue);
    await customers.save(
      'owner',
      const CustomerDraft(
        name: 'Asha Buyer',
        phone: '9876543210',
        whatsappOptIn: false,
      ),
      id: customer.id,
    );
    await sales.create('owner', 'after-exclusion', draft());
    await store.close();
    expect((await customers.list('owner')).single.whatsappOptIn, isFalse);
    final added = await customers.save(
      'owner',
      const CustomerDraft(name: 'New customer', phone: '9123456780'),
    );
    expect(added.whatsappOptIn, isTrue);
  });

  test(
    'bill colours persist across reopen and invalid colour data uses defaults',
    () async {
      final repository = LocalPaymentSettingsRepository(store);
      await repository.save(
        'owner',
        const PaymentSettings(
          merchantName: 'Asha Store',
          fontColors: {
            BillTextSection.businessName: 0xc62828,
            BillTextSection.items: 0x000000,
          },
        ),
      );
      await store.close();
      final saved = await repository.read('owner');
      expect(saved.fontColor(BillTextSection.businessName), 0xc62828);
      expect(saved.fontColor(BillTextSection.items), 0x000000);
      final db = await store.databaseFor('owner');
      await db.update(
        'settings',
        {'value': 'broken'},
        where: 'key = ?',
        whereArgs: ['billFontColors'],
      );
      expect((await repository.read('owner')).fontColors, isEmpty);
      await expectLater(
        repository.save(
          'owner',
          const PaymentSettings(fontColors: {BillTextSection.items: -1}),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'schema v8 migration preserves anonymous bills and customer defaults',
    () async {
      await customers.save(
        'owner',
        const CustomerDraft(name: 'Legacy Customer', phone: '9876543210'),
      );
      await sales.create('owner', 'legacy', draft());
      final db = await store.databaseFor('owner');
      // A pre-v9 bill could be anonymous. Keep its stock movement intact.
      await db.update(
        'sales',
        {'customerId': null, 'customerName': null, 'customerPhone': null},
        where: 'id = ?',
        whereArgs: ['legacy'],
      );
      final path = db.path;
      await store.close();
      final old = await databaseFactoryFfi.openDatabase(path);
      await old.execute('DROP TABLE bill_documents');
      await old.execute('DROP INDEX customers_identity');
      await old.execute('ALTER TABLE customers DROP COLUMN identityKey');
      await old.execute('ALTER TABLE customers DROP COLUMN address');
      await old.execute('ALTER TABLE sales DROP COLUMN customerAddress');
      await old.setVersion(8);
      await old.close();
      expect(await (await store.databaseFor('owner')).getVersion(), 12);
      expect(await customers.list('owner'), hasLength(2));
      expect(
        (await customers.list('owner')).every((c) => c.address.isEmpty),
        isTrue,
      );
      final saved = await sales.get('owner', 'legacy');
      expect(saved.draft.customerName, isNull);
      expect(saved.draft.customerAddress, isNull);
      expect((await inventory.get('owner', 'A')).quantity, 8);
      // Existing legacy operation IDs are still retryable under legacy rules.
      await sales.create('owner', 'legacy', saved.draft);
      expect((await inventory.get('owner', 'A')).quantity, 8);
    },
  );

  test('schema v8 backups restore with empty address defaults', () async {
    await customers.save('owner', const CustomerDraft(name: 'Legacy Customer'));
    await sales.create('owner', 'legacy', draft());
    final snapshot = await store.exportFor('owner');
    final tables = Map<String, Object?>.from(snapshot['tables'] as Map);
    tables.remove('bill_documents');
    tables['customers'] = [
      for (final row in tables['customers'] as List)
        Map<String, Object?>.from(row as Map)
          ..remove('address')
          ..remove('identityKey'),
    ];
    tables['sales'] = [
      for (final row in tables['sales'] as List)
        Map<String, Object?>.from(row as Map)..remove('customerAddress'),
    ];
    await store.restoreFor('owner', {
      ...snapshot,
      'schemaVersion': 8,
      'tables': tables,
    });
    expect(
      (await customers.list('owner')).every((c) => c.address.isEmpty),
      isTrue,
    );
    expect((await sales.get('owner', 'legacy')).draft.customerAddress, isNull);
  });
}
