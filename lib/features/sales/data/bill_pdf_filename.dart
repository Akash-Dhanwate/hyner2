import 'package:shared_preferences/shared_preferences.dart';

import '../../quotations/domain/quotation.dart';
import '../domain/sale.dart';

String _cleanFilenamePart(String input, {required int maxRunes}) {
  final safe = String.fromCharCodes(
    input.runes.map((rune) {
      final control = rune < 32 || (rune >= 127 && rune <= 159);
      final pathOrReserved = r'\\/:*?"<>|'.runes.contains(rune);
      return control || pathOrReserved ? 95 : rune;
    }),
  );
  final compact = safe
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'\.{2,}'), '.')
      .trim()
      .replaceAll(RegExp(r'^[._ -]+|[._ -]+$'), '');
  return String.fromCharCodes(compact.runes.take(maxRunes).toList())
      .trim()
      .replaceAll(RegExp(r'[._ -]+$'), '');
}

/// User-visible export naming. These names never replace internal bill IDs.
String billPdfFilename({
  required String? customerName,
  required String? customerPhone,
  required String saleId,
  bool includeMobile = true,
  int? billNumber,
  bool duplicate = false,
}) {
  final name = _cleanFilenamePart(customerName?.trim() ?? '', maxRunes: 52);
  if (billNumber != null) {
    if (billNumber < 1) throw ArgumentError.value(billNumber, 'billNumber');
    return '${name.isEmpty ? 'Customer' : name} - Bill $billNumber${duplicate ? ' - Duplicate' : ''}.pdf';
  }
  final digits = (customerPhone ?? '').replaceAll(RegExp(r'\D'), '');
  final phone = includeMobile && digits.length >= 8 && digits.length <= 15
      ? digits
      : '';
  final parts = <String>[if (name.isNotEmpty) name else 'Bill'];
  if (phone.isNotEmpty) parts.add(phone);

  // Historical anonymous bills need a short distinguishing fallback.
  if (name.isEmpty || phone.isEmpty) {
    final id = _cleanFilenamePart(saleId, maxRunes: 80);
    final trailingDigits = RegExp(r'(\d{1,8})$').firstMatch(id)?.group(1);
    final compactId = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final idRunes = compactId.runes.toList();
    final shortId =
        trailingDigits ??
        String.fromCharCodes(
          idRunes.skip(idRunes.length > 6 ? idRunes.length - 6 : 0),
        );
    if (shortId.isNotEmpty) parts.add(shortId);
  }
  if (duplicate) parts.add('Duplicate');
  return '${parts.join('_')}.pdf';
}

/// Quotes use a separate prefix and short reference; customer phone is omitted.
String quotationPdfFilename(Quotation quote) {
  final customer = _cleanFilenamePart(
    quote.draft.customerName ?? '',
    maxRunes: 44,
  );
  final id = _cleanFilenamePart(quote.id, maxRunes: 80);
  final trailingDigits = RegExp(r'(\d{1,8})$').firstMatch(id)?.group(1);
  final compactId = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  final idRunes = compactId.runes.toList();
  final shortId =
      trailingDigits ??
      String.fromCharCodes(
        idRunes.skip(idRunes.length > 6 ? idRunes.length - 6 : 0),
      );
  return 'Quotation_${customer.isEmpty ? 'Customer' : customer}_$shortId.pdf';
}

class BillPdfFilenamePreferences {
  BillPdfFilenamePreferences();

  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get _store =>
      _preferences ??= SharedPreferencesAsync();
  String _key(String uid) => 'hyner.pdf.include_customer_mobile.$uid';

  Future<bool> includeMobile(String uid) async =>
      await _store.getBool(_key(uid)) ?? false;

  Future<void> setIncludeMobile(String uid, bool value) =>
      _store.setBool(_key(uid), value);

  Future<String> forSale(
    Sale sale,
    String uid, {
    bool duplicate = false,
  }) async => billPdfFilename(
    customerName: sale.draft.customerName,
    customerPhone: sale.draft.customerPhone,
    saleId: sale.id,
    billNumber: sale.billNumber,
    includeMobile: false,
    duplicate: duplicate,
  );
}
