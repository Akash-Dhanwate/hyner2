import 'package:hyner/features/pricing/application/product_setup.dart';
import 'package:hyner/features/pricing/domain/exact.dart';
import 'package:hyner/features/pricing/domain/universal/universal_pricing.dart';

ProductSetup setup(
  String kind, {
  String name = 'Product',
  String rate = '150',
}) {
  final draft = ProductSetup.create(kind: kind);
  draft.data['name'] = name;
  draft.data['taxBehavior'] = 'exempt';
  draft.rows('rates').first['amount'] = rate;
  return draft;
}

final currency = Currency('INR', 2);
final now = DateTime.utc(2026, 11, 9);
NumberInput n(String value, String unit) =>
    NumberInput(Exact.parse(value), unit);
