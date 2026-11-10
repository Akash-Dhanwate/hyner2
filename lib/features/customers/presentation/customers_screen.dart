import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/page_content.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../domain/customer.dart';
import 'customer_directory.dart';
import 'customers_controller.dart';
import '../../inventory/presentation/inventory_controller.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _search = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final uid = ref.read(inventoryUidProvider);
    if (uid == null || _adding) return;
    setState(() => _adding = true);
    try {
      final draft = await showDialog<CustomerDraft>(
        context: context,
        builder: (_) => const _CustomerDialog(),
      );
      if (draft == null || !mounted || ref.read(inventoryUidProvider) != uid) {
        return;
      }
      await ref.read(customerRepositoryProvider).save(uid, draft);
      if (!mounted || ref.read(inventoryUidProvider) != uid) return;
      ref.invalidate(customersProvider);
      await LocalNotificationService.instance.activity(
        title: 'Customer added',
        body: 'A customer profile was saved to your register.',
      );
    } on FormatException catch (error) {
      if (!mounted || ref.read(inventoryUidProvider) != uid) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted || ref.read(inventoryUidProvider) != uid) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer details could not be saved.')),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(inventoryUidProvider, (previous, next) {
      if (previous != next) setState(_search.clear);
    });
    final uid = ref.watch(inventoryUidProvider);
    final customers = ref.watch(customersProvider);
    final theme = Theme.of(context);
    return SliverPageContent(
      onRefresh: () => ref.refresh(customersProvider.future),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Saved on this device'),
          const SizedBox(height: 12),
          Text('Customers', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text('Customer names and contact details stay on this device.'),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('add-customer'),
            onPressed: uid == null || _adding ? null : _add,
            icon: const Icon(Icons.person_add_alt_rounded),
            label: const Text('Add customer'),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('customer-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Search customers',
              helperText: 'Name, phone, customer ID or added date (DD/MM/YYYY)',
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear customer search',
                      onPressed: () => setState(_search.clear),
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          ),
        ],
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: customers.when(
            skipLoadingOnReload: false,
            loading: () =>
                const SliverToBoxAdapter(child: LinearProgressIndicator()),
            error: (_, _) => const SliverToBoxAdapter(
              child: InlineNotice(
                'Customers could not be loaded.',
                isError: true,
              ),
            ),
            data: (allItems) {
              final items = allItems
                  .where(
                    (item) => matchesCustomerDirectoryQuery(item, _search.text),
                  )
                  .toList();
              return items.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          allItems.isEmpty
                              ? 'No customers saved yet.'
                              : 'No customers match your search.',
                        ),
                      ),
                    )
                  : SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final customer = items[index];
                        final details = [
                          if (customer.phone.isNotEmpty) customer.phone,
                          'Customer ID: ${customer.reference}',
                          'Added: ${customerAddedDate(customer.createdAt)}',
                          if (customer.address.isNotEmpty) customer.address,
                          if (customer.whatsappOptIn)
                            'WhatsApp updates allowed',
                          if (customer.notes.isNotEmpty) customer.notes,
                        ].join(' · ');
                        return ListTile(
                          key: ValueKey('customer-${customer.id}'),
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            child: Text(
                              customer.name.isEmpty
                                  ? '?'
                                  : customer.name.characters.first
                                        .toUpperCase(),
                            ),
                          ),
                          title: Text(customer.name),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push<void>(
                            '/customers/${Uri.encodeComponent(customer.id)}',
                          ),
                          subtitle: Text(details),
                        );
                      },
                    );
            },
          ),
        ),
      ],
    );
  }
}

class _CustomerDialog extends StatefulWidget {
  const _CustomerDialog();
  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  final _address = TextEditingController();
  String? _error;
  bool _whatsappOptIn = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    final draft = CustomerDraft(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      notes: _notes.text.trim(),
      address: _address.text.trim(),
      whatsappOptIn: _whatsappOptIn,
    );
    try {
      draft.validate();
      Navigator.of(context).pop(draft);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add customer'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Customer name'),
          ),
          TextField(
            controller: _phone,
            maxLength: 40,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
          ),
          TextField(
            controller: _notes,
            maxLength: 500,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          TextField(
            controller: _address,
            maxLength: 240,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Address (optional)'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _whatsappOptIn,
            onChanged: (value) =>
                setState(() => _whatsappOptIn = value == true),
            title: const Text('WhatsApp product updates allowed'),
            subtitle: const Text(
              'Only include customers who agreed to receive updates.',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save customer')),
    ],
  );
}
