import '../../inventory/domain/product.dart';
import '../domain/sale.dart';
import '../domain/sale_price_snapshot.dart';

/// Safe, local-only serialization for an unfinished bill. Unlike a sale, a
/// draft never changes stock or reports.
abstract final class SaleDraftCodec {
  static Map<String, dynamic> encode(SaleDraft draft) => {
    'version': 1,
    'currency': draft.currency,
    'customerId': draft.customerId,
    'customerName': draft.customerName,
    'customerPhone': draft.customerPhone,
    'customerAddress': draft.customerAddress,
    'initialPaymentMinor': draft.initialPaymentMinor,
    'lines': [
      for (final line in draft.lines) {'sku': line.sku, ...line.toMap()},
    ],
  };

  static SaleDraft decode(Map<String, dynamic> value) {
    if (value['version'] != 1 ||
        value['currency'] is! String ||
        value['lines'] is! List) {
      throw const FormatException('This bill draft could not be read safely.');
    }
    final lines = <SaleLine>[];
    for (final raw in value['lines'] as List) {
      final map = Map<String, dynamic>.from(raw as Map);
      final line = SaleLine(
        sku: map['sku'] as String,
        name: map['name'] as String,
        quantity: map['quantity'] as int,
        unitPriceMinor: map['unitPriceMinor'] as int,
        unitCostMinor: map['unitCostMinor'] as int? ?? 0,
        inventorySku: map['inventorySku'] as String?,
        inventoryCostKnown: map['inventoryCostKnown'] as bool? ?? false,
        parameters: [
          for (final p in (map['parameters'] as List? ?? const []))
            ProductParameter.fromMap(p as Map),
        ],
        pricing: map['pricing'] == null
            ? null
            : SalePriceSnapshot.fromJson(
                Map<String, dynamic>.from(map['pricing'] as Map),
              ),
      );
      if (map['totalMinor'] != line.totalMinor) {
        throw const FormatException('Bill draft item total mismatch.');
      }
      line.validate();
      lines.add(line);
    }
    final draft = SaleDraft(
      currency: value['currency'] as String,
      lines: lines,
      customerId: value['customerId'] as String?,
      customerName: value['customerName'] as String?,
      customerPhone: value['customerPhone'] as String?,
      customerAddress: value['customerAddress'] as String?,
      initialPaymentMinor: value['initialPaymentMinor'] as int?,
    );
    draft.validate();
    return draft;
  }
}
