import '../../../core/widgets/financial_amount.dart';
import '../../../core/widgets/document_action_button.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../core/widgets/page_content.dart';
import '../../../core/widgets/workspace_components.dart';
import '../../auth/presentation/session_controller.dart';
import '../../inventory/domain/product.dart';
import '../data/report_pdf_service.dart';
import '../domain/business_report.dart';
import 'report_charts.dart';
import 'reports_controller.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _currency = 'INR';
  ReportPeriod _period = ReportPeriod.month;

  ReportQuery _query() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime start = switch (_period) {
      ReportPeriod.today => today,
      ReportPeriod.month => DateTime(now.year, now.month, 1),
      ReportPeriod.last30Days => today.subtract(const Duration(days: 29)),
      ReportPeriod.allTime => DateTime(1970, 1, 1),
    };
    return ReportQuery(
      currency: _currency,
      period: _period,
      start: start,
      endExclusive: today.add(const Duration(days: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _query();
    final report = ref.watch(businessReportProvider(query));
    final profile = ref.watch(sessionProvider).profile;
    final theme = Theme.of(context);
    return PageContent(
      children: [
        const Eyebrow('Business overview'),
        const SizedBox(height: 12),
        Text('Reports', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('View sales, purchases, balances, and product performance.'),
        const SizedBox(height: 20),
        ResponsivePair(
          first: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: [
              for (final currency in inventoryCurrencies)
                DropdownMenuItem(value: currency, child: Text(currency)),
            ],
            onChanged: (value) =>
                setState(() => _currency = value ?? _currency),
          ),
          second: DropdownButtonFormField<ReportPeriod>(
            isExpanded: true,
            initialValue: _period,
            decoration: const InputDecoration(labelText: 'Period'),
            items: const [
              DropdownMenuItem(value: ReportPeriod.today, child: Text('Today')),
              DropdownMenuItem(
                value: ReportPeriod.month,
                child: Text('This month'),
              ),
              DropdownMenuItem(
                value: ReportPeriod.last30Days,
                child: Text('Last 30 days'),
              ),
              DropdownMenuItem(
                value: ReportPeriod.allTime,
                child: Text('All time'),
              ),
            ],
            onChanged: (value) => setState(() => _period = value ?? _period),
          ),
        ),
        const SizedBox(height: 24),
        report.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const InlineNotice(
                'Reports could not be loaded from local records.',
                isError: true,
              ),
              TextButton(
                onPressed: () => ref.invalidate(businessReportProvider(query)),
                child: const Text('Retry reports'),
              ),
            ],
          ),
          data: (data) => _ReportContent(
            report: data,
            monthly: _period == ReportPeriod.month,
            preparedFor: profile?.label ?? 'Business owner',
          ),
        ),
      ],
    );
  }
}

class _ReportContent extends StatefulWidget {
  const _ReportContent({
    required this.report,
    required this.preparedFor,
    required this.monthly,
  });
  final bool monthly;
  final BusinessReport report;
  final String preparedFor;

  @override
  State<_ReportContent> createState() => _ReportContentState();
}

class _ReportContentState extends State<_ReportContent> {
  bool _exporting = false;
  BusinessReport get report => widget.report;
  bool get monthly => widget.monthly;

