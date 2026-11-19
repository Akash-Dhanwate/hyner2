import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../app/bootstrap/app_dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/page_content.dart';
import '../../customers/presentation/customers_controller.dart';
import '../../expenses/presentation/expenses_controller.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../purchases/presentation/purchases_controller.dart';
import '../../reports/presentation/reports_controller.dart';
import '../data/bill_pdf_actions.dart';
import '../data/local_financial_repository.dart';
import '../data/local_sales_repository.dart';
import '../domain/sale.dart';
import 'sales_controller.dart';

final financialRepositoryProvider = Provider<LocalFinancialRepository?>((ref) {
  final sales = ref.watch(dependenciesProvider).sales;
  return sales is LocalSalesRepository
      ? LocalFinancialRepository(sales.store)
      : null;
});

/// One account-bound entry point for receipts, refunds, credits and corrections.
class FinancialPanel extends ConsumerStatefulWidget {
  const FinancialPanel({
    super.key,
    required this.id,
    required this.currency,
    this.sale,
    this.purchase = false,
  });
  final String id, currency;
  final bool purchase;
  final Sale? sale;
  @override
  ConsumerState<FinancialPanel> createState() => _FinancialPanelState();
}

class _FinancialPanelState extends ConsumerState<FinancialPanel> {
  bool busy = false;
  Future<void> Function()? _pending;
  bool get blocked => busy || _pending != null;
  String? error;
  late Future<
    (DocumentBalance, List<FinancialEntry>, List<Map<String, Object?>>)
  >
  data;
  String? uid;
  String get type => widget.purchase ? 'purchase' : 'sale';
  LocalFinancialRepository get repository =>
      ref.read(financialRepositoryProvider)!;
  @override
  void initState() {
    super.initState();
    uid = ref.read(inventoryUidProvider);
    data = _load();
  }

