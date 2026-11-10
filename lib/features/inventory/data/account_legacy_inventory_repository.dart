import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/inventory_repository.dart';
import '../domain/product.dart';
import 'firestore_inventory_repository.dart';

/// Read-only, optional import of the signed-in account's older cloud catalogue.
/// Firebase initialization is deferred and never blocks the device workspace.
class AccountLegacyInventoryRepository implements InventoryRepository {
  AccountLegacyInventoryRepository(this.accountServices);
  final Future<AuthRepository> accountServices;
  InventoryRepository? _source;

  Future<InventoryRepository> _forOwner(String uid) async {
    final auth = await accountServices;
    if (auth.currentUser?.uid != uid || auth.currentUser?.localOnly == true) {
      throw const AppFailure(
        FailureKind.permission,
        'Cloud import requires the matching signed-in account.',
      );
    }
    return _source ??= FirestoreInventoryRepository(FirebaseFirestore.instance);
  }

  @override
  Future<InventoryPage> list(
    String uid,
    InventoryQuery query, {
    InventoryCursor? after,
  }) async => (await _forOwner(uid)).list(uid, query, after: after);
  @override
  Future<Product> get(String uid, String sku) async =>
      (await _forOwner(uid)).get(uid, sku);
  @override
  Future<MovementPage> movements(
    String uid,
    String sku, {
    MovementCursor? after,
  }) async => (await _forOwner(uid)).movements(uid, sku, after: after);

  Never _readOnly() => throw UnsupportedError(
    'Legacy catalogue is import-only. Save changes to the local register.',
  );
  @override
  String newOperationId() => _readOnly();
  @override
  Future<void> create(
    String uid,
    ProductDraft draft,
    String operationId,
  ) async => _readOnly();
  @override
  Future<void> update(
    String uid,
    ProductDraft draft,
    int expectedRevision,
  ) async => _readOnly();
  @override
  Future<void> setArchived(String uid, Product product, bool archived) async =>
      _readOnly();
  @override
  Future<void> adjust(
    String uid,
    Product product,
    int delta,
    String reason,
    String operationId,
  ) async => _readOnly();
}
