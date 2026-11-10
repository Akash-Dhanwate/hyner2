import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/page_content.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customers_controller.dart';
import '../../inventory/domain/inventory_repository.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../sales/domain/sale.dart';
import '../../sales/presentation/sales_controller.dart';

const _whatsAppChannel = MethodChannel('hyner/whatsapp');

final whatsAppProductsProvider = FutureProvider.autoDispose<List<Product>>((
  ref,
) async {
  final uid = ref.watch(inventoryUidProvider);
  if (uid == null) return const [];
  final repository = ref.watch(inventoryRepositoryProvider);
  final products = <Product>[];
  InventoryCursor? cursor;
  do {
    final page = await repository.list(
      uid,
      const InventoryQuery(),
      after: cursor,
    );
    if (!ref.mounted) return const [];
    products.addAll(page.products.where((product) => !product.archived));
    cursor = page.next;
  } while (cursor != null);
  return products;
});

class WhatsAppScreen extends ConsumerStatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  ConsumerState<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends ConsumerState<WhatsAppScreen> {
  final _message = TextEditingController();
  final _videoLink = TextEditingController();
  final _selectedCustomers = <String>{};
  String? _selectedSku;
  List<Customer> _campaignQueue = const [];
  String _campaignMessage = '';
  int _queueIndex = 0;
  bool _customSelection = false;
  bool _opening = false;
  int _generation = 0;
  final _removing = <String>{};

  bool _current(String uid, int generation) =>
      mounted &&
      generation == _generation &&
      ref.read(inventoryUidProvider) == uid;
  String? _notice;
  bool _noticeIsError = false;

  @override
  void dispose() {
    _message.dispose();
    _videoLink.dispose();
    super.dispose();
  }

  bool _savingPreferences = false;

  Future<void> _setUpdates(List<Customer> customers, bool enabled) async {
    final uid = ref.read(inventoryUidProvider);
    if (uid == null || _savingPreferences) return;
    final generation = _generation;
    setState(() => _savingPreferences = true);
    try {
      for (final customer in customers) {
        if (!_current(uid, generation)) return;
        if (customer.whatsappOptIn == enabled) continue;
        await ref
            .read(customerRepositoryProvider)
            .save(
              uid,
              CustomerDraft(
                name: customer.name,
                phone: customer.phone,
                address: customer.address,
                notes: customer.notes,
                whatsappOptIn: enabled,
              ),
              id: customer.id,
            );
      }
    } catch (error) {
      if (_current(uid, generation)) {
        setState(() {
          _notice = AppFailure.from(error).displayMessage;
          _noticeIsError = true;
        });
      }
    } finally {
      if (_current(uid, generation)) {
        ref.invalidate(customersProvider);
        ref.invalidate(customerProvider);
        setState(() {
          _savingPreferences = false;
          _campaignQueue = const [];
          _queueIndex = 0;
          if (enabled && customers.length > 1) {
            _customSelection = false;
            _selectedCustomers.clear();
          }
        });
      }
    }
  }

  Set<String> _recipientIds(List<Customer> customers) {
    final eligible = customers
        .where(
          (customer) => customer.whatsappOptIn && customer.phone.isNotEmpty,
        )
        .map((customer) => customer.id)
        .toSet();
    return _customSelection
        ? _selectedCustomers.intersection(eligible)
        : eligible;
  }

  String _makeMessage(Product? product) {
    final body = _message.text.trim();
    final lines = <String>[];
    if (body.isNotEmpty) {
      lines.add(body);
    } else if (product != null) {
      lines.add('Product update: ${product.name}');
      lines.add('Price: ${formatMoney(product.priceMinor, product.currency)}');
      for (final parameter in product.parameters) {
        lines.add('${parameter.name}: ${parameter.value}');
      }
    }
    final link = _videoLink.text.trim();
    if (link.isNotEmpty) lines.add('Details: $link');
    return lines.join('\n');
  }