  bool get current =>
      mounted && uid != null && ref.read(inventoryUidProvider) == uid;
  Future<(DocumentBalance, List<FinancialEntry>, List<Map<String, Object?>>)>
  _load() async {
    final source = repository;
    final account = uid!;
    return (
      await source.balance(account, type, widget.id),
      await source.entries(account, type, widget.id),
      widget.purchase
          ? <Map<String, Object?>>[]
          : await source.returns(account, widget.id),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || !current) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      _pending = null;
      if (!current) return;
      ref.invalidate(saleProvider(widget.id));
      ref.invalidate(remainingPaymentsProvider);
      ref.invalidate(recentSalesProvider);
      ref.invalidate(customerSalesProvider);
      ref.invalidate(businessReportProvider);
      ref.invalidate(expensesProvider);
      ref.invalidate(scheduledFollowUpsProvider);
      ref.invalidate(purchaseProvider(widget.id));
      ref.invalidate(purchasesProvider);
      ref.invalidate(inventoryProductProvider);
      ref.invalidate(inventoryProvider);
      ref.invalidate(salesProvider);
      if (mounted) setState(() => data = _load());
    } catch (e) {
      final failure = AppFailure.from(e);
      _pending =
          e is! FormatException &&
              (failure.kind == FailureKind.network ||
                  failure.kind == FailureKind.unknown)
          ? action
          : null;
      if (current) {
        setState(
          () => error = e is FormatException
              ? e.message
              : AppFailure.from(e).displayMessage,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _payment(DocumentBalance balance, bool refund) async {
    if (busy || !current) return;
    final draft = await showDialog<FinancialPaymentDraft>(
      context: context,
      builder: (_) => _PaymentDialog(
        currency: widget.currency,
        maximum: refund ? balance.refundDueMinor : balance.dueMinor,
        refund: refund,
        purchase: widget.purchase,
      ),
    );
    if (draft == null || !current) return;
    final operation = ref.read(salesRepositoryProvider).newSaleId();
    await _run(
      () => repository.recordPayment(
        uid!,
        type,
        widget.id,
        draft.amount,
        operationId: operation,
        date: draft.date,
        method: draft.method,
        note: draft.note,
        refund: refund,
      ),
    );
  }

  Future<void> _reverse(FinancialEntry entry) async {
    final reason = await _reasonDialog(
      context,
      'Reverse this entry?',
      'Correct a recording mistake. This does not send or recover money. Enter the reason.',
    );
    if (reason == null || !current) return;
    final operation = ref.read(salesRepositoryProvider).newSaleId();
    await _run(
      () => repository.reversePayment(
        uid!,
        entry.id,
        operationId: operation,
        reason: reason,
        date: DateTime.now(),
      ),
    );
  }

  Future<void> _return(List<Map<String, Object?>> history) async {
    final returned = <String, int>{};
    for (final record in history) {
      for (final line in jsonDecode(record['items']! as String) as List) {
        returned[line['sku'] as String] =
            (returned[line['sku']] ?? 0) + (line['quantity'] as int);
      }
    }
    final draft = await showDialog<_ReturnDraft>(
      context: context,
      builder: (_) => _SaleReturnDialog(sale: widget.sale!, returned: returned),
    );
    if (draft == null || !current) return;
    final operation = ref.read(salesRepositoryProvider).newSaleId();
    await _run(
      () => repository.recordReturn(
        uid!,
        widget.sale!,
        draft.quantities,
        operationId: operation,
        reason: draft.reason,
        restock: draft.restock,
      ),
    );
  }

  Future<void> _void() async {
    final reason = await _reasonDialog(
      context,
      'Void bill ${widget.sale!.reference}?',
      'Only continue when the goods remain in, or have returned to, your stock. Remaining sold quantities are restored. The original bill and payments remain in history. Any received money becomes a refund due.',
    );
    if (reason == null || !current) return;
    await _run(
      () => repository.voidBill(
        uid!,
        widget.id,
        reason: reason,
        expectedPaidMinor: widget.sale!.paidMinor,
      ),
    );
  }

  Future<void> _saveCredit(Map<String, Object?> record) async {
    if (!current || busy) return;
    setState(() => busy = true);
    try {
      final doc = pw.Document(
        title: 'Return credit - Bill ${widget.sale!.reference}',
      );
      final lines = jsonDecode(record['items']! as String) as List;
      doc.addPage(
        pw.MultiPage(
          build: (_) => [
            pw.Text(
              'Return credit',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Bill ${widget.sale!.reference} - ${widget.sale!.draft.customerName ?? 'Customer'}',
            ),
            pw.Text('Reference: ${record['id']}'),
            pw.Text('Date: ${record['createdAt']}'),
            pw.Text('Reason: ${record['reason']}'),
            pw.SizedBox(height: 16),
            for (final line in lines)
              pw.Text(
                '${line['name']} - ${line['quantity']} - ${formatMoney(line['totalMinor'] as int, widget.currency)}',
              ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Credit total: ${formatMoney(record['totalMinor'] as int, widget.currency)}',
            ),
            pw.Text(
              'Included tax adjustment: ${formatMoney(record['taxMinor'] as int, widget.currency)}',
            ),
            pw.Text('Stock returned: ${record['restock'] == 1 ? 'Yes' : 'No'}'),
            pw.Text(
              'A credit does not confirm a cash refund. Refunds are recorded separately.',
            ),
          ],
        ),
      );
      final bytes = await doc.save();
      if (current) {
        await BillPdfActions.save(
          bytes,
          'Bill ${widget.sale!.reference} - Return ${record['id']}.pdf',
        );
      }
    } catch (e) {
      if (current) setState(() => error = AppFailure.from(e).displayMessage);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(financialRepositoryProvider) == null || uid == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const InlineNotice(
                'Financial history could not be loaded.',
                isError: true,
              ),
              TextButton(
                onPressed: () => setState(() => data = _load()),
                child: const Text('Retry history'),
              ),
            ],
          );
        }
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final (balance, entries, returns) = snapshot.data!;
        final reversed = {
          for (final e in entries)
            if (e.reversesId != null) e.reversesId,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              widget.purchase
                  ? 'Supplier payments and credits'
                  : 'Payments, returns and corrections',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Credit: ${formatMoney(balance.creditMinor, widget.currency)} · Outstanding: ${formatMoney(balance.dueMinor, widget.currency)}',
            ),
            if (balance.refundDueMinor > 0)
              Text(
                '${widget.purchase ? 'Supplier refund to receive' : 'Customer refund to pay'}: ${formatMoney(balance.refundDueMinor, widget.currency)}',
              ),
            if (widget.sale?.isVoid == true)
              InlineNotice(
                'Void bill · ${widget.sale!.voidReason ?? ''}. Original documents and receipts are retained.',
              ),
            if (widget.sale?.replacesSaleId != null)
              TextButton(
                onPressed: () =>
                    context.push('/sales/${widget.sale!.replacesSaleId}'),
                child: const Text('View replaced bill'),
              ),
            if (error != null) InlineNotice(error!, isError: true),
            if (_pending != null) ...[
              const Text(
                'This save was not confirmed. Retry the same operation before starting another action.',
              ),
              TextButton(
                onPressed: busy ? null : () => _run(_pending!),
                child: const Text('Check and retry last action'),
              ),
            ],
            if (busy) const LinearProgressIndicator(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (balance.dueMinor > 0)
                  FilledButton.icon(
                    onPressed: blocked ? null : () => _payment(balance, false),
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(
                      widget.purchase
                          ? 'Record supplier payment'
                          : 'Record dated payment',
                    ),
                  ),
                if (balance.refundDueMinor > 0)
                  OutlinedButton(
                    onPressed: blocked ? null : () => _payment(balance, true),
                    child: Text(
                      widget.purchase
                          ? 'Record refund received'
                          : 'Record refund paid',
                    ),
                  ),
                if (widget.sale != null && !widget.sale!.isVoid)
                  OutlinedButton(
                    onPressed: blocked ? null : () => _return(returns),
                    child: const Text('Return customer items'),
                  ),
                if (widget.sale != null && !widget.sale!.isVoid)
                  TextButton(
                    onPressed: blocked ? null : _void,
                    child: const Text('Void bill'),
                  ),
                if (widget.sale?.isVoid == true)
                  OutlinedButton(
                    onPressed: blocked
                        ? null
                        : () => context.push(
                            '/sales/new?replaces=${Uri.encodeComponent(widget.id)}',
                          ),
                    child: const Text('Create replacement bill'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty) const Text('No payment entries recorded.'),
            for (final entry in entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${entry.kind} · ${formatMoney(entry.amountMinor, widget.currency)}',
                ),
                subtitle: Text(
                  '${saleDate(entry.date)} · ${entry.method}${entry.note.isEmpty ? '' : '\n${entry.note}'}${reversed.contains(entry.id) ? ' · Reversed' : ''}',
                ),
                trailing:
                    entry.kind == 'reversal' || reversed.contains(entry.id)
                    ? null
                    : IconButton(
                        tooltip: 'Reverse recording mistake',
                        onPressed: blocked ? null : () => _reverse(entry),
                        icon: const Icon(Icons.undo),
                      ),
              ),
            for (final record in returns)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Return credit · ${formatMoney(record['totalMinor']! as int, widget.currency)}',
                ),
                subtitle: Text(
                  '${record['reason']} · ${saleDate(DateTime.parse(record['createdAt']! as String))}',
                ),
                trailing: IconButton(
                  tooltip: 'Save return credit PDF',
                  onPressed: blocked ? null : () => _saveCredit(record),
                  icon: const Icon(Icons.download_outlined),
                ),
              ),
          ],
        );
      },
    );
  }
}

