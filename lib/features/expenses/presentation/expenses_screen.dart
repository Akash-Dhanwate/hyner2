import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/widgets/page_content.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../reports/presentation/reports_controller.dart';
import '../domain/operating_expense.dart';
import 'expenses_controller.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  bool _busy = false;
  int _generation = 0;

  bool _current(String uid, int generation) =>
      mounted &&
      generation == _generation &&
      ref.read(inventoryUidProvider) == uid;

  Future<void> _add() async {
    if (_busy) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    final generation = _generation;
    final repository = ref.read(expenseRepositoryProvider);
    setState(() => _busy = true);
    try {
      final draft = await showDialog<OperatingExpenseDraft>(
        context: context,
        builder: (_) => const _ExpenseDialog(),
      );
      if (draft == null || !_current(uid, generation)) return;
      await repository.create(uid, repository.newId(), draft);
      if (!_current(uid, generation)) return;
      ref.invalidate(expensesProvider);
      ref.invalidate(businessReportProvider);
      await LocalNotificationService.instance.activity(
        title: 'Expense recorded',
        body:
            '${draft.category} · ${formatMoney(draft.amountMinor, draft.currency)}',
      );
    } catch (error) {
      if (!mounted || !_current(uid, generation)) return;
      final message = error is FormatException
          ? error.message
          : AppFailure.from(error).displayMessage;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (_current(uid, generation)) setState(() => _busy = false);
    }
  }

  Future<void> _delete(OperatingExpense expense) async {
    if (_busy) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    final generation = _generation;
    final repository = ref.read(expenseRepositoryProvider);
    setState(() => _busy = true);
    try {
      final remove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete expense?'),
          content: Text(
            'Remove ${expense.category} · ${formatMoney(expense.amountMinor, expense.currency)} from your reports?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (remove != true || !_current(uid, generation)) return;
      await repository.delete(uid, expense.id);
      if (!_current(uid, generation)) return;
      ref.invalidate(expensesProvider);
      ref.invalidate(businessReportProvider);
    } catch (error) {
      if (!mounted || !_current(uid, generation)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppFailure.from(error).displayMessage)),
      );
    } finally {
      if (_current(uid, generation)) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(inventoryUidProvider, (previous, next) {
      if (previous == next) return;
      setState(() {
        _generation++;
        _busy = false;
      });
    });
    final uid = ref.watch(inventoryUidProvider);
    final expenses = ref.watch(expensesProvider);
    final theme = Theme.of(context);
    return SliverPageContent(
      onRefresh: () async {
        try {
          ref.invalidate(expensesProvider);
          await ref.read(expensesProvider.future);
        } catch (_) {
          // The provider renders the loading failure below.
        }
      },
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Money out'),
          const SizedBox(height: 12),
          Text('Expenses', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'Record outgoings such as rent, salaries, utilities, transport, and maintenance.',
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy || uid == null ? null : _add,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Record expense'),
          ),
        ],
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: expenses.when(
            loading: () =>
                const SliverToBoxAdapter(child: LinearProgressIndicator()),
            error: (_, _) => SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InlineNotice(
                    'Expenses could not be loaded from this device.',
                    isError: true,
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(expensesProvider),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
            data: (items) => items.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No operating expenses recorded yet.'),
                    ),
                  )
                : SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final expense = items[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(expense.description),
                        subtitle: Text(
                          '${expense.category} · ${_formatExpenseDate(expense.occurredAt)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatMoney(
                                expense.amountMinor,
                                expense.currency,
                              ),
                            ),
                            PopupMenuButton<String>(
                              enabled: !_busy && uid != null,
                              onSelected: (action) {
                                if (action == 'delete') {
                                  _delete(expense);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        subtitleTextStyle: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
          sliver: SliverToBoxAdapter(
            child: InlineNotice(
              'These are user-entered operating expenses for an operational summary. This screen does not calculate tax or prepare accounting statements.',
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog();

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  String _category = expenseCategories.first;
  String _currency = 'INR';
  DateTime _date = DateTime.now();
  String? _error;
  bool _submitted = false;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitted || !_form.currentState!.validate()) return;
    final minor = parseMoney(_amount.text);
    final draft = OperatingExpenseDraft(
      category: _category,
      description: _description.text.trim(),
      currency: _currency,
      amountMinor: minor,
      occurredAt: _date,
    );
    try {
      draft.validate();
      _submitted = true;
      Navigator.pop(context, draft);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Record expense'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final category in expenseCategories)
                  DropdownMenuItem(value: category, child: Text(category)),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _description,
              autofocus: true,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a short description.'
                  : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: const InputDecoration(labelText: 'Currency'),
              items: [
                for (final currency in inventoryCurrencies)
                  DropdownMenuItem(value: currency, child: Text(currency)),
              ],
              onChanged: (value) =>
                  setState(() => _currency = value ?? _currency),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: 'Amount ($_currency)'),
              validator: (value) {
                try {
                  final amount = parseMoney(value ?? '');
                  return amount < 1 ? 'Enter an amount above zero.' : null;
                } on AppFailure catch (error) {
                  return error.message;
                }
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Expense date'),
              subtitle: Text(_formatExpenseDate(_date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (mounted && date != null) setState(() => _date = date);
              },
            ),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save expense')),
    ],
  );
}

String _formatExpenseDate(DateTime value) {
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
