import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/widgets/page_content.dart';
import '../../../core/widgets/financial_amount.dart';
import '../../../core/widgets/workspace_components.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customers_controller.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/domain/pricing_formula.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../domain/sale.dart';
import '../domain/sale_checkout_seed.dart';
import 'sale_product_picker.dart';
import 'sales_controller.dart';
import 'bill_summary.dart';
import '../../reports/presentation/reports_controller.dart';

class SaleEditorScreen extends ConsumerWidget {
  const SaleEditorScreen({
    super.key,
    this.embedded = false,
    this.customerId,
    this.checkout,
  });
  final bool embedded;
  final String? customerId;

  /// The entry wrapper resolves a previously saved operation before opening
  /// the editor, so returning to an estimate opens its existing bill.
  final SaleCheckoutSeed? checkout;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(inventoryUidProvider);
    if (checkout != null && uid != checkout!.uid) {
      return const Scaffold(
        body: PageContent(
          children: [
            InlineNotice(
              'This checkout belongs to a different account. Return to QuickPrice to continue.',
              isError: true,
            ),
          ],
        ),
      );
    }
    return uid == null
        ? const SizedBox.shrink()
        : _SaleForm(
            key: ValueKey((uid, checkout?.operationId)),
            uid: uid,
            embedded: embedded,
            initialCustomerId: customerId,
            checkout: checkout,
          );
  }
}

class _SaleForm extends ConsumerStatefulWidget {
  const _SaleForm({
    super.key,
    required this.uid,
    required this.embedded,
    this.initialCustomerId,
    this.checkout,
  });
  final String uid;
  final bool embedded;
  final String? initialCustomerId;
  final SaleCheckoutSeed? checkout;
  @override
  ConsumerState<_SaleForm> createState() => _SaleFormState();
}

class _SaleFormState extends ConsumerState<_SaleForm> {
  final _form = GlobalKey<FormState>();
  final _products = <Product>[];
  final _quantities = <String, TextEditingController>{};
  final _prices = <String, TextEditingController>{};
  final _parameters = <String, List<_ParameterFields>>{};
  final _measurementValues = <String, Map<String, String>>{};
  final _advanceAmount = TextEditingController();
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _customerAddress = TextEditingController();
  Customer? _customer;
  int _paymentMode = 0; // 0 full, 1 advance, 2 pay later
  bool _saving = false, _uncertain = false, _allowPop = false, _asking = false;
  String? _id;
  SaleDraft? _submitted;
  AppFailure? _failure;
  late final SaleCheckoutSeed? _checkout;
  List<SaleLine> get _seedLines => _checkout?.lines ?? const [];
  bool get _hasLines => _seedLines.isNotEmpty || _products.isNotEmpty;
  int get _lineCount => _seedLines.length + _products.length;
  String? get _currency =>
      _checkout?.currency ?? _products.firstOrNull?.currency;
  bool get _current => mounted && ref.read(inventoryUidProvider) == widget.uid;
  @override
  void initState() {
    super.initState();
    _checkout = widget.checkout;
    _id = _checkout?.operationId;
    final customerId = widget.initialCustomerId;
    if (customerId != null) {
      unawaited(_loadInitialCustomer(customerId));
    }
  }

  Future<void> _loadInitialCustomer(String id) async {
    try {
      final customers = await ref.read(customersProvider.future);
      if (!_current) return;
      final match = customers
          .where((customer) => customer.id == id)
          .firstOrNull;
      if (match != null) setState(() => _selectCustomer(match));
    } catch (_) {
      // The customer can still be selected manually if its local record is unavailable.
    }
  }

  void _selectCustomer(Customer? value) {
    _customer = value;
    if (value != null && !validCustomerMobile(value.phone)) {
      _customerName.text = value.name;
      _customerPhone.text = value.phone;
      _customerAddress.text = value.address;
    }
  }

  @override
  void dispose() {
    for (final c in [
      ..._quantities.values,
      ..._prices.values,
      _advanceAmount,
      _customerName,
      _customerPhone,
      _customerAddress,
    ]) {
      c.dispose();
    }
    for (final row in _parameters.values) {
      for (final parameter in row) {
        parameter.dispose();
      }
    }
    super.dispose();
  }