  Future<bool> _openChat(
    String uid,
    int generation,
    String phone,
    String message,
  ) async {
    try {
      await _whatsAppChannel.invokeMethod<void>('openChat', {
        'phone': phone,
        'message': message,
      });
      return _current(uid, generation);
    } catch (error) {
      if (!_current(uid, generation)) return false;
      setState(() {
        _notice = error is MissingPluginException
            ? 'WhatsApp chat is available in the Android app.'
            : error is PlatformException
            ? error.message ?? 'WhatsApp could not be opened.'
            : AppFailure.from(error).displayMessage;
        _noticeIsError = true;
      });
      return false;
    }
  }

  Future<void> _startCampaign(
    List<Customer> customers,
    Product? product,
  ) async {
    if (_opening ||
        _savingPreferences ||
        ref.read(inventoryUidProvider) == null) {
      return;
    }
    final recipients = _recipientIds(customers)
        .map(
          (id) => customers.where((customer) => customer.id == id).firstOrNull,
        )
        .whereType<Customer>()
        .where(
          (customer) => customer.whatsappOptIn && customer.phone.isNotEmpty,
        )
        .toList();
    if (recipients.isEmpty) {
      setState(() {
        _notice = 'Select at least one customer with WhatsApp updates enabled and a phone number.';
        _noticeIsError = true;
      });
      return;
    }
    final message = _makeMessage(product);
    if (message.trim().isEmpty) {
      setState(() {
        _notice = 'Enter a message or choose a product to create an update.';
        _noticeIsError = true;
      });
      return;
    }
    setState(() {
      _campaignQueue = recipients;
      _campaignMessage = message;
      _queueIndex = 0;
      _notice = 'WhatsApp opens one customer at a time. Review and send each message in WhatsApp.';
      _noticeIsError = false;
    });
    await _openNextCampaignMessage();
  }

  Future<void> _openNextCampaignMessage() async {
    if (_opening || _queueIndex >= _campaignQueue.length) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    final generation = _generation;
    final queued = _campaignQueue[_queueIndex];
    final customers = ref.read(customersProvider);
    final customer = customers.isLoading || customers.hasError
        ? null
        : customers.value
              ?.where(
                (item) =>
                    item.id == queued.id &&
                    item.whatsappOptIn &&
                    item.phone.isNotEmpty,
              )
              .firstOrNull;
    if (customer == null) {
      setState(() {
        _notice = 'This recipient is no longer available for WhatsApp updates. Review the customer list and start again.';
        _noticeIsError = true;
        _campaignQueue = const [];
        _queueIndex = 0;
      });
      return;
    }
    setState(() => _opening = true);
    try {
      final opened = await _openChat(
        uid,
        generation,
        customer.phone,
        _campaignMessage,
      );
      if (!_current(uid, generation)) return;
      if (opened) setState(() => _queueIndex++);
    } finally {
      if (_current(uid, generation)) setState(() => _opening = false);
    }
  }

  Future<void> _sendFollowUp(Sale sale) async {
    if (_opening) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    final generation = _generation;
    final phone = sale.draft.customerPhone ?? '';
    final customerName = sale.draft.customerName ?? 'there';
    if (phone.trim().isEmpty || sale.remainingMinor <= 0) return;
    final reference = sale.id.substring(
      0,
      sale.id.length < 8 ? sale.id.length : 8,
    );
    final message =
        'Hi $customerName, a balance of ${formatMoney(sale.remainingMinor, sale.draft.currency)} remains on bill $reference. Please contact us when you are ready to complete payment.';
    setState(() => _opening = true);
    try {
      await _openChat(uid, generation, phone, message);
    } finally {
      if (_current(uid, generation)) setState(() => _opening = false);
    }
  }

