import '../../../core/widgets/financial_amount.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/storage/business_database_provider.dart';
import '../../../core/widgets/page_content.dart';
import '../../../core/widgets/workspace_components.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';

final accountingEntriesProvider =
    FutureProvider.autoDispose<List<Map<String, Object?>>>((ref) async {
      final uid = ref.watch(inventoryUidProvider);
      if (uid == null) return const [];
      final db = await ref.read(businessDatabaseProvider).databaseFor(uid);
      return db.query(
        'accounting_entries',
        orderBy: 'createdAt DESC, id DESC',
        limit: 100,
      );
    });

class AccountingScreen extends ConsumerStatefulWidget {
  const AccountingScreen({super.key});
  @override
  ConsumerState<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends ConsumerState<AccountingScreen> {
  bool _saving = false;
  int _generation = 0;
  String? _saveError;

  bool _current(String uid, int generation) =>
      mounted &&
      generation == _generation &&
      ref.read(inventoryUidProvider) == uid;

  Future<void> _addEntry() async {
    if (_saving) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    final generation = _generation;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final entry = await showDialog<_EntryDraft>(
        context: context,
        builder: (_) => const _EntryDialog(),
      );
      if (entry == null || !_current(uid, generation)) return;
      final db = await ref.read(businessDatabaseProvider).databaseFor(uid);
      if (!_current(uid, generation)) return;
      await db.insert('accounting_entries', {
        'id': DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
        'type': entry.type,
        'category': entry.category,
        'description': entry.description,
        'currency': entry.currency,
        'amountMinor': entry.amountMinor,
        'taxMinor': entry.taxMinor,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.abort);
      if (!_current(uid, generation)) return;
      ref.invalidate(accountingEntriesProvider);
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
    final rowsAsync = ref.watch(accountingEntriesProvider);
    final uid = ref.watch(inventoryUidProvider);
    return PageContent(
      children: [
        const Eyebrow('Finance and tax'),
        const SizedBox(height: 12),
        Text('Accounting', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Record adjustments and tax entries alongside sales, purchases, expenses, and returns.',
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving || uid == null ? null : _addEntry,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add accounting entry'),
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
                'Accounting could not be loaded from this device.',
                isError: true,
              ),
              TextButton(
                onPressed: () => ref.invalidate(accountingEntriesProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const Text('No manual accounting entries recorded yet.');
            }
            var income = 0, expense = 0, tax = 0;
            final currencies = <String>{};
            for (final row in rows) {
              final amount = row['amountMinor']! as int;
              tax += row['taxMinor']! as int;
              currencies.add(row['currency']! as String);
              if (row['type'] == 'income') {
                income += amount;
              } else {
                expense += amount;
              }
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currencies.length == 1) ...[
                  _metric(
                    'Recorded income',
                    formatMoney(income, currencies.single),
                  ),
                  _metric(
                    'Recorded expenses',
                    formatMoney(expense, currencies.single),
                  ),
                  _metric('Recorded tax', formatMoney(tax, currencies.single)),
                ] else
                  const InlineNotice(
                    'Totals are shown per entry because multiple currencies are recorded.',
                  ),
                const SizedBox(height: 18),
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(row['description']! as String),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${row['type']} · ${row['category']} · ${row['currency']}',
                        ),
                        const SizedBox(height: 6),
                        FinancialAmount(
                          formatMoney(
                            row['amountMinor']! as int,
                            row['currency']! as String,
                          ),
                          compact: true,
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const InlineNotice(
          'Tax amounts are recorded per entry. Confirm local GST, tax rates, and filing rules with a qualified accountant before filing.',
        ),
      ],
    );
  }
}

Widget _metric(String label, String value) =>
    RecordFact(label: label, value: value);

class _EntryDraft {
  const _EntryDraft(
    this.type,
    this.category,
    this.description,
    this.currency,
    this.amountMinor,
    this.taxMinor,
  );
  final String type, category, description, currency;
  final int amountMinor, taxMinor;
}

class _EntryDialog extends StatefulWidget {
  const _EntryDialog();
  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  final _description = TextEditingController(),
      _category = TextEditingController(),
      _amount = TextEditingController(),
      _tax = TextEditingController(text: '0');
  String _type = 'expense', _currency = 'INR';
  String? _error;
  bool _submitted = false;
  @override
  void dispose() {
    _description.dispose();
    _category.dispose();
    _amount.dispose();
    _tax.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Accounting entry'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            items: const [
              DropdownMenuItem(value: 'income', child: Text('Income')),
              DropdownMenuItem(value: 'expense', child: Text('Expense')),
            ],
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
          TextField(
            controller: _category,
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Amount ($_currency)'),
          ),
          TextField(
            controller: _tax,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Tax ($_currency)'),
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
            final amount = parseMoney(_amount.text);
            final tax = parseMoney(_tax.text);
            if (_description.text.trim().isEmpty) {
              setState(() => _error = 'Enter a description.');
              return;
            }
            _submitted = true;
            Navigator.pop(
              context,
              _EntryDraft(
                _type,
                _category.text.trim().isEmpty
                    ? 'General'
                    : _category.text.trim(),
                _description.text.trim(),
                _currency,
                amount,
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
