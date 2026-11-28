import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/firebase/firebase_bootstrap.dart';
import '../application/calculator_session.dart';
import '../application/estimate_builder.dart';
import '../application/workspace.dart';
import '../application/product_setup.dart';
import '../domain/pricing_repository.dart';
import '../domain/universal/rate_card.dart';
import 'pricing_widgets.dart';
import 'estimate_screen.dart';
import 'rate_cards_screen.dart';
import 'simple_calculator_screen.dart';

class QuickPriceScreen extends StatefulWidget {
  const QuickPriceScreen({
    super.key,
    required this.workspace,
    this.firebaseSetup,
    this.onExit,
    this.onCheckout,
    this.onQuotation,
    this.onQuotationHistory,
  });
  final QuickPriceWorkspace workspace;
  final Future<FirebaseSetupStatus>? firebaseSetup;
  final VoidCallback? onExit;
  final Future<String?> Function(QuickPriceEstimate estimate)? onCheckout;
  final Future<void> Function(QuickPriceEstimate estimate)? onQuotation;
  final VoidCallback? onQuotationHistory;
  @override
  State<QuickPriceScreen> createState() => _QuickPriceScreenState();
}

class _QuickPriceScreenState extends State<QuickPriceScreen>
    with WidgetsBindingObserver {
  final session = CalculatorSession();
  late final writer = DraftWriter(widget.workspace.values);
  late final estimateRepository = EstimateRepository(widget.workspace);
  QuickPriceEstimate? estimate;
  String? estimateError, editingLineId;
  bool estimateBusy = false;
  bool currentItemAdded = false;
  List<PricingProfileSummary> profiles = [];
  PublishedUniversalRateCard? card;
  String? profileId, error, persistenceError;
  bool loading = true, restoring = true;
  int loadGeneration = 0;
  Timer? expiryTimer;
  List<UniversalProduct> get products {
    final card = this.card;
    if (card == null) return [];
    final categories = {for (final c in card.card.categories) c.id: c};
    bool active(String id) {
      final category = categories[id];
      return category != null &&
          category.active &&
          (category.parentId == null || active(category.parentId!));
    }

    return card.card.products.where((p) => active(p.categoryId)).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session.addListener(_changed);
    _load(initial: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    expiryTimer?.cancel();
    session.removeListener(_changed);
    session.dispose();
    // Calculator and estimate state are durable drafts. They are cleared only
    // after a quotation/bill is completed, never merely because the app is
    // closed or backgrounded.
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
    // DraftWriter already persists every change; reopening the app restores it.
  }

  void _changed() {
    if (!mounted) return;
    currentItemAdded = false;
    setState(() {});
  }

  Future<void> _load({bool initial = false, String? selectedProfile}) async {
    final generation = ++loadGeneration;
    if (mounted) {
      setState(() {
        loading = true;
        restoring = true;
        error = null;
      });
    }
    try {
      if (initial) {
        estimate = QuickPriceEstimate.empty(widget.workspace.businessId);
        await widget.workspace.clearWorkingDraft();
      }
      final all = (await widget.workspace.profiles())
          .where((p) => p.status != 'archived')
          .toList();
      final requested = selectedProfile ?? profileId;
      final selected =
          all.where((p) => p.id == requested).firstOrNull ??
          all.where((p) => p.status == 'published').firstOrNull ??
          all.firstOrNull;
      final next = selected == null
          ? null
          : await widget.workspace.repository.activeCard(
              selected.id,
              at: DateTime.now().toUtc(),
            );
      if (!mounted || generation != loadGeneration) return;
      profiles = all;
      profileId = selected?.id;
      card = next;
      final wanted = session.product?.id;
      final available = products;
      final product =
          available.where((p) => p.id == wanted).firstOrNull ??
          available.firstOrNull;
      if (product != null) {
        session.select(product);
        if (initial) session.resetMeasurements();
      } else {
        session.product = null;
        session.result = null;
        session.error = null;
      }
      expiryTimer?.cancel();
      if (next?.expiresAt != null) {
        final duration = next!.expiresAt!.difference(DateTime.now().toUtc());
        expiryTimer = Timer(
          duration.isNegative ? Duration.zero : duration,
          () => _load(),
        );
      }
      setState(() {
        loading = false;
        restoring = false;
      });
      if (product != null) _changed();
    } catch (e) {
      if (mounted && generation == loadGeneration) {
        setState(() {
          loading = false;
          restoring = false;
          error = pricingError(e);
          card = null;
          session.result = null;
        });
      }
    }
  }

  Future<void> _manage() async {
    await writer.flush();
    if (!mounted) return;
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => RateCardsScreen(
          workspace: widget.workspace,
          createOnOpen: profiles.isEmpty,
        ),
      ),
    );
    await _load(selectedProfile: selected);
  }

  Future<void> _editRates([String? id]) async {
    await writer.flush();
    if (!mounted) return;
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => SimpleCalculatorScreen(
          workspace: widget.workspace,
          profileId: id ?? profileId,
        ),
      ),
    );
    await _load(selectedProfile: selected);
  }

  Future<void> _editCustomerRate() async {
    final controller = TextEditingController(
      text: session.baseRateOverrideText ?? session.availableBaseRateText ?? '',
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customer rate'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText:
                'Rate per ${unitShort[session.availableBaseRateUnit] ?? session.availableBaseRateUnit}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    session.setBaseRateOverride(value);
  }

  Future<void> _retryEstimate() async {
    try {
      final saved = await estimateRepository.load();
      if (mounted) {
        setState(() {
          estimate = saved;
          estimateError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => estimateError = pricingError(e));
    }
  }

  Future<void> _addToEstimate() async {
    if (estimateBusy ||
        estimate == null ||
        session.result == null ||
        profileId == null) {
      return;
    }
    setState(() {
      estimateBusy = true;
      estimateError = null;
    });
    try {
      final line = EstimateLine.capture(
        session: session,
        profileId: profileId!,
      );
      final active = estimate!.convertedSaleId == null
          ? estimate!
          : QuickPriceEstimate.empty(widget.workspace.businessId);
      final next = editingLineId == null
          ? active.append(line)
          : active.replace(editingLineId!, line);
      await estimateRepository.save(next);
      if (!mounted) return;
      setState(() {
        estimate = next;
        editingLineId = null;
        currentItemAdded = true;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item saved · ${next.lines.length} items in estimate'),
          action: SnackBarAction(label: 'View', onPressed: _openEstimate),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => estimateError = pricingError(e));
    } finally {
      if (mounted) setState(() => estimateBusy = false);
    }
  }

  Future<void> _openEstimate() async {
    if (estimateBusy || estimate == null) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    await writer.flush();
    if (!mounted) return;
    final edit = await Navigator.of(context).push<EstimateLine>(
      MaterialPageRoute(
        builder: (_) => EstimateScreen(
          estimate: estimate!,
          repository: estimateRepository,
          onCheckout: widget.onCheckout,
          onQuotation: widget.onQuotation,
        ),
      ),
    );
    if (!mounted) return;
    await _retryEstimate();
    if (edit == null || !mounted) return;
    await _load(selectedProfile: edit.profileId);
    if (!mounted) return;
    final product = products.where((p) => p.id == edit.product.id).firstOrNull;
    if (product == null) {
      setState(
        () => estimateError = 'This product is no longer available for editing. Its saved estimate price is unchanged.',
      );
      return;
    }
    session.select(product);
    session.restore(edit.calculatorState);
    setState(() => editingLineId = edit.id);
  }

  Future<void> _openSavedEstimates() async {
    final selected = await Navigator.of(context).push<QuickPriceEstimate>(
      MaterialPageRoute(
        builder: (_) => SavedEstimatesScreen(repository: estimateRepository),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      estimate = selected;
      editingLineId = null;
    });
    if (selected.lines.isNotEmpty) {
      final line = selected.lines.first;
      await _load(selectedProfile: line.profileId);
      if (!mounted) return;
      final product = products
          .where((p) => p.id == line.product.id)
          .firstOrNull;
      if (product != null) {
        session.select(product);
        session.restore(line.calculatorState);
        setState(() => editingLineId = line.id);
      }
    }
  }

  Future<void> _saveDraft() async {
    if (session.result != null && !currentItemAdded) {
      await _addToEstimate();
    }
    if (!mounted) return;
    final active = estimate;
    if (active == null || active.lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an item before saving a draft.')),
      );
      return;
    }
    try {
      await estimateRepository.saveDraft(active);
      await estimateRepository.clear();
      if (!mounted) return;
      setState(() {
        estimate = QuickPriceEstimate.empty(widget.workspace.businessId);
        editingLineId = null;
        currentItemAdded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estimate saved as a draft.')),
      );
    } catch (error) {
      if (mounted) setState(() => estimateError = pricingError(error));
    }
  }

  Future<void> _requestExit() async {
    if (widget.onExit == null) return;
    if (estimate?.lines.isNotEmpty != true && session.result == null) {
      widget.onExit!();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Quick Price?'),
        content: const Text('Save this estimate as a draft before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save draft'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'stay') return;
    if (choice == 'save') {
      if (session.result != null) await _addToEstimate();
      if (!mounted) return;
      await _saveDraft();
    } else {
      await estimateRepository.clear();
      await widget.workspace.clearWorkingDraft();
    }
    if (mounted) widget.onExit!();
  }

  Future<void> _quotation() async {
    if (estimateBusy || widget.onQuotation == null || estimate == null) return;
    if (estimate!.lines.isEmpty || estimate!.convertedSaleId != null) {
      await _addToEstimate();
    }
    if (!mounted || estimate!.lines.isEmpty) return;
    setState(() {
      estimateBusy = true;
      estimateError = null;
    });
    try {
      await writer.flush();
      await estimateRepository.save(estimate!);
      await widget.onQuotation!(estimate!);
      await estimateRepository.clear();
      if (mounted) {
        setState(() {
          estimate = QuickPriceEstimate.empty(widget.workspace.businessId);
          editingLineId = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => estimateError = pricingError(e));
    } finally {
      if (mounted) setState(() => estimateBusy = false);
    }
  }

  Future<void> _copy({bool share = false}) async {
    session.recalculate();
    if (session.result == null) return;
    try {
      final text = session.publicPriceText();
      if (share && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await const MethodChannel('com.hyner.hyner/share')
            .invokeMethod<void>('shareText', {'text': text});
      } else {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Price copied')));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sharing is unavailable. Try creating a quotation PDF.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _info() => showDialog<void>(
    useRootNavigator: false,
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Hyner QuickPrice'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.workspace.preview
                  ? 'This browser preview is temporary. Closing the page clears its data.'
                  : 'Your rates and unfinished inputs are saved on this Android device. Removing the app clears local data.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Add different products and sizes to one estimate, then continue to Sales with the saved prices. Custom measured items do not change inventory. Calculations work offline; cloud sync is not enabled.',
            ),
            const SizedBox(height: 16),
            if (widget.firebaseSetup != null)
              FutureBuilder<FirebaseSetupStatus>(
                future: widget.firebaseSetup,
                builder: (context, snapshot) => Text(switch (snapshot.data) {
                  FirebaseSetupStatus.ready => 'Firebase configuration is ready. Cloud sync is not enabled.',
                  FirebaseSetupStatus.unavailable => 'Firebase setup could not start. Local pricing is still available.',
                  FirebaseSetupStatus.notConfigured =>
                    'Firebase is not configured for this platform.',
                  _ => 'Firebase setup has not completed.',
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope<Object?>(
      canPop: widget.onExit == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.onExit != null) unawaited(_requestExit());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: widget.onExit == null
              ? null
              : BackButton(onPressed: _requestExit),
          title: const Text(
            'QuickPrice',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: 'Saved estimates',
              onPressed: estimateBusy ? null : _openSavedEstimates,
              icon: Badge(
                label: Text('${estimate?.lines.length ?? 0}'),
                isLabelVisible: estimate?.lines.isNotEmpty == true,
                child: const Icon(Icons.receipt_long_outlined),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Calculator options',
              onSelected: (action) {
                switch (action) {
                  case 'save-draft':
                    unawaited(_saveDraft());
                    break;
                  case 'open-draft':
                    unawaited(_openSavedEstimates());
                    break;
                  case 'manage':
                    unawaited(_manage());
                    break;
                  case 'rates':
                    unawaited(_editRates());
                    break;
                  case 'quotations':
                    widget.onQuotationHistory?.call();
                    break;
                  case 'about':
                    unawaited(_info());
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'save-draft',
                  child: Text('Save current work as draft'),
                ),
                PopupMenuItem(
                  value: 'open-draft',
                  child: const Text('Open estimate drafts'),
                ),
                const PopupMenuItem(
                  value: 'manage',
                  child: Text('Calculators and rates'),
                ),
                PopupMenuItem(
                  value: 'rates',
                  child: const Text('Edit selling rates'),
                ),
                if (widget.onQuotationHistory != null)
                  const PopupMenuItem(
                    value: 'quotations',
                    child: Text('Saved quotations'),
                  ),
                const PopupMenuItem(
                  value: 'about',
                  child: Text('About this workspace'),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? _errorView()
                  : card == null || products.isEmpty
                  ? _emptyView()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final compact =
                            constraints.maxHeight < 520 ||
                            MediaQuery.viewInsetsOf(context).bottom > 0 ||
                            MediaQuery.textScalerOf(context).scale(16) > 22;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                children: [
                                  if (profiles.length > 1)
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        for (final p in profiles)
                                          ChoiceChip(
                                            label: Text(p.name),
                                            selected: profileId == p.id,
                                            onSelected: (_) =>
                                                _load(selectedProfile: p.id),
                                          ),
                                      ],
                                    ),
                                  const SizedBox(height: 8),
                                  if (products.length == 1)
                                    Text(
                                      products.single.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    )
                                  else if (products.length <= 8)
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        for (final product in products)
                                          ChoiceChip(
                                            label: Text(product.name),
                                            selected:
                                                session.product?.id ==
                                                product.id,
                                            onSelected: (_) {
                                              HapticFeedback.selectionClick();
                                              session.select(product);
                                            },
                                          ),
                                      ],
                                    )
                                  else
                                    SelectField(
                                      label: 'Product',
                                      value: session.product?.id,
                                      options: {
                                        for (final p in products) p.id: p.name,
                                      },
                                      onChanged: (id) => session.select(
                                        products.singleWhere((p) => p.id == id),
                                      ),
                                    ),
                                  const SizedBox(height: 24),
                                  if (editingLineId != null) ...[
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Editing estimate item · current rates apply',
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => setState(
                                            () => editingLineId = null,
                                          ),
                                          child: const Text('Cancel edit'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  DynamicInputs(session: session),
                                  QuantityControl(
                                    session: session,
                                    trailing:
                                        session.availableBaseRateText == null
                                        ? null
                                        : OutlinedButton.icon(
                                            key: ValueKey(
                                              'calculation-rate-${session.product!.id}',
                                            ),
                                            onPressed: _editCustomerRate,
                                            icon: const Icon(
                                              Icons.sell_outlined,
                                              size: 18,
                                            ),
                                            label: const Text('Rate'),
                                          ),
                                  ),
                                  if (session.result != null &&
                                      session.result!.amounts.taxMinor >
                                          BigInt.zero) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'Tax ${moneyText(session.result!.amounts.taxMinor, card!.card.currency)} · Excl. tax ${moneyText(session.result!.amounts.netMinor, card!.card.currency)}',
                                    ),
                                  ],
                                  if (session.result != null)
                                    for (final warning
                                        in session.result!.warnings.toSet())
                                      MessageLine(warning),
                                  if (estimateError != null) ...[
                                    MessageLine(estimateError!, error: true),
                                    if (estimate == null)
                                      TextButton(
                                        onPressed: _retryEstimate,
                                        child: const Text('Retry estimate'),
                                      ),
                                  ],
                                  if (persistenceError != null)
                                    MessageLine(persistenceError!, error: true),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    constraints.maxHeight *
                                    (compact ? 0.48 : 0.43),
                              ),
                              child: SingleChildScrollView(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerLow,
                                    border: Border(
                                      top: BorderSide(
                                        color: scheme.outlineVariant,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      20,
                                      compact ? 10 : 16,
                                      20,
                                      12,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        PricePanel(
                                          session: session,
                                          compact: true,
                                          breakdown: false,
                                          summaryOnly: true,
                                          title: 'Amount total',
                                        ),
                                        const SizedBox(height: 8),
                                        FilledButton.icon(
                                          key: const Key('add-to-estimate'),
                                          onPressed:
                                              estimateBusy ||
                                                  estimate == null ||
                                                  session.result == null
                                              ? null
                                              : _addToEstimate,
                                          icon: const Icon(Icons.add_rounded),
                                          label: Text(
                                            editingLineId != null
                                                ? 'Update estimate item'
                                                : estimate?.convertedSaleId !=
                                                      null
                                                ? 'Add to new estimate'
                                                : 'Add to Estimate',
                                          ),
                                        ),
                                        if (estimate?.lines.isNotEmpty == true)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: TextButton.icon(
                                                    key: const Key(
                                                      'view-estimate',
                                                    ),
                                                    onPressed: estimateBusy
                                                        ? null
                                                        : _openEstimate,
                                                    icon: const Icon(
                                                      Icons
                                                          .receipt_long_outlined,
                                                    ),
                                                    label: Text(
                                                      '${estimate!.lines.length} items · Estimate',
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: TextButton.icon(
                                                    onPressed: estimateBusy
                                                        ? null
                                                        : _saveDraft,
                                                    icon: const Icon(
                                                      Icons
                                                          .bookmark_add_outlined,
                                                    ),
                                                    label: const Text(
                                                      'Save draft',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        _secondaryActions(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _secondaryActions() {
    final large = MediaQuery.textScalerOf(context).scale(16) > 22;
    final copy = TextButton(
      key: const Key('quickprice-quotation'),
      onPressed:
          estimateBusy ||
              widget.onQuotation == null ||
              (session.result == null && estimate?.lines.isNotEmpty != true)
          ? null
          : _quotation,
      child: const Text('Quotation', textAlign: TextAlign.center),
    );
    final breakdown = TextButton(
      onPressed: session.result == null ? null : _showBreakdown,
      child: const Text('Price breakdown', textAlign: TextAlign.center),
    );
    final canShare = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          copy,
          breakdown,
          if (canShare)
            TextButton.icon(
              onPressed: session.result == null
                  ? null
                  : () => _copy(share: true),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share price'),
            ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: copy),
        Expanded(child: breakdown),
        if (canShare)
          IconButton(
            tooltip: 'Share price',
            onPressed: session.result == null ? null : () => _copy(share: true),
            icon: const Icon(Icons.share_outlined),
          ),
      ],
    );
  }

  Future<void> _showBreakdown() => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: PricePanel(session: session, expandBreakdown: true),
    ),
  );

  Widget _emptyView() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 32),
      Icon(
        Icons.calculate_outlined,
        size: 60,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 24),
      Text(
        'Set up your calculator',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 16),
      Text(
        profiles.isEmpty
            ? 'No selling rates are configured yet. Set up a calculator with your products and rates.'
            : 'No active published rates are available. Finish your draft or publish a current rate card to calculate.',
      ),
      const SizedBox(height: 28),
      for (final profile in profiles)
        ListTile(
          leading: const Icon(Icons.calculate_outlined),
          title: Text(profile.name),
          subtitle: const Text('Tap to finish rates and use'),
          onTap: () => _editRates(profile.id),
        ),
      FilledButton.icon(
        onPressed: _manage,
        icon: const Icon(Icons.add),
        label: Text(profiles.isEmpty ? 'Create calculator' : 'Set up rates'),
      ),
      const SizedBox(height: 16),
      Text(
        widget.workspace.preview
            ? 'Browser preview only. Changes are temporary.'
            : 'Works offline. Your data stays on this device.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ],
  );
  Widget _errorView() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      MessageLine(error!, error: true),
      FilledButton(onPressed: () => _load(), child: const Text('Retry')),
    ],
  );
}