class FinancialPaymentDraft {
  const FinancialPaymentDraft(this.amount, this.date, this.method, this.note);
  final int amount;
  final DateTime date;
  final String method, note;
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.currency,
    required this.maximum,
    required this.refund,
    required this.purchase,
    this.initialAmount,
  });
  final int? initialAmount;
  final String currency;
  final int maximum;
  final bool refund, purchase;
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final amount = TextEditingController(
    text: moneyDecimal(widget.initialAmount ?? widget.maximum),
  );
  final note = TextEditingController();
  DateTime date = DateTime.now();
  String method = 'cash';
  String? error;
  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  void submit() {
    try {
      final value = parseMoney(amount.text);
      if (value < 1 || value > widget.maximum) {
        throw const FormatException(
          'Enter a positive amount within the available balance.',
        );
      }
      Navigator.pop(
        context,
        FinancialPaymentDraft(value, date, method, note.text.trim()),
      );
    } catch (e) {
      setState(
        () =>
            error = e is FormatException ? e.message : 'Enter a valid amount.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.refund
          ? (widget.purchase
                ? 'Confirm refund received'
                : 'Confirm refund paid')
          : (widget.purchase
                ? 'Confirm supplier payment'
                : 'Confirm customer payment'),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Record only money you have verified outside Hyner.'),
          const SizedBox(height: 12),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount (${widget.currency})',
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: method,
            decoration: const InputDecoration(labelText: 'Payment method'),
            items: [
              for (final m in paymentMethods)
                DropdownMenuItem(value: m, child: Text(m.toUpperCase())),
            ],
            onChanged: (m) => setState(() => method = m!),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Date · ${saleDate(date)}'),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null && mounted) setState(() => date = picked);
            },
          ),
          TextField(
            controller: note,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Reference or note (optional)',
            ),
          ),
          if (error != null) InlineNotice(error!, isError: true),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: submit, child: const Text('Confirm and record')),
    ],
  );
}

