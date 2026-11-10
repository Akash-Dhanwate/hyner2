import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/storage/business_database_provider.dart';
import '../../../core/widgets/page_content.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';

final quotationsProvider =
    FutureProvider.autoDispose<List<Map<String, Object?>>>((ref) async {
      final uid = ref.watch(inventoryUidProvider);
      if (uid == null) return const [];
      final db = await ref.read(businessDatabaseProvider).databaseFor(uid);
      return db.query('quotations', orderBy: 'createdAt DESC, id DESC');
    });

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
          data: (rows) {
            if (rows.isEmpty) return const Text('No quotations yet.');
            return Column(
              children: [
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(row['customerName']! as String),
                    subtitle: Text(
                      '${row['status']} · ${row['description']} · Tax ${formatMoney(row['taxMinor']! as int, row['currency']! as String)}',
                    ),
                    trailing: Text(
                      formatMoney(
                        row['totalMinor']! as int,
                        row['currency']! as String,
                      ),
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
