import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';

import 'dart:typed_data';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../reports/presentation/reports_controller.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/widgets/page_content.dart';
import '../../customers/presentation/customers_controller.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../settings/presentation/payment_settings_controller.dart';
import '../../settings/domain/payment_settings.dart';
import '../../inventory/presentation/inventory_feedback.dart';
import '../domain/sale.dart';
import '../data/bill_pdf_service.dart';
import '../data/bill_pdf_actions.dart';
import 'sales_controller.dart';

class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(saleProvider(id))
      .when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => InventoryFeedback(
          error: error,
          retry: () => ref.invalidate(saleProvider(id)),
        ),
        data: (sale) {
          final customerId = sale.draft.customerId;
          final whatsappOptIn =
              customerId != null &&
              ref
                  .watch(customerProvider(customerId))
                  .maybeWhen(
                    data: (customer) => customer.whatsappOptIn,
                    orElse: () => false,
                  );
          return _SaleDetail(
            key: ValueKey(
              '${sale.id}/${sale.paidMinor}/${sale.expectedPaymentMinor}',
            ),
            sale: sale,
            whatsappOptIn: whatsappOptIn,
          );
        },
      );
}

class _SaleDetail extends ConsumerStatefulWidget {
  const _SaleDetail({
    super.key,
    required this.sale,
    required this.whatsappOptIn,
  });
  final Sale sale;
  final bool whatsappOptIn;

  @override
  ConsumerState<_SaleDetail> createState() => _SaleDetailState();
}

class _SaleDetailState extends ConsumerState<_SaleDetail> {
  final _amount = TextEditingController();
  bool _saving = false;
  String? _paymentOperationId;
  int? _paymentAmount;
  bool _savingFollowUp = false;
  int _followUpDays = 5;
  AppFailure? _failure;
  Uint8List? _duplicate;
  String? _archiveError;
  bool _documentBusy = false;

  Sale get sale => widget.sale;
  bool get whatsappOptIn => widget.whatsappOptIn;

  @override
  void initState() {
    super.initState();
    _syncAmount();
    unawaited(_archiveDuplicate());
  }

