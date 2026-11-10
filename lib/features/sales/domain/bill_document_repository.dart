import 'dart:typed_data';

abstract interface class BillDocumentRepository {
  Future<Uint8List?> duplicate(String uid, String saleId);
  Future<void> saveDuplicate(String uid, String saleId, Uint8List bytes);
}
