import '../../../core/widgets/financial_amount.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/calculator_session.dart';
import '../application/estimate_builder.dart';

/// A customer-safe working estimate. Internal rate/rule snapshots never render.
class EstimateScreen extends StatefulWidget {
  const EstimateScreen({
    super.key,
    required this.estimate,
    required this.repository,
    this.onCheckout,
    this.onQuotation,
  });
  final QuickPriceEstimate estimate;
  final EstimateRepository repository;
  final Future<String?> Function(QuickPriceEstimate estimate)? onCheckout;
  final Future<void> Function(QuickPriceEstimate estimate)? onQuotation;
  @override
  State<EstimateScreen> createState() => _EstimateScreenState();
}

class _EstimateScreenState extends State<EstimateScreen> {
  late QuickPriceEstimate estimate = widget.estimate;
  bool busy = false;
  String? error;

  Future<void> _change(QuickPriceEstimate next) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.save(next);
      if (mounted) setState(() => estimate = next);
    } catch (e) {
      if (mounted) setState(() => error = pricingError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _share({bool share = false}) async {
    try {
      final text = estimate.publicText();
      if (share && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await const MethodChannel('com.hyner.hyner/share')
            .invokeMethod<void>('shareText', {'text': text});
      } else {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Estimate copied')));
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'The estimate could not be shared. Try copying it.',
        );
      }
    }
  }

  Future<void> _quotation() async {
    if (busy || estimate.lines.isEmpty || widget.onQuotation == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.save(estimate);
      await widget.onQuotation!(estimate);
    } catch (e) {
      if (mounted) setState(() => error = pricingError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _checkout() async {
    if (busy || estimate.lines.isEmpty || widget.onCheckout == null) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.save(estimate);
      final saleId = await widget.onCheckout!(estimate);
      if (!mounted) return;
      final saved = await widget.repository.load();
      if (!mounted) return;
      if (saved.id == estimate.id) {
        if (saleId != null && saved.convertedSaleId == null) {
          final next = saved.markConverted(saleId);
          await widget.repository.save(next);
          if (mounted) setState(() => estimate = next);
        } else {
          setState(() => estimate = saved);
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = pricingError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _newEstimate() async {
    if (busy) return;
    if (estimate.lines.isNotEmpty && estimate.convertedSaleId == null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a new estimate?'),
          content: const Text('This clears the items in the current draft.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep draft'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start new'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _change(QuickPriceEstimate.empty(estimate.businessId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = estimate.currency;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estimate'),
        actions: [
          IconButton(
            tooltip: 'New estimate',
            onPressed: busy ? null : _newEstimate,
            icon: const Icon(Icons.note_add_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (estimate.convertedSaleId != null)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  'Bill created. This estimate keeps the prices used on that bill.',
                ),
              ),
            if (estimate.convertedSaleId == null &&
                Navigator.of(context).canPop())
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextButton.icon(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add another item'),
                  ),
                ),
              ),
            Expanded(
              child: estimate.lines.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Add products from QuickPrice. Each item can have a different size, type and quantity.',
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      buildDefaultDragHandles:
                          estimate.convertedSaleId == null && !busy,
                      itemCount: estimate.lines.length,
                      onReorderItem: (oldIndex, newIndex) {
                        if (!busy && estimate.convertedSaleId == null) {
                          _change(
                            estimate.reorder(
                              oldIndex,
                              newIndex > oldIndex ? newIndex + 1 : newIndex,
                            ),
                          );
                        }
                      },
                      itemBuilder: (context, index) {
                        final line = estimate.lines[index];
                        return Container(
                          key: ValueKey(line.id),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${index + 1}. ${line.product.name}',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ),
                                  if (estimate.convertedSaleId == null)
                                    PopupMenuButton<String>(
                                      tooltip: 'Item options',
                                      enabled: !busy,
                                      onSelected: (action) {
                                        if (action == 'edit') {
                                          Navigator.pop(context, line);
                                        }
                                        if (action == 'duplicate') {
                                          _change(estimate.duplicate(line.id));
                                        }
                                        if (action == 'remove') {
                                          _change(estimate.remove(line.id));
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit item'),
                                        ),
                                        PopupMenuItem(
                                          value: 'duplicate',
                                          child: Text('Duplicate item'),
                                        ),
                                        PopupMenuItem(
                                          value: 'remove',
                                          child: Text('Remove item'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              for (final parameter in line.parameters)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${parameter.name}: ${parameter.value}',
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Text(
                                'Quantity: ${line.pricing.quantity} · ${line.pricing.unitPriceRounded ? 'Approx. ' : ''}${moneyText(BigInt.from(line.pricing.unitPriceMinor), currency!)} per item',
                              ),
                              const SizedBox(height: 4),
                              FinancialAmount(
                                moneyText(
                                  BigInt.from(line.pricing.totalMinor),
                                  currency,
                                ),
                                style: theme.textTheme.titleLarge,
                                compact: true,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (currency != null)
              Container(
                width: double.infinity,
                color: theme.colorScheme.surfaceContainerLow,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${estimate.lines.length} items · Estimated total'),
                    FinancialAmount(
                      moneyText(estimate.totalMinor, currency),
                      textKey: const Key('estimate-grand-total'),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      prominent: true,
                    ),
                    if (estimate.lines.any((line) => line.pricing.taxMinor > 0))
                      Text(
                        'Excluding tax ${moneyText(estimate.lines.fold<BigInt>(BigInt.zero, (total, line) => total + BigInt.from(line.pricing.netMinor)), currency)} · Tax ${moneyText(estimate.lines.fold<BigInt>(BigInt.zero, (total, line) => total + BigInt.from(line.pricing.taxMinor)), currency)}',
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('estimate-quotation'),
                      onPressed:
                          busy ||
                              widget.onQuotation == null ||
                              estimate.convertedSaleId != null
                          ? null
                          : _quotation,
                      icon: const Icon(Icons.request_quote_outlined),
                      label: const Text('Quotation PDF'),
                    ),
                    const SizedBox(height: 6),
                    FilledButton.icon(
                      key: const Key('estimate-checkout'),
                      onPressed: busy || widget.onCheckout == null
                          ? null
                          : _checkout,
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text(
                        estimate.convertedSaleId == null
                            ? 'Continue to Sales'
                            : 'Open saved bill',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: busy ? null : _share,
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copy estimate'),
                        ),
                        TextButton.icon(
                          onPressed: busy ? null : () => _share(share: true),
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Share estimate'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
