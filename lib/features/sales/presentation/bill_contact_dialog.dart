import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/page_content.dart';
import '../../customers/domain/customer.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../domain/sale.dart';
import 'sales_controller.dart';

class BillContactDialog extends ConsumerStatefulWidget {
  const BillContactDialog({super.key, required this.sale, required this.uid});
  final Sale sale;
  final String uid;
  @override
  ConsumerState<BillContactDialog> createState() => _BillContactDialogState();
}

class _BillContactDialogState extends ConsumerState<BillContactDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.sale.draft.customerName ?? '',
  );
  late final _phone = TextEditingController(
    text: widget.sale.draft.customerPhone ?? '',
  );
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving ||
        !_form.currentState!.validate() ||
        ref.read(inventoryUidProvider) != widget.uid) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(salesRepositoryProvider)
          .updateContact(
            widget.uid,
            widget.sale.id,
            name: _name.text,
            phone: _phone.text,
            expectedName: widget.sale.draft.customerName,
            expectedPhone: widget.sale.draft.customerPhone,
          );
      if (mounted && ref.read(inventoryUidProvider) == widget.uid) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted && ref.read(inventoryUidProvider) == widget.uid) {
        setState(() {
          _saving = false;
          _error = AppFailure.from(error).message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(inventoryUidProvider, (_, uid) {
      if (uid != widget.uid) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ModalRoute.of(context)?.isCurrent == true) {
            Navigator.pop(context, false);
          }
        });
      }
    });
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(
          'Edit bill customer',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Available until ${saleDate(widget.sale.contactEditDeadline)}.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('bill-contact-name'),
                  controller: _name,
                  enabled: !_saving,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Customer name',
                    counterText: '',
                  ),
                  validator: (v) => v?.trim().isNotEmpty == true
                      ? null
                      : 'Enter the customer name.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('bill-contact-phone'),
                  controller: _phone,
                  enabled: !_saving,
                  maxLength: 40,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    counterText: '',
                  ),
                  validator: (v) => validCustomerMobile(v ?? '')
                      ? null
                      : 'Enter a valid mobile number.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Only this bill changes. Saved customer profiles, other bills and archived copies keep their existing details.',
                ),
                if (_error != null) InlineNotice(_error!, isError: true),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('save-bill-contact'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
