import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/reports/domain/business_report.dart';
import 'package:hyner/features/reports/presentation/report_charts.dart';

import 'support/design_fixture.dart';

BusinessReport series({int month = 11, bool empty = false}) {
  final b = designReport();
  final start = DateTime.utc(2026, month);
  return BusinessReport(
    currency: b.currency,
    start: start,
    end: DateTime.utc(2026, month + 1),
    salesCount: b.salesCount,
    soldUnits: b.soldUnits,
    paidSalesCount: b.paidSalesCount,
    unpaidSalesCount: b.unpaidSalesCount,
    revenueMinor: b.revenueMinor,
    paidRevenueMinor: b.paidRevenueMinor,
    unpaidRevenueMinor: b.unpaidRevenueMinor,
    trackedRevenueMinor: b.trackedRevenueMinor,
    costOfGoodsMinor: b.costOfGoodsMinor,
    grossProfitMinor: b.grossProfitMinor,
    uncostedSalesCount: b.uncostedSalesCount,
    purchaseCount: b.purchaseCount,
    purchaseSpendMinor: b.purchaseSpendMinor,
    returnValueMinor: b.returnValueMinor,
    inventoryValueMinor: b.inventoryValueMinor,
    topProducts: b.topProducts,
    activity: empty
        ? []
        : List.generate(
            30,
            (i) => ReportActivityPoint(
              periodStart: start.add(Duration(days: i)),
              label: 'Day ${i + 1}',
              revenueMinor: BigInt.from(1000),
              expenseMinor: BigInt.from(500),
            ),
          ),
  );
}

void main() {
  testWidgets(
    'chart starts at latest week, retains browsing position and resets on period change',
    (tester) async {
      Future<void> show(BusinessReport report) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: ActivityBarChart(report: report),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      ScrollPosition position() => tester
          .widget<SingleChildScrollView>(
            find.byKey(const Key('activity-scroll')),
          )
          .controller!
          .position;
      await show(series());
      expect(position().maxScrollExtent, greaterThan(0));
      expect(position().pixels, position().maxScrollExtent);
      position().jumpTo(0);
      await show(series());
      expect(position().pixels, 0);
      await show(series(month: 12));
      expect(position().pixels, position().maxScrollExtent);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty chart focuses latest when activity arrives', (
    tester,
  ) async {
    Future<void> show(bool empty) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: ActivityBarChart(report: series(empty: empty)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(true);
    expect(find.byKey(const Key('activity-scroll')), findsNothing);
    await show(false);
    final position = tester
        .widget<SingleChildScrollView>(find.byKey(const Key('activity-scroll')))
        .controller!
        .position;
    expect(position.pixels, position.maxScrollExtent);
  });
}
