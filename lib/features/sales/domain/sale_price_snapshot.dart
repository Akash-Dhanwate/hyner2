import 'dart:convert';

import '../../inventory/domain/product.dart';
import '../../pricing/domain/exact.dart';
import '../../pricing/domain/serialization.dart';
import '../../pricing/domain/universal/universal_pricing.dart';

/// The complete replayable quote for a custom, non-stock sale line.
/// Replay checks consistency, not the authority of a caller-supplied rule.
final class SalePriceSnapshot {
  SalePriceSnapshot._(this.result, this.snapshotJson);

  static const sessionExtraOverrideWarning =
      'Base rate overridden for this calculation. Stored rates are unchanged.';

  factory SalePriceSnapshot.fromResult(PricingResult result) =>
      SalePriceSnapshot.fromJson(result.toJson());

  factory SalePriceSnapshot.fromJson(Map<String, dynamic> json) {
    try {
      // Detach nested collections from the caller and reject non-JSON values.
      final savedJson = canonicalJson(json);
      final saved = jsonDecode(savedJson) as Map<String, dynamic>;
      final rule = UniversalPricingRule.fromJson(
        saved['rule'] as Map<String, dynamic>,
      );
      final request = UniversalPricingRequest.fromJson(
        saved['request'] as Map<String, dynamic>,
      );
      final replay = UniversalPricingEngine().calculate(
        rule,
        request,
        at: DateTime.parse(saved['calculatedAt'] as String),
      );
      final warnings = saved['warnings'];
      if (warnings is! List || warnings.any((value) => value is! String)) {
        throw const FormatException('Invalid pricing warnings');
      }
      final originalWarnings = replay.warnings;
      final hasOverride =
          warnings.length == originalWarnings.length + 1 &&
          warnings.last == sessionExtraOverrideWarning;
      if ((!hasOverride && warnings.length != originalWarnings.length) ||
          !originalWarnings.indexed.every(
            (entry) => warnings[entry.$1] == entry.$2,
          )) {
        throw const FormatException('Pricing warnings do not match replay');
      }
      final expected = replay.toJson();
      expected['warnings'] = warnings;
      if (canonicalJson(expected) != savedJson) {
        throw const FormatException('Pricing snapshot does not match replay');
      }
      final result = hasOverride
          ? PricingResult(
              rule: replay.rule,
              calculatedAt: replay.calculatedAt,
              request: replay.request,
              inputs: replay.inputs,
              billableInputs: replay.billableInputs,
              base: replay.base,
              extras: replay.extras,
              unitBaseAmount: replay.unitBaseAmount,
              orderBaseAmount: replay.orderBaseAmount,
              extraAmount: replay.extraAmount,
              amounts: replay.amounts,
              warnings: warnings.cast<String>(),
            )
          : replay;
      final snapshot = SalePriceSnapshot._(result, savedJson);
      snapshot._validateLimits();
      return snapshot;
    } catch (_) {
      throw inventoryInvalid(
        'This custom price could not be verified. Recalculate the quote.',
      );
    }
  }

  final PricingResult result;
  final String snapshotJson;
  Map<String, dynamic> toJson() =>
      jsonDecode(snapshotJson) as Map<String, dynamic>;

  int get totalMinor => result.amounts.totalMinor.toInt();
  int get netMinor => result.amounts.netMinor.toInt();
  int get taxMinor => result.amounts.taxMinor.toInt();
  int get discountMinor => result.amounts.discountMinor.toInt();
  int get quantity => result.request.quantity;
  String get currency => result.rule.currency.code;
  String get businessId => result.rule.businessId;

  /// Display only: the exact saved line total remains authoritative. Dividing
  /// that total by quantity rounds half up, so unit price × quantity may differ.
  int get unitPriceMinor => Exact(
    result.amounts.totalMinor,
    BigInt.from(quantity),
  ).roundInteger(MoneyRounding.halfUp).toInt();
  bool get unitPriceRounded => totalMinor % quantity != 0;

  void _validateLimits() {
    final amounts = result.amounts;
    if (!inventoryCurrencies.contains(currency) ||
        result.rule.currency.minorDigits != 2 ||
        quantity < 1 ||
        quantity > maxStock ||
        [
          amounts.subtotalMinor,
          amounts.discountMinor,
          amounts.netMinor,
          amounts.taxMinor,
          amounts.totalMinor,
        ].any(
          (value) => value < BigInt.zero || value > BigInt.from(maxMoneyMinor),
        )) {
      throw inventoryInvalid(
        'This custom quote exceeds the supported bill limits.',
      );
    }
  }

  /// Recheck the full snapshot, including after accidental mutation of nested
  /// engine objects exposed through [result].
  void validate() {
    final verified = SalePriceSnapshot.fromJson(toJson());
    if (canonicalJson(result.toJson()) != verified.snapshotJson) {
      throw inventoryInvalid(
        'This custom price has changed. Recalculate the quote.',
      );
    }
  }
}