  List<SaleLine> _lines() => [
    ..._seedLines,
    for (final p in _products)
      SaleLine.fromProduct(
        p,
        parseUnits(_quantities[p.sku]!.text, allowZero: false),
        unitPriceMinor: parseMoney(_prices[p.sku]!.text),
        parameters: [
          for (final parameter in _parameters[p.sku] ?? const [])
            ProductParameter(
              name: parameter.name.text.trim(),
              value: parameter.value.text.trim(),
            ),
        ],
      ),
  ];

  SaleDraft _draft() {
    if (!_hasLines) {
      throw inventoryInvalid('Add a product before generating a bill.');
    }
    final lines = _lines();
    final total = lines.fold<int>(0, (sum, line) => sum + line.totalMinor);
    return SaleDraft(
      currency: _currency!,
      customerId: _customer?.id,
      customerName: _customer != null && validCustomerMobile(_customer!.phone)
          ? _customer!.name
          : (_customerName.text.trim().isEmpty
                ? null
                : _customerName.text.trim()),
      customerPhone: _customer != null && validCustomerMobile(_customer!.phone)
          ? _customer!.phone
          : _customerPhone.text.trim(),
      customerAddress:
          _customer != null && validCustomerMobile(_customer!.phone)
          ? _customer!.address
          : _customerAddress.text.trim(),
      initialPaymentMinor: _paymentMode == 2
          ? 0
          : _paymentMode == 1
          ? parseMoney(_advanceAmount.text)
          : total,
      lines: lines,
    )..validate();
  }

  void _addParameter(String sku) {
    setState(() {
      _parameters[sku]!.add(_ParameterFields('', ''));
    });
  }

