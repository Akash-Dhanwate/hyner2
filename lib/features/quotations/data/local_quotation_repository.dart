import '../../../core/storage/local_business_database.dart';
import '../domain/quotation.dart';

abstract interface class QuotationRepository {
  Future<void> save(String uid, Quotation quotation);
  Future<List<Map<String, Object?>>> list(
    String uid, {
    String? beforeTime,
    String? beforeId,
  });
  Future<Quotation> get(String uid, String id);
}

class LocalQuotationRepository implements QuotationRepository {
  LocalQuotationRepository(this.store);
  final LocalBusinessDatabase store;
  void _check(String uid) {
    if (uid.isEmpty ||
        uid != uid.trim() ||
        uid.contains('/') ||
        uid.length > 128) {
      throw const FormatException('Open your business workspace first.');
    }
  }

  @override
  Future<void> save(String uid, Quotation quotation) async {
    _check(uid);
    final row = quotation.toRow();
    // Round-trip and check before committing any snapshot, including caller mutations.
    Quotation.fromRow(row);
    final db = await store.databaseFor(uid);
    await db.transaction((tx) async {
      final existing = await tx.query(
        'quotations',
        where: 'id = ?',
        whereArgs: [quotation.id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        if (existing.single.entries.any(
          (entry) => row[entry.key] != entry.value,
        )) {
          throw const FormatException(
            'This quotation reference is already used. Reopen the saved quotation.',
          );
        }
        return;
      }
      await tx.insert('quotations', row);
    });
  }

  @override
  Future<List<Map<String, Object?>>> list(
    String uid, {
    String? beforeTime,
    String? beforeId,
  }) async {
    _check(uid);
    final marker = '{"format":"${Quotation.format}",%';
    return (await store.databaseFor(uid)).rawQuery(
      """
      SELECT id, customerName, customerPhone, currency, subtotalMinor,
        taxRateBasisPoints, taxMinor, totalMinor, status, validUntil, createdAt,
        CASE WHEN description LIKE ? THEN 'Items from QuickPrice' ELSE description END AS description,
        CASE WHEN description LIKE ? THEN 1 ELSE 0 END AS hasSnapshot
      FROM quotations
      ${beforeTime == null ? '' : 'WHERE createdAt < ? OR (createdAt = ? AND id < ?)'}
      ORDER BY createdAt DESC, id DESC LIMIT 30
    """,
      [
        marker,
        marker,
        if (beforeTime != null) ...[beforeTime, beforeTime, beforeId],
      ],
    );
  }

  @override
  Future<Quotation> get(String uid, String id) async {
    _check(uid);
    final rows = await (await store.databaseFor(uid))
        .query('quotations', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) {
      throw const FormatException('This quotation was not found.');
    }
    final value = Quotation.fromRow(rows.single);
    if (value == null) {
      throw const FormatException(
        'This older quotation has no saved product specifications.',
      );
    }
    return value;
  }
}
