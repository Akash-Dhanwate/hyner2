import '../../inventory/domain/product.dart';
import 'sale.dart';

/// Searches bill contact snapshots and exact bill totals, never inventory prices.
class SaleSearch {
  SaleSearch(String query) : text = query.trim().toLowerCase() {
    final numeric = text
        .replaceAll(RegExp(r'^(inr|usd|eur|gbp)\s*'), '')
        .replaceAll(RegExp(r'[₹\$€£,\s]'), '');
    if (RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(numeric)) {
      try {
        amountMinor = parseMoney(numeric);
      } catch (_) {
        /* Text-only search. */
      }
    }
    if (RegExp(r'^\+?[\d ()-]+$').hasMatch(text)) {
      phoneDigits = text.replaceAll(RegExp(r'\D'), '');
    }
  }
  final String text;
  int? amountMinor;
  String? phoneDigits;
  bool contactMatches(String? name, String? phone, String reference) =>
      text.isEmpty ||
      (name ?? '').toLowerCase().contains(text) ||
      reference.toLowerCase().contains(text) ||
      (phone ?? '').toLowerCase().contains(text) ||
      (phoneDigits?.isNotEmpty == true &&
          (phone ?? '').replaceAll(RegExp(r'\D'), '').contains(phoneDigits!));
  bool matches(Sale sale) =>
      contactMatches(
        sale.draft.customerName,
        sale.draft.customerPhone,
        sale.id,
      ) ||
      amountMinor != null && sale.draft.totalMinor == amountMinor;
}