  Future<bool> _calculateMeasuredPrice(Product product) async {
    final formula = product.pricingFormula;
    if (formula == null || !formula.enabled) return false;
    final fields = {
      for (final input in formula.inputs)
        input.name: TextEditingController(
          text: _measurementValues[product.sku]?[input.name] ?? '',
        ),
    };
    final route =
        DialogRoute<
          ({
            int price,
            List<ProductParameter> parameters,
            Map<String, String> values,
          })
        >(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Calculate ${product.name} price'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Price per bill item · ${formula.expression}'),
                  const SizedBox(height: 12),
                  for (final input in formula.inputs) ...[
                    TextField(
                      controller: fields[input.name],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: input.label,
                        suffixText: input.unit,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  try {
                    final values = {
                      for (final input in formula.inputs)
                        input.name: fields[input.name]!.text.trim(),
                    };
                    Navigator.pop(dialogContext, (
                      values: values,
                      price: PricingFormulaCalculator.calculateMinor(
                        formula,
                        values,
                      ),
                      parameters: pricingMeasurementParameters(
                        formula,
                        values,
                        [
                          for (final p
                              in _parameters[product.sku] ??
                                  const <_ParameterFields>[])
                            if (p.name.text.trim().isNotEmpty &&
                                p.value.text.trim().isNotEmpty)
                              ProductParameter(
                                name: p.name.text.trim(),
                                value: p.value.text.trim(),
                              ),
                        ],
                      ),
                    ));
                  } on Object catch (error) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(AppFailure.from(error).message)),
                    );
                  }
                },
                child: const Text('Apply price'),
              ),
            ],
          ),
        );
    try {
      final result = await Navigator.of(
        context,
        rootNavigator: true,
      ).push(route);
      if (result != null && mounted && _current) {
        final previous = _parameters[product.sku] ?? const <_ParameterFields>[];
        setState(() {
          _measurementValues[product.sku] = result.values;
          _prices[product.sku]!.text = moneyDecimal(result.price);
          _parameters[product.sku] = [
            for (final p in result.parameters)
              _ParameterFields(p.name, p.value),
          ];
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final p in previous) {
            p.dispose();
          }
        });
      }
      return result != null && mounted && _current;
    } finally {
      await route.completed;
      for (final controller in fields.values) {
        controller.dispose();
      }
    }
  }

  Future<void> _add() async {
    if (_saving || _uncertain) return;
    final product = await showDialog<Product>(
      context: context,
      builder: (_) => SaleProductPicker(
        uid: widget.uid,
        selected: {
          ..._seedLines.map((line) => line.sku),
          ..._products.map((product) => product.sku),
        },
        currency: _currency,
      ),
    );
    if (!_current || product == null) return;
    setState(() {
      _products.add(product);
      _quantities[product.sku] = TextEditingController(text: '1');
      _prices[product.sku] = TextEditingController(
        text: moneyDecimal(product.priceMinor),
      );
      _parameters[product.sku] = [
        for (final parameter in product.parameters)
          _ParameterFields(parameter.name, parameter.value),
      ];
      _failure = null;
    });
    if (product.pricingFormula?.enabled == true) {
      final applied = await _calculateMeasuredPrice(product);
      if (!applied && mounted && _current) {
        setState(() {
          _products.remove(product);
          _prices.remove(product.sku)?.dispose();
          _quantities.remove(product.sku)?.dispose();
          for (final parameter
              in _parameters.remove(product.sku) ?? <_ParameterFields>[]) {
            parameter.dispose();
          }
        });
      }
    }
  }

  Future<void> _leave() async {
    if (_saving || _asking) return;
    _asking = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _uncertain ? 'Leave before checking the sale?' : 'Discard this bill?',
        ),
        content: Text(
          _uncertain
              ? (_checkout == null
                    ? 'The sale may already be saved. Check Sales for reference $_id before creating another bill. This retry is not kept after leaving.'
                    : 'The sale may already be saved. Continue this estimate from QuickPrice to check reference $_id before creating another bill.')
              : (_checkout == null
                    ? 'Your unsaved bill will be lost.'
                    : 'Your customer and payment details will be lost. You can edit the items in QuickPrice.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    _asking = false;
    if (!_current || leave != true) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && _current) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/dashboard');
      }
    }
  }

  Future<void> _save() async {
    if (_saving || !_current || !_hasLines) return;
    if (!_uncertain && !_form.currentState!.validate()) return;
    try {
      final draft = _uncertain ? _submitted! : (_draft()..validateForNewBill());
      final repository = ref.read(salesRepositoryProvider);
      _id ??= repository.newSaleId();
      _submitted = draft;
      setState(() {
        _saving = true;
        _failure = null;
      });
      await repository.create(widget.uid, _id!, draft);
      if (!_current) return;
      ref.invalidate(recentSalesProvider);
      try {
        await _checkout?.onSaved?.call(_id!);
      } catch (_) {
        // The bill is committed. The checkout wrapper reconciles the estimate
        // against this operation ID on its next entry if completion failed.
      }
      if (!_current) return;
      ref.invalidate(customersProvider);
      ref.invalidate(customerSalesProvider);
      ref.invalidate(businessReportProvider);
      final stockLines = draft.lines
          .where((line) => line.pricing == null)
          .toList();
      for (final line in stockLines) {
        ref.read(inventoryProvider.notifier).checkStock(widget.uid, line.sku);
      }
      unawaited(
        LocalNotificationService.instance.activity(
          title: 'Sale recorded',
          body:
              '${draft.units} units · ${formatMoney(draft.totalMinor, draft.currency)}',
        ),
      );
      ref.invalidate(saleProvider(_id!));
      unawaited(ref.read(salesProvider.notifier).refresh());
      if (stockLines.isNotEmpty) {
        unawaited(ref.read(inventoryProvider.notifier).refresh());
      }
      for (final line in stockLines) {
        ref.invalidate(inventoryProductProvider(line.sku));
      }
      setState(() {
        _saving = false;
        _allowPop = true;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && _current) context.replace('/sales/$_id');
    } catch (error) {
      if (!_current) return;
      final failure = AppFailure.from(error);
      setState(() {
        _saving = false;
        _failure = failure;
        _uncertain =
            _uncertain ||
            failure.kind == FailureKind.network ||
            failure.kind == FailureKind.unknown;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_saving && !_uncertain;
    final customers = ref.watch(customersProvider).value ?? const <Customer>[];
    final customerFields = <Widget>[
      Text('Customer details', style: Theme.of(context).textTheme.titleMedium),
      if (_checkout == null) ...[
        const SizedBox(height: 8),
        const Text(
          'Choose an existing customer, or enter the details for this bill.',
        ),
      ],
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('sale-customer-${_customer?.id ?? "new"}'),
        isExpanded: true,
        initialValue: customers.any((c) => c.id == _customer?.id)
            ? _customer?.id
            : null,
        decoration: const InputDecoration(
          labelText: 'Existing customer (optional)',
        ),
        hint: const Text('Enter customer details below'),
        items: [
          const DropdownMenuItem(
            value: '',
            child: Text('Enter customer details below'),
          ),
          for (final customer in customers)
            DropdownMenuItem(
              value: customer.id,
              child: Text(customer.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: enabled
            ? (id) => setState(() {
                _selectCustomer(customers.where((c) => c.id == id).firstOrNull);
              })
            : null,
      ),
      const SizedBox(height: 12),
      if (_customer == null || !validCustomerMobile(_customer!.phone)) ...[
        TextFormField(
          key: const Key('sale-customer-name'),
          controller: _customerName,
          enabled: enabled,
          maxLength: 120,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Customer name'),
          validator: (value) =>
              (value ?? '').trim().isEmpty ? 'Enter the customer name.' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('sale-customer-phone'),
          controller: _customerPhone,
          enabled: enabled,
          maxLength: 40,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Mobile number'),
          validator: (value) => validCustomerMobile(value ?? '')
              ? null
              : 'Enter a valid mobile number.',
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('sale-customer-address'),
          controller: _customerAddress,
          enabled: enabled,
          maxLength: 240,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Address (optional)'),
        ),
      ] else ...[
        Text(_customer!.name),
        if (_customer!.phone.isNotEmpty) Text(_customer!.phone),
        if (_customer!.address.isNotEmpty) Text(_customer!.address),
      ],
      const SizedBox(height: 20),
    ];
    SaleDraft? preview;
    if (_hasLines) {
      try {
        preview = SaleDraft(currency: _currency!, lines: _lines())..validate();
      } catch (_) {
        /* Form shows invalid quantities. */
      }
    }
    return PopScope(
      canPop: !_saving && (_allowPop || !_hasLines),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: widget.embedded
            ? null
            : AppBar(
                title: const Text('Build a bill'),
                actions: [
                  IconButton(
                    key: const Key('sale-editor-bill-preferences'),
                    tooltip: 'Bill preferences',
                    onPressed: () => context.push<void>('/bill-settings'),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                  IconButton(
                    tooltip: 'Saved bills',
                    onPressed: () => context.push<void>('/sales/history'),
                    icon: const Icon(Icons.history_rounded),
                  ),
                ],
              ),
        body: PageContent(
          children: [
            if (_checkout == null) ...[
              if (widget.embedded)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Build a bill',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      key: const Key('sale-editor-bill-preferences'),
                      tooltip: 'Bill preferences',
                      onPressed: () => context.push<void>('/bill-settings'),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              _addProductButton(enabled),
              if (!_hasLines) const RecentBills(),
              const SizedBox(height: 20),
            ],
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_checkout != null) ...[
                    _CheckoutLines(lines: _seedLines, currency: _currency!),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key('back-to-quickprice'),
                        onPressed: _saving ? null : _leave,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Back to QuickPrice'),
                      ),
                    ),
                    const Divider(height: 24),
                    ...customerFields,
                  ],
                  for (final product in _products) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove ${product.sku}',
                          onPressed: enabled
                              ? () => setState(() {
                                  _products.remove(product);
                                  _quantities.remove(product.sku)?.dispose();
                                  _prices.remove(product.sku)?.dispose();
                                  for (final parameter
                                      in _parameters.remove(product.sku) ??
                                          []) {
                                    parameter.dispose();
                                  }
                                  _failure = null;
                                })
                              : null,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    Text(
                      '${product.sku} · Inventory price ${formatMoney(product.priceMinor, product.currency)}',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: ValueKey('sale-price-${product.sku}'),
                      controller: _prices[product.sku],
                      enabled: enabled,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Bill price (${product.currency})',
                        helperText: 'This bill only. Inventory selling price stays unchanged.',
                      ),
                      validator: (value) {
                        try {
                          parseMoney(value ?? '');
                          return null;
                        } on AppFailure catch (error) {
                          return error.message;
                        }
                      },
                    ),
                    if (product.pricingFormula?.enabled == true)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: enabled
                              ? () => _calculateMeasuredPrice(product)
                              : null,
                          icon: const Icon(Icons.calculate_outlined),
                          label: const Text('Edit measurements'),
                        ),
                      ),
                    if (_priceChanged(product))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: enabled
                              ? () => setState(() {
                                  _prices[product.sku]!.text = moneyDecimal(
                                    product.priceMinor,
                                  );
                                })
                              : null,
                          child: const Text('Use inventory price'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: ValueKey('sale-quantity-${product.sku}'),
                      controller: _quantities[product.sku],
                      enabled: enabled,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        helperText:
                            '${product.quantity} units available when selected',
                      ),
                      validator: (value) {
                        try {
                          final units = parseUnits(
                            value ?? '',
                            allowZero: false,
                          );
                          if (units > product.quantity) {
                            return 'Only ${product.quantity} units available.';
                          }
                          SaleLine.fromProduct(
                            product,
                            units,
                            unitPriceMinor: parseMoney(
                              _prices[product.sku]!.text,
                            ),
                          ).validate();
                          return null;
                        } on AppFailure catch (error) {
                          return error.message;
                        }
                      },
                    ),
                    DisclosureSection(
                      key: ValueKey('sale-specifications-${product.sku}'),
                      title: 'Item details',
                      summary:
                          '${_parameters[product.sku]?.length ?? 0} specifications · optional edits',
                      revealError:
                          _failure?.message.toLowerCase().contains(
                            'parameter',
                          ) ==
                          true,
                      children: [
                        for (
                          var index = 0;
                          index < (_parameters[product.sku]?.length ?? 0);
                          index++
                        ) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller:
                                      _parameters[product.sku]![index].name,
                                  enabled: enabled,
                                  maxLength: 60,
                                  decoration: const InputDecoration(
                                    labelText: 'Parameter',
                                    counterText: '',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller:
                                      _parameters[product.sku]![index].value,
                                  enabled: enabled,
                                  maxLength: 120,
                                  decoration: const InputDecoration(
                                    labelText: 'Value',
                                    counterText: '',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove bill parameter',
                                onPressed: enabled
                                    ? () => setState(() {
                                        _parameters[product.sku]![index]
                                            .dispose();
                                        _parameters[product.sku]!.removeAt(
                                          index,
                                        );
                                      })
                                    : null,
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ],
                        if ((_parameters[product.sku]?.length ?? 0) < 20)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: enabled
                                  ? () => _addParameter(product.sku)
                                  : null,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add bill parameter'),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 32),
                  ],
                  if (_checkout != null && _products.isEmpty)
                    ExpansionTile(
                      key: const Key('sale-additional-products'),
                      title: const Text('Additional products'),
                      subtitle: const Text('Optional inventory items'),
                      tilePadding: EdgeInsets.zero,
                      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [_addProductButton(enabled)],
                    )
                  else if (_checkout != null)
                    _addProductButton(enabled),
                  if (_hasLines) ...[
                    const SizedBox(height: 28),
                    Text(
                      'Total',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    FinancialAmount(
                      preview == null
                          ? (!_hasLines ? '—' : 'Check prices and quantities')
                          : formatMoney(preview.totalMinor, preview.currency),
                      textKey: const Key('sale-total'),
                      prominent: true,
                    ),
                    const SizedBox(height: 20),
                    if (_checkout == null) ...customerFields,
                    Text(
                      'Payment',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          label: Text('Pay in full'),
                          icon: Icon(Icons.check_circle_outline_rounded),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Text('Advance'),
                          icon: Icon(Icons.payments_outlined),
                        ),
                        ButtonSegment(
                          value: 2,
                          label: Text('Pay later'),
                          icon: Icon(Icons.schedule_outlined),
                        ),
                      ],
                      selected: {_paymentMode},
                      onSelectionChanged: enabled
                          ? (selection) => setState(() {
                              _paymentMode = selection.first;
                            })
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _paymentMode == 2
                          ? 'Create the bill now and record payment later.'
                          : _paymentMode == 1
                          ? 'Create a QR for the amount collected now.'
                          : 'Create a QR for the full bill total.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_paymentMode == 1) ...[
                      TextFormField(
                        key: const Key('sale-advance-amount'),
                        controller: _advanceAmount,
                        enabled: enabled,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: !_hasLines
                              ? 'Advance amount'
                              : 'Advance amount ($_currency)',
                          helperText: 'The amount can be changed again before each payment is recorded.',
                        ),
                        validator: (value) {
                          try {
                            final amount = parseMoney(value ?? '');
                            final total = preview?.totalMinor;
                            if (total == null || amount < 1 || amount > total) {
                              return 'Enter an amount greater than zero and no more than the bill total.';
                            }
                            return null;
                          } on AppFailure catch (error) {
                            return error.message;
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    DetailHint(
                      '${_checkout == null ? 'Saving the bill deducts stock.' : 'Stock is deducted only for inventory products added to this bill.'} The next screen shows a QR for your selected full or advance amount. The owner records payment after checking it in the payment app.',
                    ),
                    const SizedBox(height: 20),
                    if (_failure != null) ...[
                      InlineNotice(_failure!.displayMessage, isError: true),
                      const SizedBox(height: 12),
                    ],
                    if (_uncertain) ...[
                      InlineNotice(
                        'The save result is not confirmed. Retry this same bill to avoid a duplicate. Reference: $_id',
                      ),
                      const SizedBox(height: 16),
                    ],
                    FilledButton(
                      key: const Key('save-sale'),
                      onPressed: _saving || !_hasLines ? null : _save,
                      child: Text(
                        _saving
                            ? 'Saving…'
                            : _uncertain
                            ? 'Check and retry sale'
                            : 'Generate bill',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _priceChanged(Product product) {
    try {
      return parseMoney(_prices[product.sku]!.text) != product.priceMinor;
    } on AppFailure {
      return true;
    }
  }

  Widget _addProductButton(bool enabled) => OutlinedButton.icon(
    key: const Key('add-sale-product'),
    onPressed: enabled ? _add : null,
    icon: const Icon(Icons.add_rounded),
    label: Text('Add product ($_lineCount added)'),
  );
}

class _CheckoutLines extends StatelessWidget {
  const _CheckoutLines({required this.lines, required this.currency});

  final List<SaleLine> lines;
  final String currency;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: const Key('sale-checkout-lines'),
    initiallyExpanded: false,
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 16),
    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
    title: Text(
      'QuickPrice items (${lines.length})',
      style: Theme.of(context).textTheme.titleMedium,
    ),
    subtitle: Text(
      '${formatMoney(lines.fold<int>(0, (total, line) => total + line.totalMinor), currency)} · Review items',
      key: const Key('sale-checkout-summary-total'),
    ),
    children: [
      const Text('To change these items, go back to QuickPrice.'),
      for (final line in lines)
        Padding(
          key: ValueKey('sale-checkout-line-${line.sku}'),
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.name, style: Theme.of(context).textTheme.titleSmall),
              for (final parameter in line.parameters)
                Text('${parameter.name} · ${parameter.value}'),
              Text(
                'Quantity ${line.quantity} · Unit price ${line.pricing!.unitPriceRounded ? 'approx. ' : ''}${formatMoney(line.unitPriceMinor, currency)}',
              ),
              Text(
                'Line total ${formatMoney(line.totalMinor, currency)}',
                key: ValueKey('sale-checkout-total-${line.sku}'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (line.pricing!.taxMinor > 0)
                Text('Tax ${formatMoney(line.pricing!.taxMinor, currency)}'),
            ],
          ),
        ),
    ],
  );
}

class _ParameterFields {
  _ParameterFields(String name, String value)
    : name = TextEditingController(text: name),
      value = TextEditingController(text: value);

  final TextEditingController name;
  final TextEditingController value;

  void dispose() {
    name.dispose();
    value.dispose();
  }
}
