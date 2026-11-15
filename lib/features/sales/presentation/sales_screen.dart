import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_content.dart';
import '../../inventory/presentation/inventory_controller.dart';
import 'bill_summary.dart';
import 'sales_controller.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});
  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _search = TextEditingController();
  bool _initialSearchApplied = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialSearchApplied) return;
    _initialSearchApplied = true;
    final route = GoRouterState.of(context);
    final initial = route.extra is String
        ? route.extra as String
        : route.uri.queryParameters['search'];
    _search.text = initial ?? ref.read(salesProvider).search;
    if (initial != null) {
      final uid = ref.read(inventoryUidProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(inventoryUidProvider) == uid) {
          ref.read(salesProvider.notifier).refresh(search: initial);
        }
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submit() =>
      ref.read(salesProvider.notifier).refresh(search: _search.text);
  @override
  Widget build(BuildContext context) {
    ref.listen(inventoryUidProvider, (previous, next) {
      if (previous != next) _search.clear();
    });
    final state = ref.watch(salesProvider);
    final controller = ref.read(salesProvider.notifier);
    return SliverPageContent(
      onRefresh: controller.refresh,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Saved bills'),
                    const SizedBox(height: 10),
                    Text(
                      'Sales history',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('sales-bill-preferences'),
                tooltip: 'Bill preferences',
                onPressed: () => context.push<void>('/bill-settings'),
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('new-sale'),
                onPressed: () => context.push<void>('/sales'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New bill'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push<void>('/sales/remaining'),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Remaining payments'),
              ),
              IconButton(
                tooltip: 'Refresh sales',
                onPressed: state.loading ? null : controller.refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('bill-search'),
            controller: _search,
            maxLength: 120,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Find a bill',
              hintText: 'Customer, mobile or bill amount',
              counterText: '',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Search bills',
                onPressed: _submit,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          if (state.search.isNotEmpty)
            TextButton(
              onPressed: () {
                _search.clear();
                controller.refresh(search: '');
              },
              child: const Text('Show all bills'),
            ),
          if (state.loading) const LinearProgressIndicator(),
          if (state.failure != null) ...[
            InlineNotice(state.failure!.displayMessage, isError: true),
            TextButton(
              onPressed: state.loadingMore
                  ? null
                  : state.sales.isEmpty
                  ? controller.refresh
                  : controller.loadMore,
              child: const Text('Try again'),
            ),
          ],
          if (!state.loading && state.failure == null && state.sales.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                state.search.isEmpty ? 'No sales yet' : 'No matching bills',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
        ],
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList.separated(
            itemCount: state.sales.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (_, index) => BillSummary(sale: state.sales[index]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          sliver: SliverToBoxAdapter(
            child: state.loadingMore
                ? const LinearProgressIndicator()
                : state.next == null
                ? const SizedBox.shrink()
                : OutlinedButton(
                    onPressed: controller.loadMore,
                    child: const Text('Load more sales'),
                  ),
          ),
        ),
      ],
    );
  }
}