  Future<void> _archiveDuplicate() async {
    final repository = ref.read(dependenciesProvider).billDocuments;
    final uid = ref.read(inventoryUidProvider);
    if (repository == null || uid == null) return;
    try {
      var bytes = await repository.duplicate(uid, sale.id);
      if (bytes == null) {
        final settings = await ref.read(paymentSettingsProvider.future);
        bytes = await BillPdfService.build(
          sale: sale,
          settings: settings,
          copy: BillCopy.duplicate,
        );
        if (!mounted || ref.read(inventoryUidProvider) != uid) return;
        await repository.saveDuplicate(uid, sale.id, bytes);
        bytes = await repository.duplicate(uid, sale.id);
      }
      if (mounted && ref.read(inventoryUidProvider) == uid) {
        setState(() {
          _duplicate = bytes;
          _archiveError = null;
        });
      }
    } catch (_) {
      if (mounted && ref.read(inventoryUidProvider) == uid) {
        setState(
          () => _archiveError =
              'The bill is saved, but its duplicate PDF could not be archived.',
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant _SaleDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sale.paidMinor != sale.paidMinor ||
        oldWidget.sale.expectedPaymentMinor != sale.expectedPaymentMinor) {
      _syncAmount();
    }
  }

  void _syncAmount() {
    final amount = sale.expectedPaymentMinor > 0
        ? sale.expectedPaymentMinor
        : sale.remainingMinor;
    _amount.text = moneyDecimal(amount);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? _parsedAmount() {
    try {
      final value = parseMoney(_amount.text);
      if (value < 1 || value > sale.remainingMinor) return null;
      return value;
    } on AppFailure {
      return null;
    }
  }

  Future<void> _recordPayment() async {
    if (_saving) return;
    final uid = ref.read(inventoryUidProvider);
    final amount = _paymentAmount ?? _parsedAmount();
    if (uid == null || amount == null) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm payment received'),
          content: Text(
            'Confirm that ${formatMoney(amount, sale.draft.currency)} was received. Hyner does not verify or process the payment.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Record payment'),
            ),
          ],
        ),
      );
      if (confirmed != true ||
          !mounted ||
          ref.read(inventoryUidProvider) != uid) {
        return;
      }
      final repository = ref.read(salesRepositoryProvider);
      _paymentOperationId ??= repository.newSaleId();
      _paymentAmount = amount;
      await repository.recordPayment(
        uid,
        sale.id,
        amount,
        operationId: _paymentOperationId,
      );
      if (!mounted || ref.read(inventoryUidProvider) != uid) return;
      _paymentOperationId = null;
      _paymentAmount = null;
      unawaited(
        LocalNotificationService.instance.activity(
          title: 'Customer payment recorded',
          body: formatMoney(amount, sale.draft.currency),
        ),
      );
      ref.invalidate(saleProvider(sale.id));
      ref.invalidate(remainingPaymentsProvider);
      ref.invalidate(customerSalesProvider);
      ref.invalidate(businessReportProvider);
      ref.invalidate(scheduledFollowUpsProvider);
      unawaited(ref.read(salesProvider.notifier).refresh());
    } catch (error) {
      if (mounted && ref.read(inventoryUidProvider) == uid) {
        setState(() => _failure = AppFailure.from(error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _scheduleFollowUp() async {
    if (_savingFollowUp) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    setState(() => _savingFollowUp = true);
    try {
      await ref
          .read(salesRepositoryProvider)
          .setFollowUp(
            uid,
            sale.id,
            DateTime.now().add(Duration(days: _followUpDays)),
          );
      if (!mounted || ref.read(inventoryUidProvider) != uid) return;
      ref.invalidate(saleProvider(sale.id));
      ref.invalidate(scheduledFollowUpsProvider);
      setState(() => _savingFollowUp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('WhatsApp follow-up scheduled in $_followUpDays days.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingFollowUp = false;
        _failure = AppFailure.from(error);
      });
    }
  }

  Future<void> _removeFollowUp() async {
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    setState(() => _savingFollowUp = true);
    try {
      await ref.read(salesRepositoryProvider).setFollowUp(uid, sale.id, null);
      if (!mounted || ref.read(inventoryUidProvider) != uid) return;
      ref.invalidate(saleProvider(sale.id));
      ref.invalidate(scheduledFollowUpsProvider);
      setState(() => _savingFollowUp = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingFollowUp = false;
        _failure = AppFailure.from(error);
      });
    }
  }

  bool _documentCurrent(String? uid) =>
      mounted && uid != null && ref.read(inventoryUidProvider) == uid;

  Future<void> _printBill(PaymentSettings settings) async {
    final uid = ref.read(inventoryUidProvider);
    if (_documentBusy || uid == null) return;
    setState(() => _documentBusy = true);
    try {
      await Printing.layoutPdf(
        name: 'hyner-original-${sale.id}.pdf',
        onLayout: (_) {
          if (!_documentCurrent(uid)) {
            throw StateError('Account changed. Reopen the bill.');
          }
          return BillPdfService.build(
            sale: sale,
            settings: settings,
            copy: BillCopy.original,
          );
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The bill could not be opened for printing.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _documentBusy = false);
    }
  }

  Future<void> _shareBill(PaymentSettings settings) async {
    final uid = ref.read(inventoryUidProvider);
    if (_documentBusy || uid == null) return;
    setState(() => _documentBusy = true);
    try {
      final bytes = await BillPdfService.build(
        sale: sale,
        settings: settings,
        copy: BillCopy.original,
      );
      if (!_documentCurrent(uid)) return;
      await BillPdfActions.shareWhatsApp(
        bytes,
        'hyner-original-${sale.id}.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The bill could not be shared.')),
        );
      }
    } finally {
      if (mounted) setState(() => _documentBusy = false);
    }
  }

  Future<void> _savePdf(
    PaymentSettings settings, {
    bool duplicate = false,
  }) async {
    final uid = ref.read(inventoryUidProvider);
    if (_documentBusy || uid == null) return;
    setState(() => _documentBusy = true);
    try {
      final bytes = duplicate
          ? (_duplicate ??
                await BillPdfService.build(
                  sale: sale,
                  settings: settings,
                  copy: BillCopy.duplicate,
                ))
          : await BillPdfService.build(
              sale: sale,
              settings: settings,
              copy: BillCopy.original,
            );
      if (!_documentCurrent(uid)) return;
      final saved = await BillPdfActions.save(
        bytes,
        'hyner-${duplicate ? 'duplicate' : 'original'}-${sale.id}.pdf',
      );
      if (mounted && saved != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill PDF saved on this device.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The PDF could not be saved. Your bill is still saved in Sales.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _documentBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = sale.remainingMinor;
    return PageContent(
      children: [
        const Eyebrow('Saved sale'),
        const SizedBox(height: 12),
        Text(
          formatMoney(sale.draft.totalMinor, sale.draft.currency),
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(saleDate(sale.createdAt)),
        const SizedBox(height: 8),
        SelectableText('Reference: ${sale.id}'),
        if (sale.draft.customerName != null) ...[
          const SizedBox(height: 8),
          Text('Customer · ${sale.draft.customerName}'),
          if (sale.draft.customerPhone?.isNotEmpty == true)
            SelectableText('Phone · ${sale.draft.customerPhone!}'),
          if (sale.draft.customerAddress?.isNotEmpty == true)
            SelectableText(sale.draft.customerAddress!),
        ],
        if (sale.draft.customerId != null)
          TextButton.icon(
            onPressed: () => context.push<void>(
              '/customers/${Uri.encodeComponent(sale.draft.customerId!)}',
            ),
            icon: const Icon(Icons.history_rounded),
            label: const Text('All customer bills'),
          ),
        const SizedBox(height: 16),
        Text('Payment', style: theme.textTheme.titleLarge),
        Text(
          sale.paymentStatus == PaymentStatus.paid
              ? 'Paid'
              : sale.paymentStatus == PaymentStatus.partial
              ? 'Part paid'
              : 'Pending',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        _MoneyFact('Received', sale.paidMinor, sale.draft.currency),
        _MoneyFact('Remaining', remaining, sale.draft.currency),
        const SizedBox(height: 16),
        DetailHint(
          sale.paymentStatus == PaymentStatus.paid
              ? 'This bill is fully paid. Payment was confirmed by the owner.'
              : sale.paymentStatus == PaymentStatus.partial
              ? 'Advance received. The remaining balance is still due.'
              : 'Payment has not been confirmed yet. The requested QR amount is not treated as paid until the owner records it.',
        ),
        const SizedBox(height: 18),
        if (sale.payments.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Payment history', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final payment in sale.payments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Text(saleDate(payment.createdAt))),
                  Text(formatMoney(payment.amountMinor, sale.draft.currency)),
                ],
              ),
            ),
        ],
        if (sale.paidAt != null &&
            sale.paymentStatus == PaymentStatus.paid) ...[
          const SizedBox(height: 8),
          Text('Fully paid · ${saleDate(sale.paidAt!)}'),
        ],
        if (remaining > 0) ...[
          const SizedBox(height: 24),
          Text('Next payment', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('sale-payment-amount'),
            controller: _amount,
            enabled: !_saving && _paymentOperationId == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'QR amount (${sale.draft.currency})',
              helperText:
                  'Up to ${formatMoney(remaining, sale.draft.currency)} remaining.',
            ),
            validator: (value) {
              try {
                final amount = parseMoney(value ?? '');
                return amount < 1 || amount > remaining
                    ? 'Enter an amount greater than zero and no more than the remaining balance.'
                    : null;
              } on AppFailure catch (error) {
                return error.message;
              }
            },
          ),
          _PaymentQr(sale: sale, amountMinor: _parsedAmount() ?? 0),
          if (_failure != null) ...[
            const SizedBox(height: 12),
            InlineNotice(_failure!.displayMessage, isError: true),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('record-sale-payment'),
              onPressed: _saving || _parsedAmount() == null
                  ? null
                  : _recordPayment,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined),
              label: Text(
                _saving
                    ? 'Saving payment…'
                    : 'I verified payment · Record ${_parsedAmount() == null ? '' : formatMoney(_parsedAmount()!, sale.draft.currency)}',
              ),
            ),
          ),
        ],
        if (remaining > 0) ...[
          if (sale.draft.customerId != null &&
              sale.draft.customerPhone?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 22),
            Text('Payment reminder', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (!whatsappOptIn)
              const DetailHint(
                'Enable WhatsApp updates from More → WhatsApp updates before scheduling a reminder.',
              )
            else ...[
              if (sale.followupAt != null) ...[
                InlineNotice(
                  'WhatsApp draft reminder scheduled for ${saleDate(sale.followupAt!)}.',
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _followUpDays,
                      decoration: const InputDecoration(
                        labelText: 'Remind after',
                      ),
                      items: const [5, 10, 12]
                          .map(
                            (days) => DropdownMenuItem(
                              value: days,
                              child: Text('$days days'),
                            ),
                          )
                          .toList(),
                      onChanged: _savingFollowUp
                          ? null
                          : (value) =>
                                setState(() => _followUpDays = value ?? 5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _savingFollowUp ? null : _scheduleFollowUp,
                    child: Text(
                      sale.followupAt == null ? 'Schedule' : 'Reschedule',
                    ),
                  ),
                ],
              ),
              if (sale.followupAt != null)
                TextButton.icon(
                  onPressed: _savingFollowUp ? null : _removeFollowUp,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Remove reminder'),
                ),
              const SizedBox(height: 4),
              const DetailHint(
                'This adds the bill to the WhatsApp follow-up queue on that date. You still open the draft and send it manually.',
              ),
            ],
          ],
        ],
        const SizedBox(height: 24),
        Text('Bill copies', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        const DetailHint(
          'WhatsApp receives only the Original. The compact Duplicate is kept locally.',
          title: 'Bill copies',
        ),
        const SizedBox(height: 10),
        ref
            .watch(paymentSettingsProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const InlineNotice(
                'Add your business details in Settings before printing a bill.',
                isError: true,
              ),
              data: (settings) => Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _documentBusy
                        ? null
                        : () => _shareBill(settings),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('WhatsApp PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _documentBusy
                        ? null
                        : () => _printBill(settings),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print original'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('save-bill-pdf'),
                    onPressed: _documentBusy ? null : () => _savePdf(settings),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Save PDF'),
                  ),
                  TextButton.icon(
                    onPressed: _documentBusy
                        ? null
                        : () => _savePdf(settings, duplicate: true),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Save duplicate PDF'),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push<void>('/bill-settings'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Bill appearance'),
                  ),
                ],
              ),
            ),
        if (_archiveError != null) ...[
          InlineNotice(_archiveError!, isError: true),
          TextButton(
            onPressed: _archiveDuplicate,
            child: const Text('Retry duplicate archive'),
          ),
        ],
        const Divider(height: 32),
        for (final line in sale.draft.lines) ...[
          Text(line.name, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(line.sku),
          for (final parameter in line.parameters)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${parameter.name} · ${parameter.value}'),
            ),
          const SizedBox(height: 8),
          Text(
            line.pricing?.unitPriceRounded == true
                ? '${line.quantity} units · approx. ${formatMoney(line.unitPriceMinor, sale.draft.currency)} each'
                : '${line.quantity} × ${formatMoney(line.unitPriceMinor, sale.draft.currency)}',
          ),
          const SizedBox(height: 6),
          Text(
            formatMoney(line.totalMinor, sale.draft.currency),
            style: theme.textTheme.titleMedium,
          ),
          const Divider(height: 32),
        ],
        if (sale.draft.taxMinor > 0) ...[
          _MoneyFact('Excluding tax', sale.draft.netMinor, sale.draft.currency),
          _MoneyFact('Tax', sale.draft.taxMinor, sale.draft.currency),
        ],
        Text(
          'Total · ${sale.draft.units} units',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          formatMoney(sale.draft.totalMinor, sale.draft.currency),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _MoneyFact extends StatelessWidget {
  const _MoneyFact(this.label, this.amount, this.currency);
  final String label;
  final int amount;
  final String currency;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          formatMoney(amount, currency),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

class _PaymentQr extends ConsumerWidget {
  const _PaymentQr({required this.sale, required this.amountMinor});
  final Sale sale;
  final int amountMinor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(paymentSettingsProvider);
    if (sale.draft.currency != 'INR') {
      return const Padding(
        padding: EdgeInsets.only(top: 20),
        child: InlineNotice('UPI amount QR is available for INR bills.'),
      );
    }
    if (amountMinor < 1) {
      return const Padding(
        padding: EdgeInsets.only(top: 20),
        child: InlineNotice('Enter a valid payment amount to show its QR.'),
      );
    }
    return settings.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 20),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => const InlineNotice(
        'UPI settings could not be loaded.',
        isError: true,
      ),
      data: (value) {
        final uri = value.upiUri(sale, amountMinor: amountMinor);
        if (uri == null) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const InlineNotice(
                  'Add your UPI ID and business name in Settings to show a QR for this payment amount.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push<void>('/settings'),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Set up UPI QR'),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan to pay ${formatMoney(amountMinor, sale.draft.currency)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Customer scans with PhonePe, Google Pay, or another UPI app. The amount is prefilled; the owner verifies payment in their own UPI app.',
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: QrImageView(
                    data: uri.toString(),
                    version: QrVersions.auto,
                    size: 240,
                    backgroundColor: Colors.white,
                    semanticsLabel:
                        'UPI payment QR for ${formatMoney(amountMinor, sale.draft.currency)}',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  value.upiId,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