  Future<void> _downloadPdf(BuildContext context) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final now = DateTime.now();
    final capturedReport = report;
    final preparedFor = widget.preparedFor;
    try {
      await Printing.layoutPdf(
        name:
            'hyner-activity-${now.year}-${now.month.toString().padLeft(2, '0')}.pdf',
        onLayout: (_) => ReportPdfService.build(
          capturedReport,
          preparedFor: preparedFor,
          generatedAt: now,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The PDF report could not be created.')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          report.hasIncompleteCosts
              ? 'Known-cost earnings'
              : 'Earnings after costs',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        FinancialAmount(
          formatBigMoney(report.earningsAfterCostsMinor, report.currency),
          textKey: const Key('report-earnings'),
          style: theme.textTheme.headlineMedium,
          prominent: true,
        ),
        Text(
          'After buying costs and recorded operating expenses',
          style: theme.textTheme.bodySmall,
        ),
        if (report.hasIncompleteCosts)
          Text(
            'Incomplete: ${report.uncostedSalesCount} bills have no saved buying costs.',
            style: theme.textTheme.bodySmall,
          ),
        DetailHint(
          'Gross profit is the selling amount less the buying cost saved on each bill. Earnings subtract recorded operating expenses as well. Stock purchases are not deducted twice. Bills without saved costs are excluded; this is an estimate, not your cash balance.',
          title: 'Earnings calculation',
        ),
        const SizedBox(height: 12),
        const Eyebrow('Sales'),
        const SizedBox(height: 8),
        _Metric(
          'Sales revenue',
          formatBigMoney(report.revenueMinor, report.currency),
          '${report.salesCount} bills · ${report.soldUnits} units',
        ),
        _Metric(
          'Payment received',
          formatBigMoney(report.paidRevenueMinor, report.currency),
          'Recorded payments on bills in this period',
        ),
        _Metric(
          'Balance due',
          formatBigMoney(report.unpaidRevenueMinor, report.currency),
          '${report.unpaidSalesCount} open bills',
        ),
        const SizedBox(height: 12),
        ActivityBarChart(report: report),
        const SizedBox(height: 14),
        PaymentDonutChart(report: report),
        const SizedBox(height: 18),
        Text('Recent sales', style: theme.textTheme.titleMedium),
        if (report.salesRecords.isEmpty) const Text('No bills in this period.'),
        for (final record in report.salesRecords.take(3))
          InkWell(
            onTap: () => context.push<void>(
              '/sales/${Uri.encodeComponent(record.reference)}',
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.customer, style: theme.textTheme.titleSmall),
                  Text(
                    '${record.reference} · ${record.date.toLocal().toString().substring(0, 10)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  FinancialAmount(
                    formatBigMoney(record.totalMinor, report.currency),
                    compact: true,
                  ),
                ],
              ),
            ),
          ),
        TextButton(
          onPressed: () => context.push<void>('/sales/history', extra: ''),
          child: const Text('View all bills'),
        ),
        const SizedBox(height: 18),
        Text(
          monthly ? 'Monthly highlights' : 'Period highlights',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Sales revenue '),
              TextSpan(
                text: formatBigMoney(report.revenueMinor, report.currency),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' from '),
              TextSpan(
                text: '${report.salesCount} bills',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ', with '),
              TextSpan(
                text: formatBigMoney(
                  report.unpaidRevenueMinor,
                  report.currency,
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' due.'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: DocumentActionButton(
            key: const Key('download-report-pdf'),
            primary: true,
            onPressed: _exporting ? null : () => _downloadPdf(context),
            icon: Icons.download_outlined,
            label: _exporting ? 'Preparing PDF…' : 'Save or print PDF',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'PDF · Opens the print and save dialog.',
          style: theme.textTheme.bodySmall,
        ),
        if (_exporting)
          const LinearProgressIndicator(semanticsLabel: 'Preparing report PDF'),
        const SizedBox(height: 22),
        DisclosureSection(
          title: 'Profit and stock',
          maintainState: false,
          summary: 'Cost snapshots and current stock value',
          children: [
            const SizedBox(height: 8),
            _Metric(
              'Gross profit before expenses',
              formatBigMoney(report.grossProfitMinor, report.currency),
              'From bills with saved product costs',
            ),
            _Metric(
              'Cost of goods sold',
              formatBigMoney(report.costOfGoodsMinor, report.currency),
              'From cost captured when each bill was saved',
            ),
            _Metric(
              'Current inventory value',
              formatBigMoney(report.inventoryValueMinor, report.currency),
              'Current stock × weighted-average cost',
            ),
            if (report.uncostedSalesCount > 0) ...[
              const SizedBox(height: 8),
              InlineNotice(
                '${report.uncostedSalesCount} bills have no saved cost snapshot. Gross profit excludes those bills.',
              ),
            ],
          ],
        ),
        DisclosureSection(
          title: 'Purchases and expenses',
          maintainState: false,
          summary: 'Supplier spending, returns and running costs',
          children: [
            const SizedBox(height: 8),
            _Metric(
              'Purchases recorded',
              formatBigMoney(report.purchaseSpendMinor, report.currency),
              '${report.purchaseCount} purchase records',
            ),
            _Metric(
              'Returns to suppliers',
              formatBigMoney(report.returnValueMinor, report.currency),
              'Returns recorded in this period',
            ),
            _Metric(
              'Net purchase spend',
              formatBigMoney(report.netPurchasesMinor, report.currency),
              'Purchase records less supplier returns',
            ),
            _Metric(
              'Operating expenses',
              formatBigMoney(report.operatingExpensesMinor, report.currency),
              '${report.otherExpenseCount} manually entered expenses',
            ),
            _Metric(
              'Total recorded expenses',
              formatBigMoney(report.totalExpenseMinor, report.currency),
              'Net purchases plus operating expenses',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push<void>('/expenses'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Record an expense'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Eyebrow('Top five products by revenue'),
        const SizedBox(height: 8),
        if (report.topProducts.isEmpty)
          const Text('No sales in this period.')
        else
          for (final product in report.topProducts) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text('${product.units} units'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FinancialAmount(
                    formatBigMoney(product.revenueMinor, report.currency),
                    compact: true,
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        const SizedBox(height: 12),
        const Text(
          'Operational summary only - not an accounting statement or tax filing.',
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.detail);
  final String label, value, detail;

  @override
  Widget build(BuildContext context) {
    return RecordFact(label: label, value: value, detail: detail);
  }
}
