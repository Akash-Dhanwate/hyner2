import 'sale.dart';

class SalesCursor {
  const SalesCursor(this.time, this.id);
  final DateTime time;
  final String id;
}

class SalesPage {
  const SalesPage(this.sales, this.next);
  final List<Sale> sales;
  final SalesCursor? next;
}

abstract interface class SalesRepository {
  String newSaleId();
  Future<SalesPage> list(String uid, {SalesCursor? after, String search = ''});
  Future<void> updateContact(
    String uid,
    String id, {
    required String name,
    required String phone,
    required String? expectedName,
    required String? expectedPhone,
  });
  Future<List<Sale>> recent(String uid);
  Future<List<Sale>> forCustomer(String uid, String customerId);
  Future<Sale> get(String uid, String id);
  Future<void> create(String uid, String id, SaleDraft draft);
  Future<void> delete(String uid, String id, {required int expectedPaidMinor});
  Future<void> markPaid(String uid, String id);
  Future<void> recordPayment(
    String uid,
    String id,
    int amountMinor, {
    String? operationId,
  });
  Future<List<Sale>> remainingPayments(String uid);
  Future<void> setFollowUp(String uid, String id, DateTime? followupAt);
  Future<List<Sale>> scheduledFollowUps(String uid);
}
