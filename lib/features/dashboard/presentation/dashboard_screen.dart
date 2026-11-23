import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/workspace_navigation.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/performance/performance_recorder.dart';
import '../../../core/widgets/financial_amount.dart';
import '../../../core/widgets/page_content.dart';
import '../../../core/widgets/ui_primitives.dart';
import '../../../core/widgets/workspace_components.dart';
import '../../auth/presentation/session_controller.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../inventory/domain/product.dart';
import '../../reports/domain/business_report.dart';
import '../../reports/presentation/report_charts.dart';
import '../../reports/presentation/reports_controller.dart';
import '../../sales/domain/sale.dart';
import '../../sales/presentation/sales_controller.dart';
import '../../onboarding/presentation/first_time_user_guide_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).profile;
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
    final todayReport = ref.watch(businessReportProvider(todayQuery));
    final allTimeReport = ref.watch(businessReportProvider(allTimeQuery));
    final recent = ref.watch(recentSalesProvider);
    final stock = ref.watch(inventoryProvider);
    final theme = Theme.of(context);

    if (todayReport.hasValue && recent.hasValue && !todayReport.isLoading) {
      PerformanceRecorder.afterFrame(PerformanceMilestone.dashboardReady);
    }

    return PageContent(
      children: [
        HynerSurface(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked =
                      constraints.maxWidth < 500 ||
                      MediaQuery.textScalerOf(context).scale(16) > 22;
                  final greeting = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${profile?.firstName ?? 'there'}.',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Here is your business today.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  );
                  final badge = HynerStatusBadge(
                    label: profile?.localOnly == true ? 'On device' : 'Live',
                    icon: profile?.localOnly == true
                        ? Icons.smartphone_rounded
                        : Icons.cloud_done_outlined,
                  );
                  return stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            greeting,
                            const SizedBox(height: 12),
                            badge,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: greeting),
                            badge,
                          ],
                        );
                },
              ),
              if (profile?.localOnly == true) ...[
                const SizedBox(height: 12),
                Text(
                  'Device workspace · Saved on this phone',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (profile != null) ...[
                const SizedBox(height: 16),
                FirstTimeUserGuidePrompt(uid: profile.uid),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Today at a glance', style: theme.textTheme.titleLarge),
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
                label: 'New bill',
              ),
              HynerSecondaryButton(
                onPressed: () =>
                    openWorkspacePage(GoRouter.of(context), '/quickprice'),
                icon: Icons.calculate_outlined,
                label: 'Quick price',
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
        const SizedBox(height: 28),
        Text('Needs attention', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        HynerSurface(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: _AttentionItems(
            report: allTimeReport,
            stock: stock,
            onRetry: () {
              ref.invalidate(businessReportProvider(allTimeQuery));
              ref.invalidate(inventoryProvider);
            },
          ),
        ),
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
                      for (final sale in sales.take(3))
                        _RecentBillRow(sale: sale),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => openWorkspacePage(GoRouter.of(context), '/reports'),
          icon: const Icon(Icons.bar_chart_rounded),
          label: const Text('Open reports'),
        ),
        const SizedBox(height: 20),
        DisclosureSection(
          title: 'Business summary',
          summary: 'Earnings and activity details',
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
                  const SizedBox(height: 16),
                  ActivityBarChart(report: report),
                  const SizedBox(height: 16),
                  PaymentDonutChart(report: report),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
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
        final figures = <Widget>[
          _FinancialFigure(
            label: 'Today’s billed sales',
            amount: formatBigMoney(report.revenueMinor, report.currency),
          ),
          _FinancialFigure(
            label: 'Cost of items sold',
            amount: formatBigMoney(report.costOfGoodsMinor, report.currency),
          ),
          _FinancialFigure(
            label: 'Gross profit before expenses',
            amount: formatBigMoney(report.grossProfitMinor, report.currency),
          ),
          _FinancialFigure(
            label: 'Outstanding dues',
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

class _AttentionItems extends StatelessWidget {
  const _AttentionItems({
    required this.report,
    required this.stock,
    required this.onRetry,
  });
  final AsyncValue<BusinessReport> report;
  final InventoryState stock;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final lowStock = stock.products.where((product) => product.isLowStock);
    final hasDue =
        report.asData?.value.unpaidRevenueMinor != null &&
        report.asData!.value.unpaidRevenueMinor > BigInt.zero;
    final items = <Widget>[];
    if (lowStock.isNotEmpty) {
      items.add(
        _AttentionRow(
          icon: Icons.warning_amber_rounded,
          title: 'Low-stock products need review',
          onTap: () => openWorkspacePage(GoRouter.of(context), '/inventory'),
        ),
      );
    }
    if (hasDue) {
      items.add(
        _AttentionRow(
          icon: Icons.pending_actions_outlined,
          title: 'Customer bills have an outstanding balance',
          onTap: () =>
              openWorkspacePage(GoRouter.of(context), '/sales/remaining'),
        ),
      );
    }
    if (report.hasError || stock.failure != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...items,
          Row(
            children: [
              const Expanded(child: Text('Some alerts could not be checked.')),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ],
      );
    }
    if (items.isEmpty) {
      final stillChecking = stock.loading || report.isLoading;
      return Text(
        stillChecking
            ? 'Checking stock and balances…'
            : 'Nothing needs attention right now.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return Column(children: items);
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: scheme.tertiary),
      title: Text(title),
      trailing: Icon(Icons.chevron_right_rounded, color: scheme.primary),
      onTap: onTap,
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
    final status = switch (sale.paymentStatus) {
      PaymentStatus.paid => 'Paid',
      PaymentStatus.partial => 'Part paid',
      PaymentStatus.unpaid => 'Due',
    };
    return Semantics(
      button: true,
      label:
          '${customer?.isNotEmpty == true ? customer : 'Walk-in customer'}, '
          '${formatMoney(sale.draft.totalMinor, sale.draft.currency)}, $status',
      child: InkWell(
        onTap: () =>
            context.push<void>('/sales/${Uri.encodeComponent(sale.id)}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
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
                    const SizedBox(height: 4),
                    HynerStatusBadge(
                      label: status,
                      icon: sale.paymentStatus == PaymentStatus.paid
                          ? Icons.check_circle_outline_rounded
                          : Icons.schedule_rounded,
                      color: sale.paymentStatus == PaymentStatus.paid
                          ? theme.extension<HynerStatusColors>()?.success
                          : theme.extension<HynerStatusColors>()?.warning,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: FinancialAmount(
                  formatMoney(sale.draft.totalMinor, sale.draft.currency),
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
