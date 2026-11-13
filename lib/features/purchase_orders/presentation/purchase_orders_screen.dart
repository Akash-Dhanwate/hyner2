import '../../../core/widgets/financial_amount.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/storage/business_database_provider.dart';
import '../../../core/widgets/page_content.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';

final purchaseOrdersProvider =
    FutureProvider.autoDispose<List<Map<String, Object?>>>((ref) async {
      final uid = ref.watch(inventoryUidProvider);
      if (uid == null) return const [];
      final db = await ref.read(businessDatabaseProvider).databaseFor(uid);
      return db.query('purchase_orders', orderBy: 'createdAt DESC, id DESC');
    });

class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});
  @override
  ConsumerState<PurchaseOrdersScreen> createState() =>
      _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends ConsumerState<PurchaseOrdersScreen> {
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
      final draft = await showDialog<_OrderDraft>(
        context: context,
        builder: (_) => const _OrderDialog(),
      );
      if (draft == null || !_current(uid, generation)) return;
      final db = await ref.read(businessDatabaseProvider).databaseFor(uid);
      if (!_current(uid, generation)) return;
      await db.insert('purchase_orders', {
        'id': 'PO-${DateTime.now().toUtc().microsecondsSinceEpoch}',
        'supplierName': draft.supplier,
        'supplierPhone': draft.phone,
        'currency': draft.currency,
        'description': draft.description,
        'totalMinor': draft.totalMinor,
        'status': 'draft',
        'expectedAt': null,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.abort);
      if (!_current(uid, generation)) return;
      ref.invalidate(purchaseOrdersProvider);
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
    final rowsAsync = ref.watch(purchaseOrdersProvider);
    final uid = ref.watch(inventoryUidProvider);
    return PageContent(
      children: [
        const Eyebrow('Supplier planning'),
        const SizedBox(height: 12),
        Text(
          'Purchase orders',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Prepare and track supplier orders before stock is received.',
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving || uid == null ? null : _add,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New purchase order'),
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
                'Purchase orders could not be loaded from this device.',
                isError: true,
              ),
              TextButton(
                onPressed: () => ref.invalidate(purchaseOrdersProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
          data: (rows) {
            if (rows.isEmpty) return const Text('No purchase orders yet.');
            return Column(
              children: [
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(row['supplierName']! as String),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${row['status']} · ${row['description']}'),
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
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OrderDraft {
  const _OrderDraft(
    this.supplier,
    this.phone,
    this.description,
    this.currency,
    this.totalMinor,
  );
  final String supplier, phone, description, currency;
  final int totalMinor;
}

class _OrderDialog extends StatefulWidget {
  const _OrderDialog();
  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<_OrderDialog> {
  final _supplier = TextEditingController(),
      _phone = TextEditingController(),
      _description = TextEditingController(),
      _total = TextEditingController();
  String _currency = 'INR';
  String? _error;
  bool _submitted = false;
  @override
  void dispose() {
    _supplier.dispose();
    _phone.dispose();
    _description.dispose();
    _total.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New purchase order'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _supplier,
            decoration: const InputDecoration(labelText: 'Supplier name'),
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
            controller: _total,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Expected total ($_currency)',
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
            final total = parseMoney(_total.text);
            if (_supplier.text.trim().isEmpty ||
                _description.text.trim().isEmpty) {
              setState(() => _error = 'Enter a supplier and items or scope.');
              return;
            }
            _submitted = true;
            Navigator.pop(
              context,
              _OrderDraft(
                _supplier.text.trim(),
                _phone.text.trim(),
                _description.text.trim(),
                _currency,
                total,
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
