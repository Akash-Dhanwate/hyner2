import 'dart:typed_data';

abstract interface class BillDocumentRepository {
  Future<bool> hasDuplicate(String uid, String saleId);

  /// Share a single durable generation job between concurrent bill views/actions.
  Future<void> ensureDuplicate(
    String uid,
    String saleId,
    Future<Uint8List> Function() generate,
  );
  Future<Uint8List?> duplicate(String uid, String saleId);
  Future<void> saveDuplicate(String uid, String saleId, Uint8List bytes);
}
