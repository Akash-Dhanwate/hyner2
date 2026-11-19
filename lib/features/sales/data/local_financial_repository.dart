import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/local_business_database.dart';
import '../../inventory/domain/product.dart';
import '../domain/sale.dart';
import 'local_sales_repository.dart';

const paymentMethods = ['cash', 'upi', 'bank', 'card', 'other'];

class FinancialEntry {
  FinancialEntry(Map<String, Object?> row)
    : id = row['id']! as String,
      amountMinor = row['amountMinor']! as int,
      kind = row['kind']! as String,
      method = row['method']! as String,
      note = row['note']! as String,
      date = DateTime.parse(row['effectiveAt']! as String),
      reversesId = row['reversesId'] as String?;
  final String id, kind, method, note;
  final int amountMinor;
  final DateTime date;
  final String? reversesId;
}

class DocumentBalance {
  const DocumentBalance(this.totalMinor, this.creditMinor, this.paidMinor);
  final int totalMinor, creditMinor, paidMinor;
  int get netMinor => totalMinor - creditMinor;
  int get dueMinor => (netMinor - paidMinor).clamp(0, maxMoneyMinor);
  int get refundDueMinor => (paidMinor - netMinor).clamp(0, maxMoneyMinor);
}

/// Financial corrections append records; original bill lines are immutable.
class LocalFinancialRepository {
  LocalFinancialRepository(this.store, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final LocalBusinessDatabase store;
  final DateTime Function() clock;

  Future<List<FinancialEntry>> entries(
    String uid,
    String type,
    String id,
  ) async {
    final db = await store.databaseFor(uid);
    return (await db.query(
      'financial_entries',
      where: 'documentType = ? AND documentId = ?',
      whereArgs: [type, id],
      orderBy: 'effectiveAt,id',
    )).map(FinancialEntry.new).toList();
  }

  Future<List<Map<String, Object?>>> returns(String uid, String id) async =>
      (await store.databaseFor(uid)).query(
        'sale_returns',
        where: 'saleId = ?',
        whereArgs: [id],
        orderBy: 'createdAt,id',
      );

  Future<DocumentBalance> balance(String uid, String type, String id) async =>
      (await store.databaseFor(uid))
          .transaction((tx) => _balance(tx, type, id));

  Future<DocumentBalance> _balance(
    DatabaseExecutor tx,
    String type,
    String id,
  ) async {
    if (type != 'sale' && type != 'purchase') throw ArgumentError.value(type);
    final row = await _document(tx, type, id);
    final lines =
        jsonDecode(row[type == 'sale' ? 'lines' : 'items']! as String) as List;
    final total = type == 'sale'
        ? decodeLocalSale(row).draft.totalMinor
        : lines.fold<int>(
            0,
            (sum, line) =>
                sum +
                (line['unitCostMinor'] as int) * (line['quantity'] as int),
          );
    final credit = type == 'sale'
        ? row['creditMinor'] as int? ?? 0
        : (await tx.rawQuery(
                'SELECT COALESCE(SUM(totalMinor),0) AS n FROM purchase_returns WHERE purchaseId = ?',
                [id],
              )).single['n']!
              as int;
    final paid =
        (await tx.rawQuery(
              'SELECT COALESCE(SUM(amountMinor),0) AS n FROM financial_entries WHERE documentType = ? AND documentId = ?',
              [type, id],
            )).single['n']!
            as int;
    return DocumentBalance(total, credit, paid);
  }

  Future<Map<String, Object?>> _document(
    DatabaseExecutor tx,
    String type,
    String id,
  ) async {
    final rows = await tx.query(
      type == 'sale' ? 'sales' : 'purchases',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw inventoryInvalid(
        'This document is no longer available. Refresh the screen.',
      );
    }
    return rows.single;
  }

  void _validate(
    String operationId,
    DateTime date,
    String method,
    String note,
  ) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(operationId) ||
        !paymentMethods.contains(method) ||
        note.trim().length > 500 ||
        date.toUtc().isAfter(clock().toUtc().add(const Duration(minutes: 1))) ||
        date.year < 2000) {
      throw inventoryInvalid(
        'Enter a valid payment date, method and reference. Future payments cannot be recorded.',
      );
    }
  }

  Future<void> recordPayment(
    String uid,
    String type,
    String id,
    int amountMinor, {
    required String operationId,
    required DateTime date,
    String method = 'cash',
    String note = '',
    bool refund = false,
    bool matchDate = true,
  }) async {
    _validate(operationId, date, method, note);
    if (amountMinor < 1 || amountMinor > maxMoneyMinor) {
      throw inventoryInvalid('Enter a positive payment amount.');
    }
    final db = await store.databaseFor(uid);
    await db.transaction((tx) async {
      final signed = refund ? -amountMinor : amountMinor;
      final prior = await tx.query(
        'financial_entries',
        where: 'id = ?',
        whereArgs: [operationId],
      );
      if (prior.isNotEmpty) {
        final row = prior.single;
        if (row['documentId'] != id ||
            row['documentType'] != type ||
            row['amountMinor'] != signed ||
            row['method'] != method ||
            row['note'] != note.trim() ||
            matchDate && row['effectiveAt'] != date.toUtc().toIso8601String()) {
          throw inventoryInvalid(
            'This payment reference already has different details.',
          );
        }
        return;
      }
      final doc = await _document(tx, type, id);
      if (!refund && doc['billState'] == 'void') {
        throw inventoryInvalid('A void bill cannot receive payments.');
      }
      final current = await _balance(tx, type, id);
      if (amountMinor > (refund ? current.refundDueMinor : current.dueMinor)) {
        throw inventoryInvalid(
          refund
              ? 'The refund exceeds the credit available.'
              : 'The payment exceeds the outstanding balance.',
        );
      }
      await tx.insert('financial_entries', {
        'id': operationId,
        'documentType': type,
        'documentId': id,
        'amountMinor': signed,
        'kind': refund ? 'refund' : 'payment',
        'method': method,
        'note': note.trim(),
        'effectiveAt': date.toUtc().toIso8601String(),
        'recordedAt': clock().toUtc().toIso8601String(),
      });
      await _refresh(tx, type, id);
    });
  }

  Future<void> reversePayment(
    String uid,
    String entryId, {
    required String operationId,
    required String reason,
    required DateTime date,
  }) async {
    _validate(operationId, date, 'other', reason);
    if (reason.trim().isEmpty) {
      throw inventoryInvalid('Enter a reason for the correction.');
    }
    final db = await store.databaseFor(uid);
    await db.transaction((tx) async {
      final previous = await tx.query(
        'financial_entries',
        where: 'reversesId = ?',
        whereArgs: [entryId],
      );
      if (previous.isNotEmpty) {
        if (previous.single['id'] != operationId ||
            previous.single['note'] != reason.trim()) {
          throw inventoryInvalid('This entry has already been reversed.');
        }
        return;
      }
      final rows = await tx.query(
        'financial_entries',
        where: 'id = ?',
        whereArgs: [entryId],
      );
      if (rows.isEmpty || rows.single['kind'] == 'reversal') {
        throw inventoryInvalid('Choose an original payment or refund.');
      }
      final entry = rows.single;
      final type = entry['documentType']! as String;
      final id = entry['documentId']! as String;
      final before = await _balance(tx, type, id);
      final signed = -(entry['amountMinor']! as int);
      if (before.paidMinor + signed < 0) {
        throw inventoryInvalid(
          'Reverse the associated refund first; it already used this payment.',
        );
      }
      await tx.insert('financial_entries', {
        'id': operationId,
        'documentType': type,
        'documentId': id,
        'amountMinor': signed,
        'kind': 'reversal',
        'method': entry['method'],
        'note': reason.trim(),
        'effectiveAt': date.toUtc().toIso8601String(),
        'recordedAt': clock().toUtc().toIso8601String(),
        'reversesId': entryId,
      });
      await _refresh(tx, type, id);
    });
  }

  Future<void> _refresh(DatabaseExecutor tx, String type, String id) async {
    final current = await _balance(tx, type, id);
    final history = await tx.query(
      'financial_entries',
      where: 'documentType = ? AND documentId = ?',
      whereArgs: [type, id],
      orderBy: 'effectiveAt,id',
    );
    final paidAt = current.dueMinor == 0 && history.isNotEmpty
        ? history.last['effectiveAt']
        : null;
    if (type == 'sale') {
      await tx.update(
        'sales',
        {
          'paidMinor': current.paidMinor,
          'expectedPaymentMinor': current.dueMinor,
          'paymentStatus': current.dueMinor == 0
              ? 'paid'
              : current.paidMinor > 0
              ? 'partial'
              : 'unpaid',
          'paidAt': paidAt,
          'payments': jsonEncode([
            for (final e in history)
              {
                'amountMinor': e['amountMinor'],
                'createdAt': e['effectiveAt'],
                'operationId': e['id'],
              },
          ]),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await tx.update(
        'purchases',
        {
          'paymentStatus': current.dueMinor == 0 ? 'paid' : 'unpaid',
          'paidAt': paidAt,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Credit is allocated cumulatively, so repeated partial returns sum exactly
  /// to the immutable gross/tax/cost snapshots, including rounded measured items.
  Future<void> recordReturn(
    String uid,
    Sale expected,
    Map<String, int> quantities, {
    required String operationId,
    required String reason,
    required bool restock,
  }) async {
    _validate(operationId, clock(), 'other', reason);
    if (reason.trim().isEmpty ||
        quantities.isEmpty ||
        quantities.values.any((q) => q < 1)) {
      throw inventoryInvalid('Choose quantities and enter a return reason.');
    }
    final db = await store.databaseFor(uid);
    await db.transaction((tx) async {
      final prior = await tx.query(
        'sale_returns',
        where: 'id = ?',
        whereArgs: [operationId],
      );
      if (prior.isNotEmpty) {
        final saved = jsonDecode(prior.single['items']! as String) as List;
        final same =
            saved.length == quantities.length &&
            saved.every((line) => quantities[line['sku']] == line['quantity']);
        if (prior.single['saleId'] != expected.id ||
            prior.single['reason'] != reason.trim() ||
            prior.single['restock'] != (restock ? 1 : 0) ||
            !same) {
          throw inventoryInvalid(
            'This return reference already has different details.',
          );
        }
        return;
      }
      final row = await _document(tx, 'sale', expected.id);
      if (row['billState'] == 'void') {
        throw inventoryInvalid('This bill has already been voided.');
      }
      final history = await tx.query(
        'sale_returns',
        where: 'saleId = ?',
        whereArgs: [expected.id],
      );
      final returned = <String, int>{};
      for (final record in history) {
        for (final line in jsonDecode(record['items']! as String) as List) {
          returned[line['sku'] as String] =
              (returned[line['sku']] ?? 0) + (line['quantity'] as int);
        }
      }
      // Read inside the transaction; never trust caller prices or stock links.
      final saved = decodeLocalSale(row);
      if (quantities.keys.any(
        (sku) => !saved.draft.lines.any((l) => l.sku == sku),
      )) {
        throw inventoryInvalid('Choose items from this bill.');
      }
      var total = 0, tax = 0, cost = 0;
      final items = <Map<String, Object?>>[];
      for (var index = 0; index < saved.draft.lines.length; index++) {
        final line = saved.draft.lines[index];
        final q = quantities[line.sku] ?? 0;
        if (q == 0) continue;
        final before = returned[line.sku] ?? 0;
        if (before + q > line.quantity) {
          throw inventoryInvalid(
            'Return quantity exceeds remaining ${line.name}.',
          );
        }
        int allocation(int amount) =>
            ((BigInt.from(amount) *
                        BigInt.from(before + q) ~/
                        BigInt.from(line.quantity)) -
                    (BigInt.from(amount) *
                        BigInt.from(before) ~/
                        BigInt.from(line.quantity)))
                .toInt();
        final gross = allocation(line.totalMinor),
            lineTax = allocation(line.pricing?.taxMinor ?? 0),
            lineCost = allocation(line.totalCostMinor);
        total += gross;
        tax += lineTax;
        cost += lineCost;
        items.add({
          'sku': line.sku,
          'name': line.name,
          'quantity': q,
          'totalMinor': gross,
          'taxMinor': lineTax,
          'costMinor': lineCost,
        });
        if (restock && line.stockTracked) {
          await _restoreStock(
            tx,
            uid,
            line.stockSku!,
            q,
            'return_${operationId}_$index',
            reason,
          );
        }
      }
      if (!restock && cost > 0) {
        final now = clock().toUtc().toIso8601String();
        await tx.insert('operating_expenses', {
          'id': 'return_loss_$operationId',
          'category': 'Other',
          'description': 'Non-restocked return on bill ${saved.reference}',
          'currency': saved.draft.currency,
          'amountMinor': cost,
          'occurredAt': now,
          'createdAt': now,
        });
      }
      await tx.insert('sale_returns', {
        'id': operationId,
        'saleId': saved.id,
        'items': jsonEncode(items),
        'totalMinor': total,
        'taxMinor': tax,
        'costMinor': cost,
        'reason': reason.trim(),
        'restock': restock ? 1 : 0,
        'createdAt': clock().toUtc().toIso8601String(),
      });
      await tx.update(
        'sales',
        {'creditMinor': (row['creditMinor'] as int? ?? 0) + total},
        where: 'id = ?',
        whereArgs: [saved.id],
      );
      await _refresh(tx, 'sale', saved.id);
    });
  }

  Future<void> voidBill(
    String uid,
    String id, {
    required String reason,
    required int expectedPaidMinor,
  }) async {
    if (reason.trim().isEmpty || reason.trim().length > 500) {
      throw inventoryInvalid('Enter a reason for voiding this bill.');
    }
    final db = await store.databaseFor(uid);
    await db.transaction((tx) async {
      final row = await _document(tx, 'sale', id);
      if (row['billState'] == 'void') return;
      final sale = decodeLocalSale(row);
      if (sale.paidMinor != expectedPaidMinor) {
        throw inventoryInvalid(
          'Payments changed. Reopen the bill before voiding it.',
        );
      }
      final returns = await tx.query(
        'sale_returns',
        where: 'saleId = ?',
        whereArgs: [id],
      );
      final returned = <String, int>{};
      for (final record in returns) {
        for (final line in jsonDecode(record['items']! as String) as List) {
          returned[line['sku'] as String] =
              (returned[line['sku']] ?? 0) + (line['quantity'] as int);
        }
      }
      for (var index = 0; index < sale.draft.lines.length; index++) {
        final line = sale.draft.lines[index];
        final q = line.quantity - (returned[line.sku] ?? 0);
        if (q > 0 && line.stockTracked) {
          await _restoreStock(
            tx,
            uid,
            line.stockSku!,
            q,
            'void_${id}_$index',
            reason,
          );
        }
      }
      await tx.update(
        'sales',
        {
          'billState': 'void',
          'voidReason': reason.trim(),
          'voidedAt': clock().toUtc().toIso8601String(),
          'creditMinor': sale.draft.totalMinor,
          'followupAt': null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _refresh(tx, 'sale', id);
    });
  }

  Future<void> linkReplacement(
    String uid,
    String originalId,
    String replacementId,
  ) async {
    final db = await store.databaseFor(uid);
    await db.transaction((tx) async {
      final original = await _document(tx, 'sale', originalId);
      final replacement = await _document(tx, 'sale', replacementId);
      if (originalId == replacementId ||
          original['billState'] != 'void' ||
          replacement['billState'] != 'active' ||
          replacement['currency'] != original['currency']) {
        throw inventoryInvalid(
          'Choose an active replacement bill in the same currency for a void original.',
        );
      }
      final existing = await tx.query(
        'sales',
        where: 'replacesSaleId = ?',
        whereArgs: [originalId],
      );
      if (existing.any((row) => row['id'] != replacementId) ||
          replacement['replacesSaleId'] != null &&
              replacement['replacesSaleId'] != originalId) {
        throw inventoryInvalid('A replacement is already linked.');
      }
      await tx.update(
        'sales',
        {'replacesSaleId': originalId},
        where: 'id = ?',
        whereArgs: [replacementId],
      );
    });
  }

  Future<void> _restoreStock(
    DatabaseExecutor tx,
    String uid,
    String sku,
    int quantity,
    String movementId,
    String reason,
  ) async {
    final rows = await tx.query('products', where: 'sku = ?', whereArgs: [sku]);
    if (rows.isEmpty) {
      throw inventoryInvalid(
        'The linked product is missing. Restore the product before returning stock.',
      );
    }
    final product = rows.single;
    final before = product['quantity']! as int,
        after = before + quantity,
        revision = (product['revision']! as int) + 1;
    if (after > maxStock || revision > maxStock) {
      throw inventoryInvalid(
        'The returned stock exceeds the supported quantity.',
      );
    }
    final now = clock().toUtc().toIso8601String();
    await tx.update(
      'products',
      {
        'quantity': after,
        'archived': 0,
        'revision': revision,
        'lastMovementId': movementId,
        'updatedAt': now,
      },
      where: 'sku = ?',
      whereArgs: [sku],
    );
    await tx.insert('movements', {
      'id': movementId,
      'sku': sku,
      'type': 'return',
      'beforeQuantity': before,
      'afterQuantity': after,
      'delta': quantity,
      'reason': reason.trim(),
      'actorUid': uid,
      'revision': revision,
      'createdAt': now,
    });
  }
}
