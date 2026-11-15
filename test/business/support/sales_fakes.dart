import 'dart:async';

import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/sales/domain/sale_search.dart';
import 'package:hyner/features/sales/domain/sales_repository.dart';

import 'inventory_fakes.dart';

class FakeSales implements SalesRepository {
  FakeSales(this.inventory);
  final FakeInventory inventory;
  final Map<String, Map<String, Sale>> accounts = {};
  Map<String, Sale> sales(String uid) => accounts.putIfAbsent(uid, () => {});
  AppFailure? failure;
  bool failAfterCommit = false;
  Completer<SalesPage>? pendingList;
  Completer<void>? pendingWrite;
  int ids = 0, writes = 0, pageSize = 30;
  final requestedUids = <String>[];
  final deletedIds = <(String, String)>{};
  @override
  String newSaleId() => 'sale${++ids}';
  @override
  Future<SalesPage> list(
    String uid, {
    SalesCursor? after,
    String search = '',
  }) async {
    requestedUids.add(uid);
    if (pendingList != null) return pendingList!.future;
    if (failure != null) throw failure!;
    final values = sales(uid).values.toList()
      ..sort((a, b) {
        final date = b.createdAt.compareTo(a.createdAt);
        return date == 0 ? b.id.compareTo(a.id) : date;
      });
    final remaining = values
        .where(SaleSearch(search).matches)
        .where(
          (s) =>
              after == null ||
              s.createdAt.isBefore(after.time) ||
              (s.createdAt == after.time && s.id.compareTo(after.id) < 0),
        )
        .toList();
    final page = remaining.take(pageSize).toList();
    return SalesPage(
      page,
      remaining.length > pageSize
          ? SalesCursor(page.last.createdAt, page.last.id)
          : null,
    );
  }

  @override
  Future<List<Sale>> recent(String uid) async =>
      (await list(uid)).sales.take(3).toList();

  @override
  Future<void> updateContact(
    String uid,
    String id, {
    required String name,
    required String phone,
    required String? expectedName,
    required String? expectedPhone,
  }) async {
    final prior = await get(uid, id);
    if (!prior.canEditContactAt(DateTime.now())) {
      throw inventoryInvalid(
        'Customer details are locked seven days after bill creation.',
      );
    }
    if (prior.draft.customerName != expectedName ||
        prior.draft.customerPhone != expectedPhone) {
      throw inventoryInvalid('Reload this bill before editing.');
    }
    final d = prior.draft;
    sales(uid)[id] = Sale(
      id: prior.id,
      createdAt: prior.createdAt,
      draft: SaleDraft(
        currency: d.currency,
        lines: d.lines,
        customerId: d.customerId,
        customerName: name,
        customerPhone: phone,
        customerAddress: d.customerAddress,
        initialPaymentMinor: d.initialPaymentMinor,
      ),
      paymentStatus: prior.paymentStatus,
      paidAt: prior.paidAt,
      paidMinor: prior.paidMinor,
      expectedPaymentMinor: prior.expectedPaymentMinor,
      payments: prior.payments,
      followupAt: prior.followupAt,
    );
  }

