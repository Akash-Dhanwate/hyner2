import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/workspace_navigation.dart';
import '../../../core/widgets/page_content.dart';
import '../../../core/widgets/financial_amount.dart';
import '../../../core/widgets/workspace_components.dart';
import '../../../core/performance/performance_recorder.dart';
import '../../auth/presentation/session_controller.dart';
import '../../customers/presentation/customers_controller.dart';
import '../../reports/domain/business_report.dart';
import '../../reports/presentation/report_charts.dart';
import '../../reports/presentation/reports_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).profile;
    final today = DateTime.now();
    final allTimeQuery = ReportQuery(
      currency: 'INR',
      period: ReportPeriod.allTime,
      start: DateTime(1970, 1, 1),
      endExclusive: DateTime(today.year, today.month, today.day + 1),
    );
    final report = ref.watch(businessReportProvider(allTimeQuery));
    final customers = ref.watch(customersProvider);
    final theme = Theme.of(context);
    if (report.hasValue &&
        !report.isLoading &&
        customers.hasValue &&
        !customers.isLoading) {
      PerformanceRecorder.afterFrame(PerformanceMilestone.dashboardReady);
    }
    return PageContent(
      children: [
        const Eyebrow('Home'),
        const SizedBox(height: 10),
        Text(
          'Hello, ${profile?.firstName ?? 'there'}.',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        ResponsivePair(
          first: FilledButton.icon(
            onPressed: () =>
                openWorkspacePage(GoRouter.of(context), '/quickprice'),
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Open QuickPrice'),
          ),
          second: OutlinedButton.icon(
            onPressed: () => openWorkspacePage(GoRouter.of(context), '/sales'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Build a bill'),
          ),
          gap: 8,
        ),
        if (profile?.localOnly == true) ...[
          const SizedBox(height: 10),
          const Text('Device workspace · Saved on this phone'),
        ],
        const SizedBox(height: 22),
        Text('Business snapshot', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('All time · INR', style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        _DashboardMetrics(
          customerCount: customers.asData?.value.length,
          report: report.asData?.value,
          customersLoading: customers.isLoading,
          reportLoading: report.isLoading,
        ),
        if (customers.hasError) ...[
          const SizedBox(height: 12),
          const InlineNotice('Customer count could not be loaded.'),
          TextButton(
            onPressed: () => ref.invalidate(customersProvider),
            child: const Text('Retry customer count'),
          ),
        ],
        const SizedBox(height: 14),
        report.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const InlineNotice('Business totals could not be loaded.'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(businessReportProvider(allTimeQuery)),
                child: const Text('Retry business totals'),
              ),
            ],
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecordFact(
                label: data.hasIncompleteCosts
                    ? 'Known-cost earnings'
                    : 'Earnings after costs',
                value: formatBigMoney(
                  data.earningsAfterCostsMinor,
                  data.currency,
                ),
                detail: data.hasIncompleteCosts
                    ? 'Some bills have no saved buying costs'
                    : 'After buying costs and operating expenses',
              ),
              RecordFact(
                label: 'Balance due',
                value: formatBigMoney(data.unpaidRevenueMinor, data.currency),
              ),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () => openWorkspacePage(
                      GoRouter.of(context),
                      '/sales/remaining',
                    ),
                    child: const Text('View unpaid bills'),
                  ),
                  TextButton(
                    onPressed: () =>
                        openWorkspacePage(GoRouter.of(context), '/reports'),
                    child: const Text('View reports'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DisclosureSection(
                title: 'Activity details',
                maintainState: false,
                summary: 'Revenue, expenses and payments',
                children: [
                  ActivityBarChart(report: data),
                  const SizedBox(height: 16),
                  PaymentDonutChart(report: data),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardMetrics extends StatelessWidget {
  const _DashboardMetrics({
    required this.customerCount,
    required this.report,
    required this.customersLoading,
    required this.reportLoading,
  });
  final int? customerCount;
  final BusinessReport? report;
  final bool customersLoading, reportLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = [
      (
        'customers',
        'Customers',
        customerCount?.toString() ?? (customersLoading ? '…' : '—'),
        Icons.people_outline_rounded,
      ),
      (
        'sales',
        'Sales',
        report?.salesCount.toString() ?? (reportLoading ? '…' : '—'),
        Icons.receipt_long_outlined,
      ),
      (
        'revenue',
        'Revenue',
        report == null
            ? (reportLoading ? '…' : '—')
            : formatBigMoney(report!.revenueMinor, report!.currency),
        Icons.trending_up_rounded,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(16) > 24;
        final width = stack
            ? constraints.maxWidth
            : (constraints.maxWidth - 32) / 3;
        return Wrap(
          spacing: 16,
          runSpacing: 20,
          children: [
            for (final value in values)
              SizedBox(
                key: ValueKey('dashboard-metric-${value.$1}'),
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value.$2, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    FinancialAmount(
                      value.$3,
                      textKey: ValueKey('dashboard-value-${value.$1}'),
                      compact: value.$1 != 'revenue',
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
