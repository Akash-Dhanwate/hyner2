import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../features/customers/data/customer_rows.dart';
import '../../features/sales/data/bill_document_codec.dart';
import '../../features/sales/domain/sale_price_snapshot.dart';

/// Local register database. Inventory, customer and bill data stay on this
/// device; Firebase is not used to create or settle a sale.
class LocalBusinessDatabase {
  LocalBusinessDatabase({this.factory, this.directory});

  static final LocalBusinessDatabase instance = LocalBusinessDatabase();

  final DatabaseFactory? factory;
  final String? directory;
  final Map<String, Future<Database>> _databases = {};

  Future<Database> databaseFor(String uid) {
    if (uid.isEmpty || uid.contains('/')) {
      throw ArgumentError.value(
        uid,
        'uid',
        'A valid signed-in account is required.',
      );
    }
    return _databases.putIfAbsent(
      uid,
      () => _open(uid).catchError((Object error, StackTrace stack) {
        _databases.remove(uid);
        Error.throwWithStackTrace(error, stack);
      }),
    );
  }

  Future<void> close() async {
    final pending = _databases.values.toList();
    _databases.clear();
    for (final database in pending) {
      await (await database).close();
    }
  }

  Future<Database> _open(String uid) async {
    final factory = this.factory ?? databaseFactory;
    final directory = this.directory ?? await factory.getDatabasesPath();
    final fileKey = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
    return factory.openDatabase(
      '$directory/hyner_register_$fileKey.db',
      options: OpenDatabaseOptions(
        version: 11,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE products (
            sku TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            parameters TEXT NOT NULL DEFAULT '[]',
            pricingFormula TEXT,
            currency TEXT NOT NULL,
            costMinor INTEGER NOT NULL,
            priceMinor INTEGER NOT NULL,
            quantity INTEGER NOT NULL,
            reorderLevel INTEGER NOT NULL,
            archived INTEGER NOT NULL,
            revision INTEGER NOT NULL,
            lastMovementId TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
          await db.execute(
            'CREATE INDEX products_name ON products(name COLLATE NOCASE, sku)',
          );
          await db.execute('''
          CREATE TABLE movements (
            id TEXT NOT NULL,
            sku TEXT NOT NULL,
            type TEXT NOT NULL,
            beforeQuantity INTEGER NOT NULL,
            afterQuantity INTEGER NOT NULL,
            delta INTEGER NOT NULL,
            reason TEXT NOT NULL,
            actorUid TEXT NOT NULL,
            revision INTEGER NOT NULL,
            createdAt TEXT NOT NULL,
            PRIMARY KEY (sku, id)
          )
        ''');
          await db.execute(
            'CREATE INDEX movements_product_date ON movements(sku, createdAt DESC, id DESC)',
          );
          await db.execute('''
          CREATE TABLE customers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            identityKey TEXT,
            address TEXT NOT NULL DEFAULT '',
            notes TEXT NOT NULL,
            whatsappOptIn INTEGER NOT NULL DEFAULT 1,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
          await db.execute(
            'CREATE INDEX customers_name ON customers(name COLLATE NOCASE)',
          );
          await db.execute(
            'CREATE UNIQUE INDEX customers_identity ON customers(identityKey) WHERE identityKey IS NOT NULL',
          );
          await db.execute('''
          CREATE TABLE sales (
            id TEXT PRIMARY KEY,
            currency TEXT NOT NULL,
            lines TEXT NOT NULL,
            customerId TEXT,
            customerName TEXT,
            customerPhone TEXT,
            customerAddress TEXT,
            paymentStatus TEXT NOT NULL,
            initialPaymentMinor INTEGER NOT NULL DEFAULT 0,
            expectedPaymentMinor INTEGER NOT NULL DEFAULT 0,
            paidMinor INTEGER NOT NULL DEFAULT 0,
            payments TEXT NOT NULL DEFAULT '[]',
            followupAt TEXT,
            createdAt TEXT NOT NULL,
            paidAt TEXT
          )
        ''');
          await db.execute(
            'CREATE INDEX sales_created ON sales(createdAt DESC, id DESC)',
          );
          await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
          await _createPurchaseTables(db);
          await _createExpenseTable(db);
          await _createQuotationTable(db);
          await _createPurchaseOrderTable(db);
          await _createAccountingTable(db);
          await _createBillDocuments(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createPurchaseTables(db);
          if (oldVersion < 3) {
            await db.execute(
              "ALTER TABLE products ADD COLUMN parameters TEXT NOT NULL DEFAULT '[]'",
            );
            await db.execute(
              'ALTER TABLE sales ADD COLUMN initialPaymentMinor INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute(
              'ALTER TABLE sales ADD COLUMN expectedPaymentMinor INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute(
              'ALTER TABLE sales ADD COLUMN paidMinor INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute(
              "ALTER TABLE sales ADD COLUMN payments TEXT NOT NULL DEFAULT '[]'",
            );
            // Before v3 there was no pay-later amount. Preserve the old full
            // first payment while allowing an explicit zero on newer bills.
            for (final row in await db.query('sales')) {
              final total = _saleTotal(row);
              await db.update(
                'sales',
                {'initialPaymentMinor': total, 'expectedPaymentMinor': total},
                where: 'id = ?',
                whereArgs: [row['id']],
              );
            }
          }
          if (oldVersion < 4) {
            await db.execute(
              'ALTER TABLE customers ADD COLUMN whatsappOptIn INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute('ALTER TABLE sales ADD COLUMN followupAt TEXT');
          }
          if (oldVersion < 5) await _createExpenseTable(db);
          if (oldVersion < 6) {
            await db.execute(
              'ALTER TABLE products ADD COLUMN pricingFormula TEXT',
            );
          }
          if (oldVersion < 7) {
            await _createQuotationTable(db);
            await _createPurchaseOrderTable(db);
            await _createAccountingTable(db);
          }
          if (oldVersion < 8) {
            await db.execute('ALTER TABLE movements RENAME TO old_movements');
            await db.execute('''
            CREATE TABLE movements (
              id TEXT NOT NULL,
              sku TEXT NOT NULL,
              type TEXT NOT NULL,
              beforeQuantity INTEGER NOT NULL,
              afterQuantity INTEGER NOT NULL,
              delta INTEGER NOT NULL,
              reason TEXT NOT NULL,
              actorUid TEXT NOT NULL,
              revision INTEGER NOT NULL,
              createdAt TEXT NOT NULL,
              PRIMARY KEY (sku, id)
            )
          ''');
            await db.execute(
              'INSERT INTO movements SELECT * FROM old_movements',
            );
            await db.execute('DROP TABLE old_movements');
            await db.execute(
              'CREATE INDEX movements_product_date ON movements(sku, createdAt DESC, id DESC)',
            );
          }
          if (oldVersion < 9) {
            await db.execute(
              "ALTER TABLE customers ADD COLUMN address TEXT NOT NULL DEFAULT ''",
            );
            await db.execute(
              'ALTER TABLE sales ADD COLUMN customerAddress TEXT',
            );
          }
          if (oldVersion < 10) {
            await db.execute(
              'ALTER TABLE customers ADD COLUMN identityKey TEXT',
            );
            await db.execute(
              'CREATE UNIQUE INDEX customers_identity ON customers(identityKey) WHERE identityKey IS NOT NULL',
            );
            await _createBillDocuments(db);
            await repairCustomerLinks(db);
          }
          if (oldVersion < 11) {
            await db.update('customers', {'whatsappOptIn': 1});
          }
        },
      ),
    );
  }

  /// Creates a portable, human-readable snapshot for manual backup. The
  /// snapshot is intentionally exported through the OS share sheet; it is not
  /// uploaded automatically and never contains authentication tokens.
  Future<Map<String, dynamic>> exportFor(String uid) async {
    final db = await databaseFor(uid);
    final tables = <String>[
      'products',
      'movements',
      'customers',
      'sales',
      'settings',
      'suppliers',
      'purchases',
      'purchase_returns',
      'operating_expenses',
      'quotations',
      'purchase_orders',
      'accounting_entries',
      'bill_documents',
    ];
    final records = await db.transaction((tx) async {
      final records = <String, List<Map<String, Object?>>>{};
      for (final table in tables) {
        final rows = await tx.query(table);
        if (table == 'bill_documents') {
          records[table] = [for (final row in rows) _exportBillDocument(row)];
        } else {
          records[table] = rows;
        }
      }
      return records;
    });
    return {
      'format': 'hyner-local-backup',
      'version': 2,
      // v11 changes defaults only; the portable table format remains v10.
      'schemaVersion': 10,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'accountUid': uid,
      'tables': records,
    };
  }

  Future<void> restoreFor(String uid, Map<String, dynamic> snapshot) async {
    final version = snapshot['version'];
    if (snapshot['format'] != 'hyner-local-backup' ||
        (version != 1 && version != 2) ||
        (version == 2 &&
            snapshot['schemaVersion'] != 8 &&
            snapshot['schemaVersion'] != 9 &&
            snapshot['schemaVersion'] != 10)) {
      throw const FormatException('This is not a supported Hyner backup.');
    }
    if (snapshot['accountUid'] != uid) {
      throw const FormatException(
        'This backup belongs to a different account.',
      );
    }
    final rawTables = snapshot['tables'];
    if (rawTables is! Map) {
      throw const FormatException('The backup does not contain business data.');
    }
    final db = await databaseFor(uid);
    const tables = [
      'bill_documents',
      'operating_expenses',
      'quotations',
      'purchase_orders',
      'accounting_entries',
      'purchase_returns',
      'purchases',
      'suppliers',
      'sales',
      'settings',
      'customers',
      'movements',
      'products',
    ];
    // v1 backups predate some modules. Core tables were always required;
    // present tables must never be silently skipped because of a bad type.
    final requiredTables = version == 2
        ? tables
              .where(
                (t) => t != 'bill_documents' || snapshot['schemaVersion'] == 10,
              )
              .toList()
        : const ['products', 'movements', 'customers', 'sales', 'settings'];
    if (requiredTables.any((table) => rawTables[table] is! List) ||
        rawTables.entries.any(
          (entry) => !tables.contains(entry.key) || entry.value is! List,
        )) {
      throw const FormatException(
        'The backup contains missing or invalid tables.',
      );
    }
    await db.transaction((tx) async {
      for (final table in tables) {
        await tx.delete(table);
      }
      for (final table in tables.reversed) {
        final rows = rawTables[table];
        if (rows is! List) continue;
        for (final row in rows) {
          if (row is! Map) {
            throw const FormatException('The backup contains an invalid row.');
          }
          final values = Map<String, Object?>.from(row);
          if (table == 'bill_documents') {
            final encoded = values['duplicatePdf'];
            if (encoded is! String || encoded.length > 8 * 1024 * 1024) {
              throw const FormatException('Invalid archived PDF.');
            }
            final bytes = base64Decode(encoded);
            BillDocumentCodec.decodePdf(bytes, encoding: values['encoding']);
            values['encoding'] ??= 'pdf';
            values['duplicatePdf'] = bytes;
          }
          if (table == 'customers') values['identityKey'] = null;
          if (table == 'sales' && !values.containsKey('initialPaymentMinor')) {
            final total = _saleTotal(values);
            values['initialPaymentMinor'] = total;
            values['expectedPaymentMinor'] = total;
          }
          await tx.insert(table, values);
        }
      }
      await repairCustomerLinks(tx);
    });
  }
}

Future<void> _createBillDocuments(DatabaseExecutor db) => db.execute('''
  CREATE TABLE bill_documents (
    saleId TEXT PRIMARY KEY,
    duplicatePdf BLOB NOT NULL,
    encoding TEXT NOT NULL DEFAULT 'pdf',
    createdAt TEXT NOT NULL,
    FOREIGN KEY (saleId) REFERENCES sales(id) ON DELETE CASCADE
  )
''');

Map<String, Object?> _exportBillDocument(Map<String, Object?> row) {
  final bytes = row['duplicatePdf']! as List<int>;
  BillDocumentCodec.decodePdf(bytes, encoding: row['encoding']);
  return {...row, 'duplicatePdf': base64Encode(bytes)};
}

int _saleTotal(Map<String, Object?> row) {
  if (row['lines'] is! String) {
    throw const FormatException('The backup contains an invalid bill.');
  }
  final decoded = jsonDecode(row['lines']! as String);
  if (decoded is! List ||
      decoded.any(
        (line) =>
            line is! Map ||
            line['unitPriceMinor'] is! int ||
            line['quantity'] is! int,
      )) {
    throw const FormatException('The backup contains invalid bill lines.');
  }
  var total = 0;
  for (final line in decoded) {
    final rawPricing = line['pricing'];
    if (rawPricing == null) {
      total += (line['unitPriceMinor'] as int) * (line['quantity'] as int);
      continue;
    }
    final pricing = SalePriceSnapshot.fromJson(
      Map<String, dynamic>.from(rawPricing as Map),
    );
    if (pricing.quantity != line['quantity'] ||
        pricing.unitPriceMinor != line['unitPriceMinor'] ||
        pricing.currency != row['currency'] ||
        line['unitCostMinor'] != 0) {
      throw const FormatException(
        'The backup contains an invalid custom bill.',
      );
    }
    total += pricing.totalMinor;
  }
  return total;
}

Future<void> _createExpenseTable(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE operating_expenses (
      id TEXT PRIMARY KEY,
      category TEXT NOT NULL,
      description TEXT NOT NULL,
      currency TEXT NOT NULL,
      amountMinor INTEGER NOT NULL,
      occurredAt TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX operating_expenses_date ON operating_expenses(currency, occurredAt DESC, id)',
  );
}

Future<void> _createPurchaseTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE suppliers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      notes TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX suppliers_name ON suppliers(name COLLATE NOCASE)',
  );
  await db.execute('''
    CREATE TABLE purchases (
      id TEXT PRIMARY KEY,
      supplierId TEXT,
      supplierName TEXT,
      supplierPhone TEXT,
      currency TEXT NOT NULL,
      items TEXT NOT NULL,
      returnedItems TEXT NOT NULL DEFAULT '{}',
      paymentStatus TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      paidAt TEXT
    )
  ''');
  await db.execute(
    'CREATE INDEX purchases_created ON purchases(createdAt DESC, id DESC)',
  );
  await db.execute('''
    CREATE TABLE purchase_returns (
      id TEXT PRIMARY KEY,
      purchaseId TEXT NOT NULL,
      items TEXT NOT NULL,
      totalMinor INTEGER NOT NULL,
      reason TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX purchase_returns_purchase ON purchase_returns(purchaseId, createdAt DESC)',
  );
}

Future<void> _createQuotationTable(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE quotations (
      id TEXT PRIMARY KEY,
      customerName TEXT NOT NULL,
      customerPhone TEXT NOT NULL,
      currency TEXT NOT NULL,
      description TEXT NOT NULL,
      subtotalMinor INTEGER NOT NULL,
      taxRateBasisPoints INTEGER NOT NULL DEFAULT 0,
      taxMinor INTEGER NOT NULL DEFAULT 0,
      totalMinor INTEGER NOT NULL,
      status TEXT NOT NULL,
      validUntil TEXT,
      createdAt TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX quotations_created ON quotations(createdAt DESC, id DESC)',
  );
}

Future<void> _createPurchaseOrderTable(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE purchase_orders (
      id TEXT PRIMARY KEY,
      supplierName TEXT NOT NULL,
      supplierPhone TEXT NOT NULL,
      currency TEXT NOT NULL,
      description TEXT NOT NULL,
      totalMinor INTEGER NOT NULL,
      status TEXT NOT NULL,
      expectedAt TEXT,
      createdAt TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX purchase_orders_created ON purchase_orders(createdAt DESC, id DESC)',
  );
}

Future<void> _createAccountingTable(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE accounting_entries (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      category TEXT NOT NULL,
      description TEXT NOT NULL,
      currency TEXT NOT NULL,
      amountMinor INTEGER NOT NULL,
      taxMinor INTEGER NOT NULL DEFAULT 0,
      createdAt TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX accounting_entries_created ON accounting_entries(currency, createdAt DESC, id DESC)',
  );
}
