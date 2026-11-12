import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../inventory/domain/product.dart';
import '../domain/sale.dart';
import 'sales_controller.dart';

class BillSummary extends StatelessWidget {
  const BillSummary({super.key, required this.sale});
  final Sale sale;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = sale.draft.customerName?.trim();
    return InkWell(
      key: ValueKey('sale-${sale.id}'),
      onTap: () => context.push<void>('/sales/${Uri.encodeComponent(sale.id)}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name?.isNotEmpty == true ? name! : 'Walk-in customer',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            if (sale.draft.customerPhone?.isNotEmpty == true)
              Text(sale.draft.customerPhone!, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              '${saleDate(sale.createdAt)} · ${sale.paymentStatus == PaymentStatus.paid
                  ? 'Paid'
                  : sale.paymentStatus == PaymentStatus.partial
                  ? 'Part paid'
                  : 'Payment pending'}',
              style: theme.textTheme.bodySmall,
            ),
            Text('Ref: ${sale.id}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              formatMoney(sale.draft.totalMinor, sale.draft.currency),
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class RecentBills extends ConsumerStatefulWidget {
  const RecentBills({super.key});
  @override
  ConsumerState<RecentBills> createState() => _RecentBillsState();
}

class _RecentBillsState extends ConsumerState<RecentBills> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open({bool search = false}) => context.push<void>(
    Uri(
      path: '/sales/history',
      queryParameters: {'search': search ? _search.text.trim() : ''},
    ).toString(),
  );
  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentSalesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text(
              'Recent bills',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton(onPressed: _open, child: const Text('Saved bills')),
          ],
        ),
        TextField(
          key: const Key('recent-bill-search'),
          controller: _search,
          maxLength: 120,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Find a bill',
            hintText: 'Customer, mobile or bill amount',
            counterText: '',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: 'Search saved bills',
              onPressed: () => _open(search: true),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
          onSubmitted: (_) => _open(search: true),
        ),
        recent.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(recentSalesProvider),
            child: const Text('Retry recent bills'),
          ),
          data: (sales) => sales.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Your last three bills will appear here.'),
                )
              : Column(
                  children: [
                    for (final sale in sales) ...[
                      BillSummary(sale: sale),
                      const Divider(),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
