import '../../../core/storage/local_business_database.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';
import 'customer_rows.dart';

class LocalCustomerRepository implements CustomerRepository {
  LocalCustomerRepository(this._store);
  final LocalBusinessDatabase _store;

  @override
  Future<List<Customer>> list(String uid) async {
    final db = await _store.databaseFor(uid);
    final rows = await db.query(
      'customers',
      orderBy: 'name COLLATE NOCASE, id',
    );
    return rows.map(customerFromRow).toList();
  }

  @override
  Future<Customer> save(String uid, CustomerDraft draft, {String? id}) async {
    final db = await _store.databaseFor(uid);
    return db.transaction((tx) => saveCustomerRow(tx, draft, id: id));
  }
}
