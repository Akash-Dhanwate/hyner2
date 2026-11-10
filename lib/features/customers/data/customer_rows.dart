import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../domain/customer.dart';

Customer customerFromRow(Map<String, Object?> row) => Customer(
  id: row['id']! as String,
  name: row['name']! as String,
  phone: row['phone']! as String,
  notes: row['notes']! as String,
  address: row['address'] as String? ?? '',
  whatsappOptIn: row['whatsappOptIn'] == 1,
  createdAt: DateTime.parse(row['createdAt']! as String),
  updatedAt: DateTime.parse(row['updatedAt']! as String),
);

/// Used by directory edits and checkout inside their caller's transaction.
/// Matching an existing person never rewrites their contact/consent from a bill.
Future<Customer> saveCustomerRow(
  DatabaseExecutor db,
  CustomerDraft draft, {
  String? id,
  bool checkout = false,
  DateTime? at,
}) async {
  draft.validate();
  final key = customerIdentityKey(draft.name, draft.phone);
  final matches = key == null
      ? <Map<String, Object?>>[]
      : await db.query(
          'customers',
          where: 'identityKey = ?',
          whereArgs: [key],
          limit: 1,
        );
  if (id == null && matches.isNotEmpty) return customerFromRow(matches.single);
  final prior = id == null
      ? <Map<String, Object?>>[]
      : await db.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
  if (checkout && id != null && prior.isEmpty) {
    throw const FormatException(
      'This customer is unavailable. Refresh the customer list before saving.',
    );
  }
  final now = (at ?? DateTime.now()).toUtc();
  final old = prior.isEmpty ? null : customerFromRow(prior.single);
  final random = Random.secure();
  final token = List.generate(
    16,
    (_) => random.nextInt(16).toRadixString(16),
  ).join();
  final customerId = id ?? customerReference(draft.name, draft.phone, token);
  final name = checkout && old != null ? old.name : draft.name.trim();
  final phone = checkout && old != null && validCustomerMobile(old.phone)
      ? old.phone
      : draft.phone.trim();
  final address = checkout && old != null && old.address.isNotEmpty
      ? old.address
      : draft.address.trim();
  var identity = customerIdentityKey(name, phone);
  if (matches.isNotEmpty && matches.single['id'] != customerId) {
    if (old != null && customerIdentityKey(old.name, old.phone) == identity) {
      identity =
          null; // Preserve an existing legacy duplicate without merging it.
    } else {
      throw const FormatException(
        'This name and mobile number already belong to another customer. Choose that customer.',
      );
    }
  }
  final values = <String, Object?>{
    'id': customerId,
    'name': name,
    'phone': phone,
    'address': address,
    'notes': checkout && old != null ? old.notes : draft.notes.trim(),
    'whatsappOptIn':
        (checkout && old != null ? old.whatsappOptIn : draft.whatsappOptIn)
        ? 1
        : 0,
    'identityKey': identity,
    'createdAt': (old?.createdAt ?? now).toIso8601String(),
    'updatedAt':
        (old != null && now.isBefore(old.createdAt) ? old.updatedAt : now)
            .toIso8601String(),
  };
  if (old == null) {
    await db.insert('customers', values);
  } else {
    await db.update(
      'customers',
      values,
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }
  return customerFromRow(values);
}

/// Keeps existing IDs/links; only unlinked historical contacts are connected.
Future<void> repairCustomerLinks(DatabaseExecutor db) async {
  await db.update('customers', {'identityKey': null});
  String? createdCursor, customerCursor;
  while (true) {
    final customers = await db.query(
      'customers',
      where: createdCursor == null
          ? null
          : 'createdAt > ? OR (createdAt = ? AND id > ?)',
      whereArgs: createdCursor == null
          ? null
          : [createdCursor, createdCursor, customerCursor],
      orderBy: 'createdAt, id',
      limit: 100,
    );
    for (final row in customers) {
      final key = customerIdentityKey(
        row['name']! as String,
        row['phone']! as String,
      );
      if (key == null) continue;
      final canonical = await db.query(
        'customers',
        columns: ['id'],
        where: 'identityKey = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (canonical.isEmpty) {
        await db.update(
          'customers',
          {'identityKey': key},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
    if (customers.length < 100) break;
    createdCursor = customers.last['createdAt']! as String;
    customerCursor = customers.last['id']! as String;
  }
  // Cursor pages prevent a growing register from being materialized at once.
  var cursor = '';
  while (true) {
    final rows = await db.query(
      'sales',
      where: 'customerId IS NULL AND id > ?',
      whereArgs: [cursor],
      orderBy: 'id',
      limit: 100,
    );
    for (final row in rows) {
      final name = row['customerName'] as String? ?? '';
      final phone = row['customerPhone'] as String? ?? '';
      final address = row['customerAddress'] as String? ?? '';
      if (customerIdentityKey(name, phone) == null ||
          name.trim().length > 120 ||
          phone.length > 40 ||
          address.length > 240) {
        continue;
      }
      final person = await saveCustomerRow(
        db,
        CustomerDraft(name: name.trim(), phone: phone, address: address),
        checkout: true,
        at: DateTime.parse(row['createdAt']! as String),
      );
      await db.update(
        'sales',
        {'customerId': person.id},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    if (rows.length < 100) break;
    cursor = rows.last['id']! as String;
  }
}
