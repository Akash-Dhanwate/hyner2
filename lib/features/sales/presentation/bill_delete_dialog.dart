import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/account_scope_guard.dart';
import '../../../core/widgets/page_content.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../domain/sale.dart';
import 'sales_controller.dart';

class BillDeleteDialog extends ConsumerStatefulWidget {
  const BillDeleteDialog({super.key, required this.sale, required this.uid});
  final Sale sale;
  final String uid;

  @override
  ConsumerState<BillDeleteDialog> createState() => _BillDeleteDialogState();
}

class _BillDeleteDialogState extends ConsumerState<BillDeleteDialog> {
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    if (_deleting || ref.read(inventoryUidProvider) != widget.uid) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref
          .read(salesRepositoryProvider)
          .delete(
            widget.uid,
            widget.sale.id,
            expectedPaidMinor: widget.sale.paidMinor,
          );
      if (mounted && ref.read(inventoryUidProvider) == widget.uid) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted && ref.read(inventoryUidProvider) == widget.uid) {
        setState(() => _error = AppFailure.from(error).displayMessage);
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    return AccountScopeGuard(
      uid: widget.uid,
      child: PopScope(
        canPop: !_deleting,
        child: AlertDialog(
          title: const Text('Delete this bill?'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sale.draft.customerName ?? 'Walk-in customer'),
                Text('Reference: ${sale.id}'),
                Text(
                  'Bill total: ${formatMoney(sale.draft.totalMinor, sale.draft.currency)}',
                ),
                const SizedBox(height: 16),
                const Text(
                  'This permanently removes the bill, its recorded payments, payment reminder and local PDF archive. Sales reports and customer bill history will update. The saved customer stays.',
                ),
                if (sale.draft.lines.any((line) => line.stockTracked)) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Inventory quantities will be restored. Archived products on this bill will become active again. Delete only if the sale was cancelled or entered by mistake and the goods remain in, or have returned to, your stock.',
                  ),
                ],
                if (sale.paidMinor > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Recorded payments of ${formatMoney(sale.paidMinor, sale.draft.currency)} will be removed from reports. No money is refunded; settle any refund separately.',
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'PDFs already downloaded or shared remain outside Hyner. A deletion record and stock history are kept. This cannot be undone.',
                ),
                if (_error != null) InlineNotice(_error!, isError: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _deleting ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              key: const Key('confirm-delete-bill'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: _deleting ? null : _delete,
              icon: _deleting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              label: Text(_deleting ? 'Deleting…' : 'Delete bill'),
            ),
          ],
        ),
      ),
    );
  }
}
