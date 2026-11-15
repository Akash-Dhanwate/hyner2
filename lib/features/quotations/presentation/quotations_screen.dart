import '../../../core/widgets/financial_amount.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/storage/business_database_provider.dart';
import '../../../core/widgets/page_content.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';

import 'package:go_router/go_router.dart';

import 'quotation_controller.dart';
import '../domain/quotation.dart';

export 'quotation_controller.dart' show quotationsProvider;

/// Currency values use two decimal places. Tax rounds half up to a minor unit.
int quotationTaxMinor(int subtotalMinor, int rateBasisPoints) =>
    ((BigInt.from(subtotalMinor) * BigInt.from(rateBasisPoints) +
                BigInt.from(5000)) ~/
            BigInt.from(10000))
        .toInt();

class QuotationsScreen extends ConsumerStatefulWidget {
  const QuotationsScreen({super.key});
  @override
  ConsumerState<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends ConsumerState<QuotationsScreen> {
  bool _saving = false;
  int _generation = 0;
  String? _saveError;
  final _older = <Map<String, Object?>>[];
  bool _loadingMore = false, _end = false;
  Future<void> _more(List<Map<String, Object?>> rows) async {
    final uid = ref.read(inventoryUidProvider);
    if (uid == null || rows.isEmpty || _loadingMore) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _saveError = null;
    });
    try {
      final last = rows.last;
      final page = await ref
          .read(quotationRepositoryProvider)
          .list(
            uid,
            beforeTime: last['createdAt']! as String,
            beforeId: last['id']! as String,
          );
      if (_current(uid, generation)) {
        setState(() {
          _older.addAll(page);
          _end = page.length < 30;
        });
      }
    } catch (_) {
      if (_current(uid, generation)) {
        setState(
          () => _saveError = 'More quotations could not be loaded. Try again.',
        );
      }
    } finally {
      if (_current(uid, generation)) setState(() => _loadingMore = false);
    }
  }

  bool _current(String uid, int generation) =>
      mounted &&
      generation == _generation &&
      ref.read(inventoryUidProvider) == uid;

  Future<void> _add() async {
    if (_saving) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    final generation = _generation;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final draft = await showDialog<_QuoteDraft>(
        context: context,
        builder: (_) => const _QuoteDialog(),
      );
      if (draft == null || !_current(uid, generation)) return;
      final db = await ref.read(businessDatabaseProvider).databaseFor(uid);
      if (!_current(uid, generation)) return;
      final tax = quotationTaxMinor(
        draft.subtotalMinor,
        draft.taxRateBasisPoints,
      );
      await db.insert('quotations', {
        'id': 'Q-${DateTime.now().toUtc().microsecondsSinceEpoch}',
        'customerName': draft.customer,
        'customerPhone': draft.phone,
        'currency': draft.currency,
        'description': draft.description,
        'subtotalMinor': draft.subtotalMinor,
        'taxRateBasisPoints': draft.taxRateBasisPoints,
        'taxMinor': tax,
        'totalMinor': draft.subtotalMinor + tax,
        'status': 'draft',
        'validUntil': null,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.abort);
      if (!_current(uid, generation)) return;
      ref.invalidate(quotationsProvider);
    } catch (error) {
      if (_current(uid, generation)) {
        setState(() => _saveError = AppFailure.from(error).displayMessage);
      }
    } finally {
      if (_current(uid, generation)) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(inventoryUidProvider, (previous, next) {
      if (previous == next) return;
      setState(() {
        _generation++;
        _older.clear();
        _loadingMore = false;
        _end = false;
        _saving = false;
        _saveError = null;
      });
    });
    final rowsAsync = ref.watch(quotationsProvider);
    final uid = ref.watch(inventoryUidProvider);
    return PageContent(
      children: [
        const Eyebrow('Pre-sale planning'),
        const SizedBox(height: 12),
        Text('Quotations', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Prepare estimates before converting a customer request into a sale.',
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving || uid == null ? null : _add,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New quotation'),
        ),
        const SizedBox(height: 24),
        if (_saveError != null) InlineNotice(_saveError!, isError: true),
        rowsAsync.when(
          skipLoadingOnRefresh: false,
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const InlineNotice(
                'Quotations could not be loaded from this device.',
                isError: true,
              ),
              TextButton(
                onPressed: () => ref.invalidate(quotationsProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
          data: (first) {
            final rows = {
              for (final row in [...first, ..._older]) row['id']: row,
            }.values.toList();
            if (rows.isEmpty) return const Text('No quotations yet.');
            return Column(
              children: [
                for (final row in rows)
                  ListTile(
                    onTap: () {
                      try {
                        if (row['hasSnapshot'] == 1 ||
                            Quotation.fromRow(row) != null) {
                          context.push(
                            '/quotations/${Uri.encodeComponent(row['id']! as String)}',
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'This manual quotation has no saved item PDF. Its details are shown in the list.',
                              ),
                            ),
                          );
                        }
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This quotation could not be read safely.',
                            ),
                          ),
                        );
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                    title: Text(row['customerName']! as String),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${row['status']} · ${_description(row)} · Tax ${formatMoney(row['taxMinor']! as int, row['currency']! as String)}',
                        ),
                        const SizedBox(height: 6),
                        FinancialAmount(
                          formatMoney(
                            row['totalMinor']! as int,
                            row['currency']! as String,
                          ),
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                if (!_end && first.length >= 30)
                  TextButton(
                    onPressed: _loadingMore ? null : () => _more(rows),
                    child: Text(
                      _loadingMore ? 'Loading…' : 'Load more quotations',
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _QuoteDraft {
  const _QuoteDraft(
    this.customer,
    this.phone,
    this.description,
    this.currency,
    this.subtotalMinor,
    this.taxRateBasisPoints,
  );
  final String customer, phone, description, currency;
  final int subtotalMinor, taxRateBasisPoints;
}

class _QuoteDialog extends StatefulWidget {
  const _QuoteDialog();
  @override
  State<_QuoteDialog> createState() => _QuoteDialogState();
}

class _QuoteDialogState extends State<_QuoteDialog> {
  final _customer = TextEditingController(),
      _phone = TextEditingController(),
      _description = TextEditingController(),
      _subtotal = TextEditingController(),
      _tax = TextEditingController(text: '0');
  String _currency = 'INR';
  String? _error;
  bool _submitted = false;
  @override
  void dispose() {
    for (final c in [_customer, _phone, _description, _subtotal, _tax]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New quotation'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _customer,
            decoration: const InputDecoration(labelText: 'Customer name'),
          ),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
          ),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Items or scope'),
          ),
          TextField(
            controller: _subtotal,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Subtotal ($_currency)'),
          ),
          TextField(
            controller: _tax,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Tax rate (%)',
              helperText: 'Tax rounds to the nearest 0.01; halves round up.',
              helperMaxLines: 2,
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            items: [
              for (final item in inventoryCurrencies)
                DropdownMenuItem(value: item, child: Text(item)),
            ],
            onChanged: (value) =>
                setState(() => _currency = value ?? _currency),
          ),
          if (_error != null) InlineNotice(_error!, isError: true),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_submitted) return;
          try {
            final subtotal = parseMoney(_subtotal.text);
            final tax = parseMoney(_tax.text);
            if (_customer.text.trim().isEmpty ||
                _description.text.trim().isEmpty ||
                tax > 10000) {
              setState(
                () => _error = 'Enter a customer, items or scope, and a tax rate from 0 to 100%.',
              );
              return;
            }
            _submitted = true;
            Navigator.pop(
              context,
              _QuoteDraft(
                _customer.text.trim(),
                _phone.text.trim(),
                _description.text.trim(),
                _currency,
                subtotal,
                tax,
              ),
            );
          } on AppFailure catch (error) {
            setState(() => _error = error.message);
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}

String _description(Map<String, Object?> row) {
  if (row['hasSnapshot'] == 1) return 'Items from QuickPrice';
  try {
    final quote = Quotation.fromRow(row);
    if (quote != null) return '${quote.draft.lines.length} items';
  } catch (_) {
    return 'Saved quotation could not be read';
  }
  return row['description']! as String;
}
