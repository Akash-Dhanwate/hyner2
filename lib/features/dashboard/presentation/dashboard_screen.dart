import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/workspace_navigation.dart';
import '../../../core/performance/performance_recorder.dart';
import '../../../core/widgets/financial_amount.dart';
import '../../../core/widgets/page_content.dart';
import '../../../core/widgets/ui_primitives.dart';
import '../../../core/widgets/workspace_components.dart';
import '../../auth/presentation/session_controller.dart';
import '../../reports/domain/business_report.dart';
import '../../reports/presentation/reports_controller.dart';
import '../../sales/domain/sale.dart';
import '../../sales/presentation/sales_controller.dart';
import '../../onboarding/presentation/first_time_user_guide_screen.dart';
import '../../settings/presentation/payment_settings_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).profile;
    final businessName = ref
        .watch(paymentSettingsProvider)
        .asData
        ?.value
        .merchantName
        .trim();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayQuery = ReportQuery(
      currency: 'INR',
      period: ReportPeriod.today,
      start: todayStart,
      endExclusive: todayStart.add(const Duration(days: 1)),
    );
    final allTimeQuery = ReportQuery(
      currency: 'INR',
      period: ReportPeriod.allTime,
      start: DateTime(1970, 1, 1),
      endExclusive: todayStart.add(const Duration(days: 1)),
    );
    final yearQuery = ReportQuery(
      currency: 'INR',
      period: ReportPeriod.month,
      start: DateTime(now.year, 1, 1),
      endExclusive: DateTime(now.year + 1, 1, 1),
    );
    final todayReport = ref.watch(businessReportProvider(todayQuery));
    final allTimeReport = ref.watch(businessReportProvider(allTimeQuery));
    final yearReport = ref.watch(businessReportProvider(yearQuery));
    final recent = ref.watch(recentSalesProvider);
    final theme = Theme.of(context);

    if (todayReport.hasValue && recent.hasValue && !todayReport.isLoading) {
      PerformanceRecorder.afterFrame(PerformanceMilestone.dashboardReady);
    }

    return PageContent(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                businessName?.isNotEmpty == true
                    ? businessName!
                    : 'Business overview',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium,
              ),
              if (profile != null) FirstTimeUserGuidePrompt(uid: profile.uid),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Overview', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        HynerSurface(
          child: todayReport.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => _RetryMessage(
              message: 'Today’s sales could not be loaded.',
              onRetry: () => ref.invalidate(businessReportProvider(todayQuery)),
            ),
            data: (report) =>
                _TodaySummary(report: report, outstanding: allTimeReport),
          ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 520 ||
                MediaQuery.textScalerOf(context).scale(16) > 22;
            final actions = [
              HynerPrimaryButton(
                onPressed: () =>
                    openWorkspacePage(GoRouter.of(context), '/sales'),
                icon: Icons.add_rounded,
                label: 'Bill',
              ),
              HynerSecondaryButton(
                onPressed: () =>
                    openWorkspacePage(GoRouter.of(context), '/quickprice'),
                icon: Icons.calculate_outlined,
                label: 'Quick Price',
              ),
            ];
            return stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      actions[0],
                      const SizedBox(height: 8),
                      actions[1],
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: actions[0]),
                      const SizedBox(width: 10),
                      Expanded(child: actions[1]),
                    ],
                  );
          },
        ),
        const SizedBox(height: 20),
        const DashboardSalesTrend(),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack =
                constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(16) > 24;
            final title = Text(
              'Recent bills',
              style: theme.textTheme.titleLarge,
            );
            final action = TextButton(
              onPressed: () =>
                  openWorkspacePage(GoRouter.of(context), '/sales/history'),
              child: const Text('View all'),
            );
            return stack
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, action],
                  )
                : Row(
                    children: [
                      Expanded(child: title),
                      action,
                    ],
                  );
          },
        ),
        HynerSurface(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: recent.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => _RetryMessage(
              message: 'Recent bills could not be loaded.',
              onRetry: () => ref.invalidate(recentSalesProvider),
            ),
            data: (sales) => sales.isEmpty
                ? const _EmptyRecentBills()
                : Column(
                    children: [
                      for (final sale in sales.take(2))
                        _RecentBillRow(sale: sale),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
        DisclosureSection(
          title: 'Business summary',
          summary: 'Yearly totals and earnings',
          maintainState: false,
          children: [
            allTimeReport.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => _RetryMessage(
                message: 'Business totals could not be loaded.',
                onRetry: () =>
                    ref.invalidate(businessReportProvider(allTimeQuery)),
              ),
              data: (report) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RecordFact(
                    label: report.hasIncompleteCosts
                        ? 'Known-cost earnings'
                        : 'Earnings after costs',
                    value: formatBigMoney(
                      report.earningsAfterCostsMinor,
                      report.currency,
                    ),
                    detail: report.hasIncompleteCosts
                        ? 'Some bills have no saved buying costs'
                        : 'After buying costs and operating expenses',
                  ),
                  yearReport.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (year) => RecordFact(
                      label: 'Yearly turnover',
                      value: formatBigMoney(year.revenueMinor, year.currency),
                      detail:
                          '${year.salesCount} bills · ${year.soldUnits} items sold',
                    ),
                  ),
                  const SizedBox(height: 12),
                  RecordFact(
                    label: 'All-time turnover',
                    value: formatBigMoney(report.revenueMinor, report.currency),
                    detail:
                        '${report.salesCount} bills · ${report.soldUnits} items sold',
                  ),
                  const SizedBox(height: 12),
                  RecordFact(
                    label: 'Amount due',
                    value: formatBigMoney(
                      report.unpaidRevenueMinor,
                      report.currency,
                    ),
                    detail: '${report.unpaidSalesCount} bills with a balance',
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () =>
                        openWorkspacePage(GoRouter.of(context), '/reports'),
                    icon: const Icon(Icons.bar_chart_rounded),
                    label: const Text('More business figures'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DashboardSalesTrend extends ConsumerStatefulWidget {
  const DashboardSalesTrend({super.key});

  @override
  ConsumerState<DashboardSalesTrend> createState() =>
      _DashboardSalesTrendState();
}

class _DashboardSalesTrendState extends ConsumerState<DashboardSalesTrend> {
  String _range = 'Month';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = switch (_range) {
      'Week' => today.subtract(Duration(days: today.weekday - 1)),
      'Year' => DateTime(now.year, 1, 1),
      _ => DateTime(now.year, now.month, 1),
    };
    final end = switch (_range) {
      'Week' => start.add(const Duration(days: 7)),
      'Year' => DateTime(now.year + 1, 1, 1),
      _ => DateTime(now.year, now.month + 1, 1),
    };
    final report = ref.watch(
      businessReportProvider(
        ReportQuery(
          currency: 'INR',
          period: _range == 'Year' ? ReportPeriod.allTime : ReportPeriod.month,
          start: start,
          endExclusive: end,
        ),
      ),
    );
    final theme = Theme.of(context);
    return HynerSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sales & customers',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              for (final range in const ['Week', 'Month', 'Year'])
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(range),
                    selected: _range == range,
                    onSelected: (_) => setState(() => _range = range),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _TrendLegend(color: theme.colorScheme.primary, label: 'Sales'),
              const SizedBox(width: 16),
              _TrendLegend(
                color: theme.colorScheme.tertiary,
                label: 'Customers',
              ),
            ],
          ),
          const SizedBox(height: 8),
          report.when(
            loading: () => const SizedBox(
              height: 164,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const SizedBox(
              height: 164,
              child: Center(child: Text('Sales trend unavailable')),
            ),
            data: (value) {
              final buckets = _trendBuckets(
                value.salesRecords,
                start,
                end,
                _range,
              );
              if (buckets.every((point) => point.sales == BigInt.zero)) {
                return const SizedBox(
                  height: 164,
                  child: Center(
                    child: Text('No sales recorded in this period'),
                  ),
                );
              }
              return SizedBox(
                height: 164,
                child: Semantics(
                  image: true,
                  label:
                      'Sales and customer trend: ${buckets.map((p) => '${p.label}, sales ${formatBigMoney(p.sales, 'INR')}, ${p.customers} customers').join('. ')}',
                  child: CustomPaint(
                    painter: _DashboardTrendPainter(
                      points: buckets,
                      gridColor: theme.colorScheme.outlineVariant,
                      salesColor: theme.colorScheme.primary,
                      customerColor: theme.colorScheme.tertiary,
                      labelColor: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TrendPoint {
  const _TrendPoint(this.label, this.sales, this.customers);
  final String label;
  final BigInt sales;
  final int customers;
}

List<_TrendPoint> _trendBuckets(
  List<ReportSaleRecord> records,
  DateTime start,
  DateTime end,
  String range,
) {
  final count = range == 'Week'
      ? 7
      : range == 'Year'
      ? 12
      : 5;
  final sales = List<BigInt>.filled(count, BigInt.zero);
  final customers = List<Set<String>>.generate(count, (_) => <String>{});
  final labels = <String>[];
  if (range == 'Week') {
    for (var i = 0; i < count; i++) {
      labels.add(['M', 'T', 'W', 'T', 'F', 'S', 'S'][i]);
    }
  } else if (range == 'Year') {
    for (var i = 0; i < count; i++) {
      labels.add(
        const [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ][i],
      );
    }
  } else {
    for (var i = 0; i < count; i++) {
      labels.add('${i * 7 + 1}');
    }
  }
  for (final record in records) {
    final date = record.date;
    if (date.isBefore(start) || !date.isBefore(end)) continue;
    final index = range == 'Week'
        ? date.difference(start).inDays
        : range == 'Year'
        ? date.month - 1
        : math.min(4, (date.day - 1) ~/ 7);
    sales[index] += record.totalMinor;
    customers[index].add(
      record.customer == 'Walk-in customer'
          ? record.reference
          : record.customer.trim().toLowerCase(),
    );
  }
  return [
    for (var i = 0; i < count; i++)
      _TrendPoint(labels[i], sales[i], customers[i].length),
  ];
}

class _TrendLegend extends StatelessWidget {
  const _TrendLegend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _DashboardTrendPainter extends CustomPainter {
  const _DashboardTrendPainter({
    required this.points,
    required this.gridColor,
    required this.salesColor,
    required this.customerColor,
    required this.labelColor,
  });
  final List<_TrendPoint> points;
  final Color gridColor, salesColor, customerColor, labelColor;
  @override
  void paint(Canvas canvas, Size size) {
    const left = 12.0, right = 12.0, top = 10.0, bottom = 26.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = .7;
    for (var i = 0; i < 4; i++) {
      final y = plot.top + plot.height * i / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }
    final maxSales = points.fold<BigInt>(
      BigInt.zero,
      (max, p) => p.sales > max ? p.sales : max,
    );
    final maxCustomers = points.fold<int>(
      0,
      (max, p) => p.customers > max ? p.customers : max,
    );
    final slot = plot.width / points.length;
    final salesPath = Path(), customerPath = Path();
    for (var i = 0; i < points.length; i++) {
      final x = plot.left + slot * (i + .5);
      final sy =
          plot.bottom -
          (maxSales == BigInt.zero
                  ? 0
                  : points[i].sales.toDouble() / maxSales.toDouble()) *
              plot.height;
      final cy =
          plot.bottom -
          (maxCustomers == 0 ? 0 : points[i].customers / maxCustomers) *
              plot.height;
      if (i == 0) {
        salesPath.moveTo(x, sy);
        customerPath.moveTo(x, cy);
      } else {
        salesPath.lineTo(x, sy);
        customerPath.lineTo(x, cy);
      }
      _label(canvas, points[i].label, Offset(x, plot.bottom + 6));
    }
    final salesPaint = Paint()
      ..color = salesColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final customerPaint = Paint()
      ..color = customerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(salesPath, salesPaint);
    canvas.drawPath(customerPath, customerPaint);
    for (var i = 0; i < points.length; i++) {
      final x = plot.left + slot * (i + .5);
      final sy =
          plot.bottom -
          (maxSales == BigInt.zero
                  ? 0
                  : points[i].sales.toDouble() / maxSales.toDouble()) *
              plot.height;
      final cy =
          plot.bottom -
          (maxCustomers == 0 ? 0 : points[i].customers / maxCustomers) *
              plot.height;
      canvas.drawCircle(Offset(x, sy), 3, Paint()..color = salesColor);
      canvas.drawCircle(Offset(x, cy), 3, Paint()..color = customerColor);
    }
  }

  void _label(Canvas canvas, String text, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(at.dx - painter.width / 2, at.dy));
  }

  @override
  bool shouldRepaint(covariant _DashboardTrendPainter old) =>
      old.points != points ||
      old.gridColor != gridColor ||
      old.salesColor != salesColor ||
      old.customerColor != customerColor;
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.report, required this.outstanding});
  final BusinessReport report;
  final AsyncValue<BusinessReport> outstanding;

  @override
  Widget build(BuildContext context) {
    final outstandingReport = outstanding.asData?.value;
    final outstandingAmount = outstandingReport == null
        ? (outstanding.isLoading ? '…' : '—')
        : formatBigMoney(
            outstandingReport.unpaidRevenueMinor,
            outstandingReport.currency,
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final customers = report.salesRecords
            .map(
              (sale) => sale.customer == 'Walk-in customer'
                  ? 'walk-in:${sale.reference}'
                  : sale.customer.trim().toLowerCase(),
            )
            .toSet()
            .length;
        final figures = <Widget>[
          _FinancialFigure(
            label: 'Sales today',
            amount: formatBigMoney(report.revenueMinor, report.currency),
          ),
          _FinancialFigure(
            label: 'Bills today',
            amount: '${report.salesCount}',
          ),
          _FinancialFigure(label: 'Customers today', amount: '$customers'),
          _FinancialFigure(
            label: 'Total amount due',
            amount: outstandingAmount,
          ),
        ];
        final singleColumn = constraints.maxWidth < 300;
        final width = singleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - 16) / 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 18,
              children: [
                for (final figure in figures)
                  SizedBox(width: width, child: figure),
              ],
            ),
            if (report.hasIncompleteCosts) ...[
              const SizedBox(height: 10),
              Text(
                'Gross profit excludes ${report.uncostedSalesCount} ${report.uncostedSalesCount == 1 ? 'bill' : 'bills'} without a saved purchase cost.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FinancialFigure extends StatelessWidget {
  const _FinancialFigure({required this.label, required this.amount});
  final String label, amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        FinancialAmount(
          amount,
          compact: false,
          color: theme.colorScheme.primary,
        ),
      ],
    );
  }
}

class _RecentBillRow extends StatelessWidget {
  const _RecentBillRow({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customer = sale.draft.customerName?.trim();
    return Semantics(
      button: true,
      label:
          '${customer?.isNotEmpty == true ? customer : 'Walk-in customer'}, '
          '${formatBigMoney(BigInt.from(sale.draft.totalMinor), sale.draft.currency)}',
      child: InkWell(
        onTap: () =>
            context.push<void>('/sales/${Uri.encodeComponent(sale.id)}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer?.isNotEmpty == true
                          ? customer!
                          : 'Walk-in customer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: FinancialAmount(
                  formatBigMoney(
                    BigInt.from(sale.draft.totalMinor),
                    sale.draft.currency,
                  ),
                  compact: true,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRecentBills extends StatelessWidget {
  const _EmptyRecentBills();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('No bills yet.'),
      TextButton.icon(
        onPressed: () => openWorkspacePage(GoRouter.of(context), '/sales'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create your first bill'),
      ),
    ],
  );
}

class _RetryMessage extends StatelessWidget {
  const _RetryMessage({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(message)),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  );
}
