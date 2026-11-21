import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/local_business_database.dart';
import '../domain/sale.dart';
import 'sale_draft_codec.dart';

class LocalSaleDraftRepository {
  LocalSaleDraftRepository(this.store);
  final LocalBusinessDatabase store;

  Future<List<Map<String, Object?>>> list(String uid) async =>
      (await store.databaseFor(uid))
          .query('sale_drafts', orderBy: 'updatedAt DESC');

  Future<void> save(String uid, String id, SaleDraft draft) async {
    draft.validate();
    final db = await store.databaseFor(uid);
    await db.insert('sale_drafts', {
      'id': id,
      'title': draft.customerName?.trim().isNotEmpty == true
          ? draft.customerName
          : 'Untitled bill',
      'draft': jsonEncode(SaleDraftCodec.encode(draft)),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<SaleDraft> get(String uid, String id) async {
    final rows = await (await store.databaseFor(uid))
        .query('sale_drafts', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) {
      throw const FormatException('This bill draft was not found.');
    }
    return SaleDraftCodec.decode(jsonDecode(rows.single['draft']! as String));
  }

  Future<void> remove(String uid, String id) async =>
      (await store.databaseFor(uid))
          .delete('sale_drafts', where: 'id = ?', whereArgs: [id]);
}