  @override
  Future<List<Sale>> forCustomer(String uid, String customerId) async =>
      sales(uid).values
          .where((sale) => sale.draft.customerId == customerId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<Sale> get(String uid, String id) async {
    if (failure != null) throw failure!;
    return sales(uid)[id] ??
        (throw const AppFailure(
          FailureKind.invalidData,
          'Sale not found',
          reference: 'sales/not-found',
        ));
  }

  @override
  Future<void> create(String uid, String id, SaleDraft draft) async {
    if (pendingWrite != null) await pendingWrite!.future;
    if (failure != null) throw failure!;
    draft.validate();
    if (deletedIds.contains((uid, id))) {
      throw inventoryInvalid('This bill was deleted. Start a new bill.');
    }
    final existing = sales(uid)[id];
    if (existing != null) {
      if (!existing.draft.matches(draft)) {
        throw inventoryInvalid('Sale reference already used');
      }
      return;
    }
    draft.validateForNewBill();
    for (final line in draft.lines) {
      if (!line.stockTracked) continue;
      final p = inventory.products(uid)[line.sku];
      if (p == null || p.archived || p.quantity < line.quantity) {
        throw inventoryInvalid('Insufficient available stock.');
      }
      if (p.name != line.name || p.currency != draft.currency) {
        throw inventoryInvalid('Product changed. Remove it and add it again.');
      }
    }
    for (final line in draft.lines) {
      if (!line.stockTracked) continue;
      final p = inventory.products(uid)[line.sku]!;
      inventory.products(uid)[line.sku] = Product(
        sku: p.sku,
        name: p.name,
        category: p.category,
        currency: p.currency,
        costMinor: p.costMinor,
        priceMinor: p.priceMinor,
        quantity: p.quantity - line.quantity,
        reorderLevel: p.reorderLevel,
        archived: false,
        revision: p.revision + 1,
        lastMovementId: id,
        createdAt: p.createdAt,
        updatedAt: DateTime.utc(2026, 10, 25, 12),
      );
    }
    sales(uid)[id] = Sale(
      id: id,
      draft: draft,
      createdAt: DateTime.utc(2026, 10, 25, 12),
    );
    writes++;
    if (failAfterCommit) {
      throw const AppFailure(FailureKind.network, 'Connection interrupted');
    }
  }

  @override
  Future<void> delete(
    String uid,
    String id, {
    required int expectedPaidMinor,
  }) async {
    if (pendingWrite != null) await pendingWrite!.future;
    if (failure != null) throw failure!;
    if (deletedIds.contains((uid, id))) return;
    final sale = await get(uid, id);
    if (sale.paidMinor != expectedPaidMinor) {
      throw inventoryInvalid(
        'Payments on this bill changed. Reopen the bill before deleting it.',
      );
    }
    for (final line in sale.draft.lines) {
      if (!line.stockTracked) continue;
      final p = inventory.products(uid)[line.sku]!;
      inventory.products(uid)[line.sku] = Product(
        sku: p.sku,
        name: p.name,
        category: p.category,
        currency: p.currency,
        costMinor: p.costMinor,
        priceMinor: p.priceMinor,
        parameters: p.parameters,
        pricingFormula: p.pricingFormula,
        quantity: p.quantity + line.quantity,
        reorderLevel: p.reorderLevel,
        archived: false,
        revision: p.revision + 1,
        lastMovementId: 'delete_$id',
        createdAt: p.createdAt,
        updatedAt: DateTime.now(),
      );
    }
    sales(uid).remove(id);
    deletedIds.add((uid, id));
    writes++;
  }

  @override
  Future<void> markPaid(String uid, String id) async {
    final sale = sales(uid)[id];
    if (sale == null) throw inventoryInvalid('Sale not found');
    sales(uid)[id] = Sale(
      id: sale.id,
      draft: sale.draft,
      createdAt: sale.createdAt,
      paymentStatus: PaymentStatus.paid,
      paidAt: DateTime.utc(2026, 10, 25, 12),
    );
  }

  @override
  Future<void> recordPayment(
    String uid,
    String id,
    int amountMinor, {
    String? operationId,
  }) async {
    final sale = sales(uid)[id];
    if (sale == null) throw inventoryInvalid('Sale not found');
    final paid = sale.paidMinor + amountMinor;
    if (amountMinor < 1 || paid > sale.draft.totalMinor) {
      throw inventoryInvalid('Invalid payment amount');
    }
    sales(uid)[id] = Sale(
      id: sale.id,
      draft: sale.draft,
      createdAt: sale.createdAt,
      paymentStatus: paid == sale.draft.totalMinor
          ? PaymentStatus.paid
          : PaymentStatus.partial,
      paidMinor: paid,
      expectedPaymentMinor: sale.draft.totalMinor - paid,
      paidAt: paid == sale.draft.totalMinor
          ? DateTime.utc(2026, 10, 25, 12)
          : null,
    );
  }

  @override
  Future<List<Sale>> remainingPayments(String uid) async =>
      sales(uid).values.where((sale) => sale.remainingMinor > 0).toList();

  @override
  Future<void> setFollowUp(String uid, String id, DateTime? followupAt) async {}

  @override
  Future<List<Sale>> scheduledFollowUps(String uid) async => const [];
}
