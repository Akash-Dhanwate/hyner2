import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/workspace_navigation.dart';
import '../../../core/widgets/page_content.dart';
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
    return PageContent(
      children: [
        const Eyebrow('Home'),
        const SizedBox(height: 10),
        Text(
          'Hello, ${profile?.firstName ?? 'there'}.',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () =>
              openWorkspacePage(GoRouter.of(context), '/quickprice'),
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Open QuickPrice'),
        ),
        if (profile?.localOnly == true) ...[
          const SizedBox(height: 10),
          const Text('Device workspace · Saved on this phone'),
        ],
        const SizedBox(height: 22),
        Text('Business snapshot', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
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
              ActivityBarChart(report: data),
              const SizedBox(height: 14),
              PaymentDonutChart(report: data),
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < values.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                key: ValueKey('dashboard-metric-${values[index].$1}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(values[index].$4, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      values[index].$2,
                      softWrap: true,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      values[index].$3,
                      key: ValueKey('dashboard-value-${values[index].$1}'),
                      softWrap: true,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