  Future<void> _markFollowUpDone(Sale sale) async {
    if (_removing.contains(sale.id)) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    final generation = _generation;
    setState(() => _removing.add(sale.id));
    try {
      await ref.read(salesRepositoryProvider).setFollowUp(uid, sale.id, null);
      if (!_current(uid, generation)) return;
      ref.invalidate(scheduledFollowUpsProvider);
      ref.invalidate(saleProvider(sale.id));
      setState(() {
        _notice = 'Follow-up removed from the queue.';
        _noticeIsError = false;
      });
    } catch (error) {
      if (!_current(uid, generation)) return;
      setState(() {
        _notice = AppFailure.from(error).displayMessage;
        _noticeIsError = true;
      });
    } finally {
      if (_current(uid, generation)) setState(() => _removing.remove(sale.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(inventoryUidProvider, (previous, next) {
      if (previous == next) return;
      setState(() {
        _generation++;
        _opening = false;
        _savingPreferences = false;
        _removing.clear();
        _selectedCustomers.clear();
        _customSelection = false;
        _selectedSku = null;
        _campaignQueue = const [];
        _campaignMessage = '';
        _queueIndex = 0;
        _message.clear();
        _videoLink.clear();
        _notice = null;
        _noticeIsError = false;
      });
    });
    final uid = ref.watch(inventoryUidProvider);
    final customersAsync = ref.watch(customersProvider);
    final productsAsync = ref.watch(whatsAppProductsProvider);
    final followupsAsync = ref.watch(scheduledFollowUpsProvider);
    final theme = Theme.of(context);
    final customers = customersAsync.isLoading || customersAsync.hasError
        ? const <Customer>[]
        : customersAsync.value ?? const <Customer>[];
    final products = productsAsync.isLoading || productsAsync.hasError
        ? const <Product>[]
        : productsAsync.value ?? const <Product>[];
    final selectedIds = _recipientIds(customers);
    final optedInCustomerIds = customers
        .where(
          (customer) => customer.whatsappOptIn && customer.phone.isNotEmpty,
        )
        .map((customer) => customer.id)
        .toSet();
    final product = products
        .where((item) => item.sku == _selectedSku)
        .firstOrNull;
    final dueNow = DateTime.now();
    return SliverPageContent(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Customer communication'),
          const SizedBox(height: 10),
          Text('WhatsApp updates', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          const DetailHint(
            'Prepare product messages and payment follow-ups for customers who have a saved phone number.',
          ),
          if (_notice != null) ...[
            const SizedBox(height: 14),
            InlineNotice(_notice!, isError: _noticeIsError),
          ],
          const SizedBox(height: 24),
          Text('Product update', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          productsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const InlineNotice(
                  'Inventory products could not be loaded.',
                  isError: true,
                ),
                TextButton(
                  onPressed: () => ref.invalidate(whatsAppProductsProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
            data: (items) => DropdownButtonFormField<String?>(
              key: ValueKey((
                uid,
                items.any((item) => item.sku == _selectedSku)
                    ? _selectedSku
                    : null,
              )),
              initialValue: items.any((item) => item.sku == _selectedSku)
                  ? _selectedSku
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Product (optional)',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Write a general update'),
                ),
                for (final item in items)
                  DropdownMenuItem<String?>(
                    value: item.sku,
                    child: Text(
                      '${item.name} · ${formatMoney(item.priceMinor, item.currency)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _selectedSku = value),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            maxLength: 800,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Message (optional with a product selected)',
              hintText: 'Add an offer, stock note, or a personal message.',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _videoLink,
            keyboardType: TextInputType.url,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Video or product link (optional)',
            ),
          ),
          const SizedBox(height: 8),
          Text('Recipients', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          const DetailHint(
            'Customers have updates enabled by default. Use the switches here to change their saved preference; use the checkboxes to choose recipients for this message.',
            title: 'WhatsApp recipients',
          ),
          TextButton.icon(
            onPressed: _savingPreferences || uid == null || _opening
                ? null
                : () => _setUpdates(customers, true),
            icon: const Icon(Icons.done_all_rounded),
            label: Text(
              _savingPreferences
                  ? 'Saving preferences…'
                  : 'Enable updates for all customers',
            ),
          ),
        ],
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: customersAsync.when(
            loading: () =>
                const SliverToBoxAdapter(child: LinearProgressIndicator()),
            error: (_, _) => SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InlineNotice(
                    'Customers could not be loaded.',
                    isError: true,
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(customersProvider),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
            data: (items) => items.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Add customers before sending updates.'),
                    ),
                  )
                : SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final customer = items[index];
                      return Column(
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(customer.name),
                            subtitle: Text(
                              customer.whatsappOptIn
                                  ? 'Updates enabled'
                                  : 'Updates disabled',
                            ),
                            value: customer.whatsappOptIn,
                            onChanged:
                                _savingPreferences || _opening || uid == null
                                ? null
                                : (enabled) => _setUpdates([customer], enabled),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: selectedIds.contains(customer.id),
                            onChanged:
                                !customer.whatsappOptIn ||
                                    customer.phone.isEmpty
                                ? null
                                : (checked) => setState(() {
                                    if (!_customSelection) {
                                      _selectedCustomers
                                        ..clear()
                                        ..addAll(_recipientIds(items));
                                    }
                                    _customSelection = true;
                                    if (checked == true) {
                                      _selectedCustomers.add(customer.id);
                                    } else {
                                      _selectedCustomers.remove(customer.id);
                                    }
                                  }),
                            title: const Text('Include in this message'),
                            subtitle: Text(
                              customer.phone.isEmpty
                                  ? 'Add a phone number to enable WhatsApp'
                                  : customer.whatsappOptIn
                                  ? customer.phone
                                  : 'Not opted in for product updates',
                            ),
                          ),
                          const Divider(),
                        ],
                      );
                    },
                  ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      _opening ||
                          _savingPreferences ||
                          uid == null ||
                          customersAsync.isLoading ||
                          customersAsync.hasError
                      ? null
                      : () => _startCampaign(customers, product),
                  icon: const Icon(Icons.send_rounded),
                  label: Text(
                    'Open WhatsApp for ${selectedIds.length} selected',
                  ),
                ),
                if (_queueIndex < _campaignQueue.length) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Message ${_queueIndex + 1} of ${_campaignQueue.length} is ready. Send it in WhatsApp, return here, then continue.',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _opening || uid == null
                        ? null
                        : _openNextCampaignMessage,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(
                      'Open next: ${_campaignQueue[_queueIndex].name}',
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 22),
                Text('Payment follow-ups', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                const DetailHint(
                  'Scheduled reminders appear here. Open the WhatsApp draft and send it yourself; Hyner does not send messages in the background.',
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        followupsAsync.when(
          loading: () => const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(child: LinearProgressIndicator()),
          ),
          error: (_, _) => SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InlineNotice(
                    'Follow-ups could not be loaded.',
                    isError: true,
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(scheduledFollowUpsProvider),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
          data: (sales) {
            final eligibleSales = sales
                .where(
                  (sale) => optedInCustomerIds.contains(sale.draft.customerId),
                )
                .toList();
            if (eligibleSales.isEmpty) {
              return const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: Text('No payment follow-ups are scheduled.'),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.separated(
                itemCount: eligibleSales.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final sale = eligibleSales[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(sale.draft.customerName ?? 'Customer'),
                    subtitle: Text(
                      '${sale.followupAt == null ? 'No date' : saleDate(sale.followupAt!)} · ${sale.followupAt != null && !sale.followupAt!.isAfter(dueNow) ? 'Due now' : 'Upcoming'} · ${formatMoney(sale.remainingMinor, sale.draft.currency)} due',
                    ),
                    trailing: PopupMenuButton<String>(
                      enabled:
                          !_opening &&
                          !_removing.contains(sale.id) &&
                          uid != null,
                      onSelected: (action) {
                        if (action == 'open') _sendFollowUp(sale);
                        if (action == 'done') _markFollowUpDone(sale);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'open',
                          child: Text('Open WhatsApp draft'),
                        ),
                        PopupMenuItem(
                          value: 'done',
                          child: Text('Remove reminder'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
          sliver: SliverToBoxAdapter(
            child: InlineNotice(
              'Bulk campaigns and automatic WhatsApp sending require the WhatsApp Business Platform. This screen opens one customer chat at a time and requires you to tap Send.',
            ),
          ),
        ),
      ],
    );
  }
}
