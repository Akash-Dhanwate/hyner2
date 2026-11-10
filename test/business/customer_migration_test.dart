import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/features/customers/data/local_customer_repository.dart';
import 'package:hyner/features/customers/domain/customer.dart';
import 'package:hyner/features/sales/data/local_sales_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late LocalBusinessDatabase store;
  const uid = 'owner';
  final time = DateTime.utc(2023, 2, 3).toIso8601String();

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'hyner-customer-migration-',
    );
    store = LocalBusinessDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  Map<String, Object?> customer(
    String id, {
    String name = 'Asha Buyer',
    String phone = '9876543210',
  }) => {
    'id': id,
    'name': name,
    'phone': phone,
    'address': 'Directory address',
    'notes': 'Keep notes',
    'whatsappOptIn': 1,
    'createdAt': time,
    'updatedAt': time,
  };

  Map<String, Object?> bill(
    String id, {
    String? customerId,
    String? name = 'Asha Buyer',
    String? phone = '9876543210',
    String? address = 'Bill address',
  }) => {
    'id': id,
    'currency': 'INR',
    'lines': jsonEncode([
      {
        'sku': 'A',
        'name': 'Historical item',
        'unitPriceMinor': 100,
        'unitCostMinor': 40,
        'quantity': 2,
        'parameters': [
          {'name': 'Size', 'value': 'Large'},
        ],
      },
    ]),
    'customerId': customerId,
    'customerName': name,
    'customerPhone': phone,
    'customerAddress': address,
    'paymentStatus': 'partial',
    'initialPaymentMinor': 80,
    'expectedPaymentMinor': 150,
    'paidMinor': 50,
    'payments': jsonEncode([
      {'amountMinor': 50, 'createdAt': time, 'operationId': 'old_payment'},
    ]),
    'followupAt': DateTime.utc(2024).toIso8601String(),
    'createdAt': time,
    'paidAt': null,
  };

  // Remove every v10 addition; changing only user_version is not an old schema.
  Future<Database> downgrade(int version) async {
    final db = await store.databaseFor(uid);
    final path = db.path;
    await store.close();
    final old = await databaseFactoryFfi.openDatabase(path);
    await old.execute('DROP TABLE bill_documents');
    await old.execute('DROP INDEX customers_identity');
    await old.execute('ALTER TABLE customers DROP COLUMN identityKey');
    if (version == 8) {
      await old.execute('ALTER TABLE customers DROP COLUMN address');
      await old.execute('ALTER TABLE sales DROP COLUMN customerAddress');
    }
    await old.setVersion(version);
    return old;
  }

  for (final version in [8, 9]) {
    test(
      'v$version repairs only unlinked contacts without changing bill or directory snapshots',
      () async {
        final old = await downgrade(version);
        final first = customer('a_oldest');
        final duplicate = customer(
          'b_duplicate',
          name: 'ASHA   BUYER',
          phone: '(987) 654-3210',
        );
        for (final row in [first, duplicate]) {
          if (version == 8) row.remove('address');
          await old.insert('customers', row);
        }
        final fixtures = [
          bill('already_linked', customerId: 'b_duplicate'),
          bill('dangling_existing_link', customerId: 'external_legacy_id'),
          bill('matching', name: 'asha   buyer', phone: '98765 43210'),
          bill('new_contact', name: 'New Buyer', phone: '9123456780'),
          bill(
            'new_contact_again',
            name: 'NEW  BUYER',
            phone: '(912) 345-6780',
          ),
          bill('anonymous', name: null, phone: null),
          bill('missing_name', name: '  '),
          bill('invalid_mobile', phone: 'not a mobile'),
          bill('missing_mobile', phone: ''),
        ];
        for (final row in fixtures) {
          if (version == 8) row.remove('customerAddress');
          await old.insert('sales', row);
        }
        final before = await old.query('sales', orderBy: 'id');
        final oldCustomers = await old.query('customers', orderBy: 'id');
        await old.close();

        final db = await store.databaseFor(uid);
        expect(await db.getVersion(), 11);
        expect(await db.query('bill_documents'), isEmpty);
        final archiveColumns = await db.rawQuery(
          'PRAGMA table_info(bill_documents)',
        );
        expect(
          archiveColumns.singleWhere(
            (row) => row['name'] == 'encoding',
          )['dflt_value'],
          "'pdf'",
        );
        final after = await db.query('sales', orderBy: 'id');
        for (var i = 0; i < before.length; i++) {
          final expected = {...before[i]}..remove('customerId');
          if (version == 8) expected['customerAddress'] = null;
          expect(
            {...after[i]}..remove('customerId'),
            expected,
            reason: before[i]['id']! as String,
          );
        }
        final links = {for (final row in after) row['id']: row['customerId']};
        expect(links['already_linked'], 'b_duplicate');
        expect(links['dangling_existing_link'], 'external_legacy_id');
        expect(links['matching'], 'a_oldest');
        expect(links['new_contact'], isNotNull);
        expect(links['new_contact_again'], links['new_contact']);
        for (final id in [
          'anonymous',
          'missing_name',
          'invalid_mobile',
          'missing_mobile',
        ]) {
          expect(links[id], isNull, reason: id);
        }
        final people = await db.query('customers', orderBy: 'id');
        expect(people, hasLength(3));
        for (final row in oldCustomers) {
          final actual = people.singleWhere(
            (person) => person['id'] == row['id'],
          );
          final expected = {...row};
          if (version == 8) expected['address'] = '';
          expect({...actual}..remove('identityKey'), expected);
        }
        expect(
          people.singleWhere((row) => row['id'] == 'a_oldest')['identityKey'],
          customerIdentityKey('Asha Buyer', '9876543210'),
        );
        expect(
          people.singleWhere(
            (row) => row['id'] == 'b_duplicate',
          )['identityKey'],
          isNull,
        );
        final newPerson = people.singleWhere(
          (row) => row['id'] == links['new_contact'],
        );
        expect(newPerson['createdAt'], time);
        expect(newPerson['whatsappOptIn'], 1);
        expect(newPerson['address'], version == 8 ? '' : 'Bill address');

        // A legacy duplicate can still be edited without stealing the canonical key.
        await LocalCustomerRepository(store).save(
          uid,
          CustomerDraft(
            name: duplicate['name']! as String,
            phone: duplicate['phone']! as String,
            notes: 'Edited legacy note',
          ),
          id: 'b_duplicate',
        );
        expect(
          (await db.query(
            'customers',
            where: 'id = ?',
            whereArgs: ['b_duplicate'],
          )).single['identityKey'],
          isNull,
        );
        final stable = (await store.exportFor(uid))['tables'];
        await store.close();
        expect((await store.exportFor(uid))['tables'], stable);
        final repository = LocalSalesRepository(store);
        final historical = await repository.get(uid, 'matching');
        await repository.create(
          uid,
          'matching',
          historical.draft.linkedTo(null),
        );
        expect((await store.exportFor(uid))['tables'], stable);
      },
    );
  }

  test('v9 repair crosses cursor pages with invalid contacts and canonical matches', () async {
    final old = await downgrade(9);
    await old.transaction((tx) async {
      for (var i = 0; i < 205; i++) {
        await tx.insert(
          'sales',
          bill(
            'bill_${i.toString().padLeft(3, '0')}',
            phone: i < 100 ? 'invalid' : '9876543210',
          ),
        );
      }
    });
    await old.close();
    final db = await store.databaseFor(uid);
    expect(
      await db.query('sales', where: 'customerId IS NULL'),
      hasLength(100),
    );
    expect(
      await db.query('sales', where: 'customerId IS NOT NULL'),
      hasLength(105),
    );
    final people = await db.query('customers');
    expect(people, hasLength(1));
    expect(
      await db.query(
        'sales',
        where: 'customerId = ?',
        whereArgs: [people.single['id']],
      ),
      hasLength(105),
    );
  });

  test('v9 customer identity repair spans pages and preserves legacy duplicate IDs', () async {
    final old = await downgrade(9);
    await old.transaction((tx) async {
      for (var index = 0; index < 205; index++) {
        await tx.insert(
          'customers',
          customer('person_${index.toString().padLeft(3, '0')}'),
        );
      }
    });
    await old.close();
    final db = await store.databaseFor(uid);
    final rows = await db.query('customers', orderBy: 'id');
    expect(rows, hasLength(205));
    expect(
      rows.first['identityKey'],
      customerIdentityKey('Asha Buyer', '9876543210'),
    );
    expect(rows.skip(1).every((row) => row['identityKey'] == null), isTrue);
    expect((await LocalCustomerRepository(store).list(uid)).length, 205);
  });

  test('v9 malformed historical contacts stay readable without aborting the upgrade', () async {
    final old = await downgrade(9);
    final invalid = [
      bill('long_mobile', phone: '9876543210${List.filled(40, ' ').join()}'),
      bill('long_address', address: List.filled(241, 'x').join()),
    ];
    for (final row in invalid) {
      await old.insert('sales', row);
    }
    await old.close();
    final db = await store.databaseFor(uid);
    expect(await db.getVersion(), 11);
    expect(await db.query('customers'), isEmpty);
    final rows = await db.query('sales', orderBy: 'id');
    expect(rows.every((row) => row['customerId'] == null), isTrue);
    for (final row in rows) {
      expect(row, invalid.singleWhere((item) => item['id'] == row['id']));
    }
  });

  test('v9 JSON backup repairs links and ignores supplied identity keys atomically', () async {
    await store.databaseFor(uid);
    final snapshot = await store.exportFor(uid);
    final tables = Map<String, Object?>.from(snapshot['tables'] as Map)
      ..remove('bill_documents');
    tables['customers'] = [customer('existing')];
    tables['sales'] = [
      bill('matching'),
      bill('new', name: 'New Buyer', phone: '9123456780'),
    ];
    await store.restoreFor(
      uid,
      jsonDecode(
        jsonEncode({...snapshot, 'schemaVersion': 9, 'tables': tables}),
      ) as Map<String, dynamic>,
    );
    final db = await store.databaseFor(uid);
    final saved = await db.query('sales', orderBy: 'id');
    expect(saved.first['customerId'], 'existing');
    expect(saved.last['customerId'], isNotNull);
    for (final row in saved) {
      final original = (tables['sales'] as List).cast<Map>().singleWhere(
        (item) => item['id'] == row['id'],
      );
      expect(
        {...row}..remove('customerId'),
        {...original}..remove('customerId'),
      );
    }
    final current = await store.exportFor(uid);
    final currentTables = Map<String, Object?>.from(current['tables'] as Map);
    currentTables['customers'] = [
      for (final raw in currentTables['customers'] as List)
        {...raw as Map, 'identityKey': 'untrusted duplicate key'},
    ];
    await store.restoreFor(uid, {...current, 'tables': currentTables});
    expect((await store.exportFor(uid))['tables'], current['tables']);
  });
}
