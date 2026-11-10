import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_content.dart';
import '../domain/customer.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../sales/domain/sale.dart';
import 'customer_directory.dart';
import 'customers_controller.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.id});
  final String id;

  Future<void> _setWhatsAppConsent(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    final consent = !customer.whatsappOptIn;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          consent ? 'Allow product updates?' : 'Stop product updates?',
        ),
        content: Text(
          consent
              ? 'This customer will be available in the WhatsApp product update list.'
              : 'This customer will be excluded from WhatsApp product updates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(consent ? 'Allow updates' : 'Stop updates'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !context.mounted ||
        ref.read(inventoryUidProvider) != uid) {
      return;
    }
    try {
      await ref
          .read(customerRepositoryProvider)
          .save(
            uid,
            CustomerDraft(
              name: customer.name,
              phone: customer.phone,
              notes: customer.notes,
              address: customer.address,
              whatsappOptIn: consent,
            ),
            id: customer.id,
          );
      if (!context.mounted || ref.read(inventoryUidProvider) != uid) return;
      ref.invalidate(customerProvider(id));
      ref.invalidate(customersProvider);
    } catch (_) {
      if (!context.mounted || ref.read(inventoryUidProvider) != uid) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp preferences could not be saved.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(customerProvider(id));
    final sales = ref.watch(customerSalesProvider(id));
    return customer.when(
      skipLoadingOnReload: false,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => PageContent(
        children: [
          const InlineNotice('Customer could not be loaded.', isError: true),
          TextButton(
            onPressed: () => ref.invalidate(customerProvider(id)),
            child: const Text('Try again'),
          ),
        ],
      ),
      data: (value) => SliverPageContent(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(customerProvider(id).future),
            ref.refresh(customerSalesProvider(id).future),
          ]);
        },
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Customer account'),
            const SizedBox(height: 12),
            Text(value.name, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            SelectableText('Customer ID: ${value.reference}'),
            Text('Added: ${customerAddedDate(value.createdAt)}'),
            const SizedBox(height: 8),
            if (value.phone.isNotEmpty) SelectableText(value.phone),
            if (value.address.isNotEmpty) SelectableText(value.address),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _setWhatsAppConsent(context, ref, value),
              icon: Icon(
                value.whatsappOptIn
                    ? Icons.notifications_off_outlined
                    : Icons.chat_outlined,
              ),
              label: Text(
                value.whatsappOptIn
                    ? 'Exclude from WhatsApp product updates'
                    : 'Allow WhatsApp product updates',
              ),
            ),
            if (value.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(value.notes),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push<void>(
                '/sales/new?customerId=${Uri.encodeComponent(value.id)}',
              ),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Build bill for this customer'),
            ),
            const SizedBox(height: 28),
            const Eyebrow('Account history'),
            const SizedBox(height: 12),
          ],
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: sales.when(
              skipLoadingOnReload: false,
              loading: () =>
                  const SliverToBoxAdapter(child: LinearProgressIndicator()),
              error: (_, _) => const SliverToBoxAdapter(
                child: InlineNotice(
                  'Customer bills could not be loaded.',
                  isError: true,
                ),
              ),
              data: (items) => SliverList.separated(
                itemCount: items.length + 1,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  if (index == 0) return _CustomerHistorySummary(items);
                  return _CustomerBill(items[index - 1]);
                },
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Payment status is recorded locally after you check your UPI app.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerHistorySummary extends StatelessWidget {
  const _CustomerHistorySummary(this.sales);
  final List<Sale> sales;

  @override
  Widget build(BuildContext context) {
    var units = 0;
    final totals = <String, int>{};
    final paid = <String, int>{};
    final due = <String, int>{};
    for (final sale in sales) {
      units += sale.draft.units;
      final currency = sale.draft.currency;
      totals.update(
        currency,
        (value) => value + sale.draft.totalMinor,
        ifAbsent: () => sale.draft.totalMinor,
      );
      paid.update(
        currency,
        (value) => value + sale.paidMinor,
        ifAbsent: () => sale.paidMinor,
      );
      due.update(
        currency,
        (value) => value + sale.remainingMinor,
        ifAbsent: () => sale.remainingMinor,
      );
    }
    final currencies = totals.keys.toList()..sort();
    return Padding(
      key: const Key('customer-history-summary'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${sales.length} ${sales.length == 1 ? 'bill' : 'bills'} · $units units',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final currency in currencies) ...[
            const SizedBox(height: 8),
            Text('Total billed: ${formatMoney(totals[currency]!, currency)}'),
            Text(
              'Paid: ${formatMoney(paid[currency]!, currency)} · '
              'Due: ${formatMoney(due[currency]!, currency)}',
            ),
          ],
          if (sales.isEmpty) ...[
            const SizedBox(height: 12),
            const Text('No bills are linked to this customer yet.'),
          ],
        ],
      ),
    );
  }
}

class _CustomerBill extends StatelessWidget {
  const _CustomerBill(this.sale);
  final Sale sale;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey('customer-bill-${sale.id}'),
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatMoney(sale.draft.totalMinor, sale.draft.currency),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text('${saleDate(sale.createdAt)} · ${sale.draft.units} units'),
        Text(
          sale.paymentStatus == PaymentStatus.paid
              ? 'Paid'
              : '${sale.paymentStatus == PaymentStatus.partial ? 'Part paid' : 'Pending'} · '
                    '${formatMoney(sale.remainingMinor, sale.draft.currency)} due',
        ),
        const SizedBox(height: 8),
        for (final line in sale.draft.lines) ...[
          Text('${line.name} · ${line.quantity} units'),
          for (final parameter in line.parameters)
            Text('${parameter.name}: ${parameter.value}'),
          const SizedBox(height: 8),
        ],
        TextButton.icon(
          onPressed: () =>
              context.push<void>('/sales/${Uri.encodeComponent(sale.id)}'),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('View bill'),
        ),
      ],
    ),
  );
}
