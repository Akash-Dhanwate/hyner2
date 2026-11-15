import 'dart:convert';

import '../../customers/domain/customer.dart';
import '../../inventory/domain/product.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_price_snapshot.dart';

/// A saved offer, independent of sales, payments, inventory and calculator drafts.
class Quotation {
  Quotation({required this.id, required this.createdAt, required this.draft}) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id)) {
      throw const FormatException('Invalid quotation reference.');
    }
    draft.validate();
    if (draft.customerName?.trim().isNotEmpty != true ||
        !validCustomerMobile(draft.customerPhone ?? '') ||
        draft.initialPaymentMinor != 0) {
      throw const FormatException(
        'Enter a customer name and valid mobile number.',
      );
    }
  }
  final String id;
  final DateTime createdAt;
  final SaleDraft draft;
  static const format = 'hyner-quickprice-quotation';
  String get snapshot => jsonEncode({
    'format': format,
    'version': 1,
    'address': draft.customerAddress ?? '',
    'lines': [
      for (final line in draft.lines) {'sku': line.sku, ...line.toMap()},
    ],
  });
  Map<String, Object?> toRow() => {
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'customerName': draft.customerName,
    'customerPhone': draft.customerPhone,
    'currency': draft.currency,
    'description': snapshot,
    'subtotalMinor': draft.netMinor,
    'taxRateBasisPoints': 0,
    'taxMinor': draft.taxMinor,
    'totalMinor': draft.totalMinor,
    'status': 'draft',
    'validUntil': null,
  };
  static Quotation? fromRow(Map<String, Object?> row) {
    final text = row['description'] as String;
    if (!text.startsWith('{')) return null;
    dynamic value;
    try {
      value = jsonDecode(text);
    } catch (_) {
      return null;
    }
    if (value is! Map || value['format'] != format) return null;
    if (value['version'] != 1 ||
        value['lines'] is! List ||
        value['address'] is! String) {
      throw const FormatException('This quotation could not be read safely.');
    }
    final lines = <SaleLine>[];
    for (final raw in value['lines'] as List) {
      final map = Map<String, dynamic>.from(raw as Map);
      final line = SaleLine(
        sku: map['sku'] as String,
        name: map['name'] as String,
        quantity: map['quantity'] as int,
        unitPriceMinor: map['unitPriceMinor'] as int,
        unitCostMinor: map['unitCostMinor'] as int,
        parameters: [
          for (final p in map['parameters'] as List)
            ProductParameter.fromMap(p as Map),
        ],
        pricing: map['pricing'] == null
            ? null
            : SalePriceSnapshot.fromJson(
                Map<String, dynamic>.from(map['pricing'] as Map),
              ),
      );
      if (map['totalMinor'] != line.totalMinor) {
        throw const FormatException('Quotation item total mismatch.');
      }
      lines.add(line);
    }
    final draft = SaleDraft(
      currency: row['currency'] as String,
      lines: lines,
      customerName: row['customerName'] as String,
      customerPhone: row['customerPhone'] as String,
      customerAddress: value['address'] as String,
      initialPaymentMinor: 0,
    );
    final quote = Quotation(
      id: row['id'] as String,
      createdAt: DateTime.parse(row['createdAt'] as String),
      draft: draft,
    );
    if (draft.totalMinor != row['totalMinor'] ||
        draft.taxMinor != row['taxMinor'] ||
        draft.netMinor != row['subtotalMinor']) {
      throw const FormatException(
        'Quotation totals do not match the saved items.',
      );
    }
    return quote;
  }

  Sale get document => Sale(id: id, createdAt: createdAt, draft: draft);
}
