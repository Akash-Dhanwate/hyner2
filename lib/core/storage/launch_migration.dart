import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../features/sales/domain/sale_price_snapshot.dart';

/// Additive launch migration. Numbers belong to a workspace and are never reused.
Future<void> installLaunchSchema(DatabaseExecutor db) async {
  final columns = await db.rawQuery('PRAGMA table_info(sales)');
  for (final entry in {
    'billNumber': 'INTEGER',
    'billState': "TEXT NOT NULL DEFAULT 'active'",
    'creditMinor': 'INTEGER NOT NULL DEFAULT 0',
    'voidReason': 'TEXT',
    'voidedAt': 'TEXT',
    'replacesSaleId': 'TEXT',
  }.entries) {
    if (!columns.any((column) => column['name'] == entry.key)) {
      await db.execute(
        'ALTER TABLE sales ADD COLUMN ${entry.key} ${entry.value}',
      );
    }
  }
  if (!columns.any((column) => column['name'] == 'billNumber')) {
    for (final row in await db.query(
      'sales',
      where: "paymentStatus = 'paid' AND paidMinor = 0",
    )) {
      final lines = jsonDecode(row['lines']! as String) as List;
      final total = lines.fold<int>(
        0,
        (sum, line) =>
            sum +
            (line['pricing'] != null
                ? SalePriceSnapshot.fromJson(
                    Map<String, dynamic>.from(line['pricing'] as Map),
                  ).totalMinor
                : (line['quantity'] as int) * (line['unitPriceMinor'] as int)),
      );
      await db.update(
        'sales',
        {'paidMinor': total, 'expectedPaymentMinor': 0},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }
  await ensureBillNumbers(db);
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS sales_bill_number ON sales(billNumber)',
  );
  await db.execute('''CREATE TABLE IF NOT EXISTS financial_entries (
    id TEXT PRIMARY KEY, documentType TEXT NOT NULL,
    documentId TEXT NOT NULL, amountMinor INTEGER NOT NULL,
    kind TEXT NOT NULL, method TEXT NOT NULL, note TEXT NOT NULL,
    effectiveAt TEXT NOT NULL, recordedAt TEXT NOT NULL, reversesId TEXT,
    UNIQUE(reversesId)
  )''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS financial_document ON financial_entries(documentType,documentId,effectiveAt,id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS financial_date ON financial_entries(effectiveAt,documentType)',
  );
  await db.execute('''CREATE TABLE IF NOT EXISTS sale_returns (
    id TEXT PRIMARY KEY, saleId TEXT NOT NULL REFERENCES sales(id),
    items TEXT NOT NULL, totalMinor INTEGER NOT NULL, taxMinor INTEGER NOT NULL,
    costMinor INTEGER NOT NULL, reason TEXT NOT NULL, restock INTEGER NOT NULL,
    createdAt TEXT NOT NULL
  )''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS sale_returns_sale ON sale_returns(saleId,createdAt,id)',
  );
  // Migrate receipts without inventing payment dates or methods. Keep originals.
  for (final row in await db.query('sales')) {
    if ((await db.query(
      'financial_entries',
      columns: ['id'],
      where: 'documentType = ? AND documentId = ?',
      whereArgs: ['sale', row['id']],
      limit: 1,
    )).isNotEmpty) {
      continue;
    }
    final payments = jsonDecode(row['payments'] as String? ?? '[]') as List;
    var sum = 0;
    for (var i = 0; i < payments.length; i++) {
      final payment = payments[i] as Map;
      final amount = payment['amountMinor'] as int;
      sum += amount;
      await db.insert('financial_entries', {
        'id': 'legacy-sale-${row['id']}-$i',
        'documentType': 'sale',
        'documentId': row['id'],
        'amountMinor': amount,
        'kind': 'payment',
        'method': 'legacy',
        'note': 'Imported historical payment',
        'effectiveAt': payment['createdAt'],
        'recordedAt': payment['createdAt'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final paid = row['paidMinor'] as int? ?? 0;
    if (paid > sum) {
      await db.insert('financial_entries', {
        'id': 'legacy-sale-${row['id']}-balance',
        'documentType': 'sale',
        'documentId': row['id'],
        'amountMinor': paid - sum,
        'kind': row['paidAt'] == null ? 'opening_balance' : 'payment',
        'method': 'legacy',
        'note': row['paidAt'] == null
            ? 'Historical paid balance; receipt date unknown'
            : 'Historical paid balance',
        'effectiveAt': row['paidAt'] ?? row['createdAt'],
        'recordedAt': row['createdAt'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
  for (final row in await db.query(
    'purchases',
    where: "paymentStatus = 'paid'",
  )) {
    if ((await db.query(
      'financial_entries',
      columns: ['id'],
      where: 'documentType = ? AND documentId = ?',
      whereArgs: ['purchase', row['id']],
      limit: 1,
    )).isNotEmpty) {
      continue;
    }
    final lines = jsonDecode(row['items']! as String) as List;
    final total = lines.fold<int>(
      0,
      (sum, line) =>
          sum + (line['quantity'] as int) * (line['unitCostMinor'] as int),
    );
    await db.insert('financial_entries', {
      'id': 'legacy-purchase-${row['id']}',
      'documentType': 'purchase',
      'documentId': row['id'],
      'amountMinor': total,
      'kind': row['paidAt'] == null ? 'opening_balance' : 'payment',
      'method': 'legacy',
      'note': 'Imported historical supplier payment',
      'effectiveAt': row['paidAt'] ?? row['createdAt'],
      'recordedAt': row['createdAt'],
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}

Future<void> ensureBillNumbers(DatabaseExecutor db) async {
  var high =
      (await db.rawQuery('SELECT COALESCE(MAX(billNumber),0) AS n FROM sales'))
              .single['n']
          as int;
  final counters = await db.query(
    'settings',
    where: 'key = ?',
    whereArgs: ['bill-sequence'],
  );
  final stored = counters.isEmpty
      ? 0
      : int.tryParse(counters.single['value']! as String) ?? 0;
  if (stored > high) high = stored;
  for (final row in await db.query(
    'sales',
    columns: ['id'],
    where: 'billNumber IS NULL',
    orderBy: 'createdAt,id',
  )) {
    await db.update(
      'sales',
      {'billNumber': ++high},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }
  if (high == 0 && counters.isEmpty) return;
  await db.insert('settings', {
    'key': 'bill-sequence',
    'value': '$high',
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

Future<int> nextBillNumber(DatabaseExecutor db) async {
  await ensureBillNumbers(db);
  final rows = await db.query(
    'settings',
    where: 'key = ?',
    whereArgs: ['bill-sequence'],
  );
  final next =
      (rows.isEmpty ? 0 : int.parse(rows.single['value']! as String)) + 1;
  await db.insert('settings', {
    'key': 'bill-sequence',
    'value': '$next',
  }, conflictAlgorithm: ConflictAlgorithm.replace);
  return next;
}
