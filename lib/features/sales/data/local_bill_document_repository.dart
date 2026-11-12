import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/local_business_database.dart';
import '../domain/bill_document_repository.dart';
import 'bill_document_codec.dart';

class LocalBillDocumentRepository implements BillDocumentRepository {
  LocalBillDocumentRepository(this.store);
  final LocalBusinessDatabase store;
  final _jobs = <(String, String), Future<void>>{};

  @override
  Future<bool> hasDuplicate(String uid, String saleId) async {
    final db = await store.databaseFor(uid);
    final rows = await db.query(
      'bill_documents',
      columns: ['saleId'],
      where: 'saleId = ?',
      whereArgs: [saleId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> ensureDuplicate(
    String uid,
    String saleId,
    Future<Uint8List> Function() generate,
  ) {
    final key = (uid, saleId);
    final existing = _jobs[key];
    if (existing != null) return existing;
    final job =
        (() async {
          if (await hasDuplicate(uid, saleId)) return;
          final bytes = await generate();
          await saveDuplicate(uid, saleId, bytes);
        })().whenComplete(() {
          _jobs.remove(key);
        });
    _jobs[key] = job;
    return job;
  }

  @override
  Future<Uint8List?> duplicate(String uid, String saleId) async {
    final db = await store.databaseFor(uid);
    final rows = await db.query(
      'bill_documents',
      where: 'saleId = ?',
      whereArgs: [saleId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return BillDocumentCodec.decodePdf(
      rows.single['duplicatePdf']! as List<int>,
      encoding: rows.single['encoding'],
    );
  }

  @override
  Future<void> saveDuplicate(String uid, String saleId, Uint8List bytes) async {
    final archived = BillDocumentCodec.encodePdf(bytes);
    final db = await store.databaseFor(uid);
    await db.transaction((tx) async {
      final sale = await tx.query(
        'sales',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );
      if (sale.isEmpty) {
        throw StateError('Save the bill before archiving its duplicate.');
      }
      await tx.insert('bill_documents', {
        'saleId': saleId,
        'duplicatePdf': archived.bytes,
        'encoding': archived.encoding,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }
}
