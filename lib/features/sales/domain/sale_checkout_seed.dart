import '../../inventory/domain/product.dart';
import 'sale.dart';

/// An immutable QuickPrice checkout, scoped to one account and save operation.
/// Customer and payment details are collected by the shared sales editor.
final class SaleCheckoutSeed {
  SaleCheckoutSeed({
    required this.uid,
    required this.operationId,
    required List<SaleLine> lines,
    this.onSaved,
  }) : lines = List.unmodifiable(lines) {
    validate();
  }

  final String uid;
  final String operationId;
  final List<SaleLine> lines;

  /// Runtime completion hook. Failure cannot undo an already committed sale.
  final Future<void> Function(String saleId)? onSaved;

  String get currency => lines.first.pricing!.currency;

  void validate() {
    if (uid.isEmpty ||
        uid.length > 128 ||
        uid != uid.trim() ||
        uid.contains('/') ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(uid) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(operationId)) {
      throw inventoryInvalid(
        'Open checkout from a valid account and estimate.',
      );
    }
    if (lines.isEmpty || lines.any((line) => line.pricing == null)) {
      throw inventoryInvalid('Add priced items in QuickPrice before checkout.');
    }
    if (lines.any((line) => line.pricing!.currency != currency)) {
      throw inventoryInvalid('Choose priced items in the same currency.');
    }
    SaleDraft(currency: currency, lines: lines).validate();
  }
}