Future<String?> _reasonDialog(
  BuildContext context,
  String title,
  String message,
) async {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(title, message),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog(this.title, this.message);
  final String title, message;
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final reason = TextEditingController();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          TextField(
            controller: reason,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Reason'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: reason.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, reason.text.trim()),
        child: const Text('Confirm'),
      ),
    ],
  );
}

class _ReturnDraft {
  const _ReturnDraft(this.quantities, this.reason, this.restock);
  final Map<String, int> quantities;
  final String reason;
  final bool restock;
}

class _SaleReturnDialog extends StatefulWidget {
  const _SaleReturnDialog({required this.sale, required this.returned});
  final Sale sale;
  final Map<String, int> returned;
  @override
  State<_SaleReturnDialog> createState() => _SaleReturnDialogState();
}

class _SaleReturnDialogState extends State<_SaleReturnDialog> {
  late final quantities = {
    for (final line in widget.sale.draft.lines)
      line.sku: TextEditingController(text: '0'),
  };
  final reason = TextEditingController();
  bool restock = true;
  String? error;
  @override
  void dispose() {
    reason.dispose();
    for (final c in quantities.values) {
      c.dispose();
    }
    super.dispose();
  }

  void submit() {
    try {
      final chosen = <String, int>{};
      for (final line in widget.sale.draft.lines) {
        final q = int.tryParse(quantities[line.sku]!.text);
        if (q == null ||
            q < 0 ||
            q > line.quantity - (widget.returned[line.sku] ?? 0)) {
          throw const FormatException(
            'Enter quantities within the remaining returnable amounts.',
          );
        }
        if (q > 0) chosen[line.sku] = q;
      }
      if (chosen.isEmpty || reason.text.trim().isEmpty) {
        throw const FormatException('Choose items and enter a reason.');
      }
      Navigator.pop(context, _ReturnDraft(chosen, reason.text.trim(), restock));
    } catch (e) {
      setState(() => error = (e as FormatException).message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Return items · Bill ${widget.sale.reference}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Credits reduce the unpaid balance first. Any excess becomes a refund due; record money paid separately. Goods not returned to stock retain their known cost as a recorded loss.',
          ),
          for (final line in widget.sale.draft.lines)
            TextField(
              controller: quantities[line.sku],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText:
                    '${line.name} · max ${line.quantity - (widget.returned[line.sku] ?? 0)}',
              ),
            ),
          TextField(
            controller: reason,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Return reason'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Return goods to sellable stock'),
            value: restock,
            onChanged: (v) => setState(() => restock = v),
          ),
          if (error != null) InlineNotice(error!, isError: true),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: submit,
        child: const Text('Record return credit'),
      ),
    ],
  );
}

Future<FinancialPaymentDraft?> showFinancialPaymentDialog(
  BuildContext context, {
  required String currency,
  required int maximum,
  int? initialAmount,
}) => showDialog<FinancialPaymentDraft>(
  context: context,
  builder: (_) => _PaymentDialog(
    currency: currency,
    maximum: maximum,
    initialAmount: initialAmount,
    refund: false,
    purchase: false,
  ),
);
