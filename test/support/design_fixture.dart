import 'package:hyner/features/reports/domain/business_report.dart';

/// Synthetic presentation fixture, never live merchant metrics.
BusinessReport designReport() => BusinessReport(
  currency: 'INR',
  start: DateTime.utc(2026, 11),
  end: DateTime.utc(2026, 12),
  salesCount: 1,
  soldUnits: 2,
  paidSalesCount: 0,
  unpaidSalesCount: 1,
  revenueMinor: BigInt.from(630000),
  paidRevenueMinor: BigInt.from(315000),
  unpaidRevenueMinor: BigInt.from(315000),
  trackedRevenueMinor: BigInt.from(630000),
  costOfGoodsMinor: BigInt.from(360000),
  grossProfitMinor: BigInt.from(270000),
  uncostedSalesCount: 0,
  purchaseCount: 1,
  purchaseSpendMinor: BigInt.from(108000),
  returnValueMinor: BigInt.zero,
  inventoryValueMinor: BigInt.from(2160000),
  topProducts: [
    ProductSalesStat(
      sku: 'DOOR',
      name: 'Flush door',
      units: 2,
      revenueMinor: BigInt.from(630000),
    ),
  ],
  activity: [
    ReportActivityPoint(
      periodStart: DateTime.utc(2026, 11, 10),
      label: '10 Nov',
      revenueMinor: BigInt.from(210000),
      expenseMinor: BigInt.from(36000),
    ),
    ReportActivityPoint(
      periodStart: DateTime.utc(2026, 11, 11),
      label: '11 Nov',
      revenueMinor: BigInt.from(420000),
      expenseMinor: BigInt.from(72000),
    ),
  ],
);
