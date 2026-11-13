import 'package:flutter/material.dart';

import '../application/calculator_session.dart';
import '../application/product_setup.dart';
import '../application/workspace.dart';
import '../domain/exact.dart';
import '../domain/pricing_models.dart';
import '../domain/pricing_repository.dart';
import '../domain/universal/rate_card.dart';
import 'pricing_widgets.dart';
import 'product_setup_screen.dart';
import 'simple_calculator_screen.dart';

class RateCardsScreen extends StatefulWidget {
  const RateCardsScreen({
    super.key,
    required this.workspace,
    this.createOnOpen = false,
  });
  final QuickPriceWorkspace workspace;
  final bool createOnOpen;
  @override
  State<RateCardsScreen> createState() => _RateCardsScreenState();
}

class _RateCardsScreenState extends State<RateCardsScreen> {
  List<PricingProfileSummary>? profiles;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    _load();
    if (widget.createOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _create();
      });
    }
  }

  Future<void> _load() async {
    try {
      final data = await widget.workspace.profiles();
      if (mounted) {
        setState(() {
          profiles = data;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = pricingError(e));
    }
  }

  Future<void> _create() async {
    if (busy) return;
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => SimpleCalculatorScreen(workspace: widget.workspace),
      ),
    );
    if (!mounted) return;
    if (selected != null && Navigator.canPop(context)) {
      Navigator.pop(context, selected);
      return;
    }
    await _load();
  }

  Future<void> _editRates(
    PricingProfileSummary profile, {
    bool advanced = false,
  }) async {
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => advanced
            ? RateCardEditor(
                workspace: widget.workspace,
                profileId: profile.id,
                archived: profile.status == 'archived',
              )
            : SimpleCalculatorScreen(
                workspace: widget.workspace,
                profileId: profile.id,
              ),
      ),
    );
    if (!mounted) return;
    if (selected != null && Navigator.canPop(context)) {
      Navigator.pop(context, selected);
      return;
    }
    await _load();
  }

  Future<void> _rename(PricingProfileSummary profile) async {
    final name = await showDialog<String>(
      useRootNavigator: false,
      context: context,
      builder: (_) => _RenameCalculatorDialog(initialName: profile.name),
    );
    if (name == null || !mounted || name == profile.name) return;
    setState(() => busy = true);
    try {
      final current = await widget.workspace.repository.readDraft(profile.id);
      final card = current.card;
      await widget.workspace.repository.saveDraft(
        profile.id,
        UniversalRateCardDraft(
          name: name,
          currency: card.currency,
          description: card.description,
          industryTemplate: card.industryTemplate,
          categories: card.categories,
          products: card.products,
        ),
        expectedRevision: current.revision,
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => error = pricingError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete(PricingProfileSummary profile) async {
    final confirmed = await showDialog<bool>(
      useRootNavigator: false,
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete calculator?'),
        content: Text(
          '“${profile.name}” will be removed from your active calculators and can no longer be used for new calculations. Its calculator data is retained as archived pricing history; saved bills and estimates remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete calculator'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // The repository's archive operation preserves immutable published
      // versions, audit records, and snapshots already used by bills/estimates.
      await widget.workspace.repository.archive(profile.id);
      await _load();
    } catch (e) {
      if (mounted) setState(() => error = pricingError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _advancedCreate() async {
    String name = '', currency = 'INR';
    final requested = await showDialog<bool>(
      useRootNavigator: false,
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('New calculator'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueField(
                  label: 'Calculator name',
                  value: name,
                  helper: 'For example, Door prices or Hardware prices',
                  onChanged: (v) => set(() => name = v),
                ),
                const SizedBox(height: 16),
                SelectField(
                  label: 'Currency',
                  value: currency,
                  options: const {
                    'INR': 'INR · Indian rupee',
                    'USD': 'USD · US dollar',
                    'EUR': 'EUR · Euro',
                    'GBP': 'GBP · British pound',
                  },
                  onChanged: (v) => set(() => currency = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: name.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (requested != true || !mounted) return;
    setState(() => busy = true);
    try {
      final draft = await widget.workspace.repository.createProfile(
        newPricingId(),
        UniversalRateCardDraft(
          name: name.trim(),
          currency: Currency(currency, 2),
        ),
      );
      if (mounted) {
        final selected = await Navigator.push<String>(
          context,
          MaterialPageRoute<String>(
            builder: (_) => RateCardEditor(
              workspace: widget.workspace,
              profileId: draft.profileId,
            ),
          ),
        );
        if (selected != null && mounted && Navigator.canPop(context)) {
          Navigator.pop(context, selected);
          return;
        }
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => error = pricingError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeProfiles = (profiles ?? <PricingProfileSummary>[])
        .where((profile) => profile.status != 'archived')
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your calculators'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => _advancedCreate(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'advanced', child: Text('Advanced setup')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Set rates once. Use them at the counter.',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.workspace.preview
                      ? 'Browser preview · changes disappear when this page closes.'
                      : 'Tap a saved calculator to use it. Edit its rates whenever you need.',
                ),
                if (error != null) MessageLine(error!, error: true),
                if (profiles == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (profiles != null && activeProfiles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No selling rates are configured yet. Create your first calculator to begin.',
                    ),
                  ),
                for (final profile in activeProfiles)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calculate_outlined),
                    title: Text(
                      profile.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      profile.status == 'published'
                          ? 'Ready to use'
                          : 'Finish your rates',
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Calculator options',
                      onSelected: (action) {
                        switch (action) {
                          case 'rates':
                            _editRates(profile);
                          case 'advanced':
                            _editRates(profile, advanced: true);
                          case 'rename':
                            _rename(profile);
                          case 'delete':
                            _delete(profile);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'rates',
                          child: Text('Edit selling rates'),
                        ),
                        PopupMenuItem(
                          value: 'advanced',
                          child: Text('Advanced settings'),
                        ),
                        PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename calculator'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete calculator'),
                        ),
                      ],
                    ),
                    onTap: busy
                        ? null
                        : () {
                            if (profile.status == 'published' &&
                                Navigator.canPop(context)) {
                              Navigator.pop(context, profile.id);
                            } else {
                              _editRates(profile);
                            }
                          },
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: busy ? null : _create,
                  icon: const Icon(Icons.add),
                  label: const Text('Create calculator'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RenameCalculatorDialog extends StatefulWidget {
  const _RenameCalculatorDialog({required this.initialName});
  final String initialName;

  @override
  State<_RenameCalculatorDialog> createState() =>
      _RenameCalculatorDialogState();
}

class _RenameCalculatorDialogState extends State<_RenameCalculatorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final value = _name.text.trim();
    if (value.isNotEmpty && value.length <= 120) {
      Navigator.pop(context, value);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename calculator'),
    content: TextField(
      key: const Key('rename-calculator-name'),
      controller: _name,
      autofocus: true,
      maxLength: 120,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(labelText: 'Calculator name'),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('save-calculator-name'),
        onPressed: _name.text.trim().isEmpty ? null : _save,
        child: const Text('Save name'),
      ),
    ],
  );
}

class RateCardEditor extends StatefulWidget {
  const RateCardEditor({
    super.key,
    required this.workspace,
    required this.profileId,
    this.archived = false,
  });
  final QuickPriceWorkspace workspace;
  final String profileId;
  final bool archived;
  @override
  State<RateCardEditor> createState() => _RateCardEditorState();
}

class _RateCardEditorState extends State<RateCardEditor> {
  UniversalStoredDraft? draft;
  String? error;
  bool busy = false, pendingSetup = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.workspace.repository.readDraft(
        widget.profileId,
      );
      final pending = await widget.workspace.values.read(
        'setup_${widget.profileId}_new',
      );
      if (mounted) {
        setState(() {
          draft = value;
          pendingSetup = pending != null;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = pricingError(e));
    }
  }

  Future<void> _edit([UniversalProduct? product]) async {
    if (busy || draft == null) return;
    setState(() => busy = true);
    try {
      final key = 'setup_${widget.profileId}_${product?.id ?? 'new'}';
      final stored = await widget.workspace.values.read(key);
      if (product != null && stored == null) {
        throw StateError(
          'This product was created outside the setup wizard. Its saved rates remain available for calculation.',
        );
      }
      final setup = stored == null
          ? ProductSetup.create()
          : ProductSetup.fromJson(stored);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute<bool>(
            builder: (_) => ProductSetupScreen(
              workspace: widget.workspace,
              setup: setup,
              storageKey: key,
              currency: draft!.card.currency,
              categories: draft!.card.categories,
              onSave: (product, setup) async {
                final current = draft!;
                final categories = [...current.card.categories];
                if (!categories.any((c) => c.id == product.categoryId)) {
                  final categoryName = (setup.data['categoryName'] as String)
                      .trim();
                  categories.add(
                    PricingCategory(
                      id: product.categoryId,
                      name: categoryName.isEmpty ? product.name : categoryName,
                      parentId: (setup.data['parentId'] as String).isEmpty
                          ? null
                          : setup.data['parentId'] as String,
                      sortOrder: categories.length,
                    ),
                  );
                }
                final products = [...current.card.products];
                final index = products.indexWhere((p) => p.id == product.id);
                if (index < 0) {
                  products.add(product);
                } else {
                  products[index] = product;
                }
                final saved = await widget.workspace.repository.saveDraft(
                  widget.profileId,
                  UniversalRateCardDraft(
                    name: current.card.name,
                    currency: current.card.currency,
                    description: current.card.description,
                    industryTemplate: current.card.industryTemplate,
                    categories: categories,
                    products: products,
                  ),
                  expectedRevision: current.revision,
                );
                draft = saved;
                // Keep the editor state associated with the validated product. It is
                // separate from immutable published rule snapshots.
                await widget.workspace.values.write(
                  'setup_${widget.profileId}_${product.id}',
                  setup.data,
                );
                if (key.endsWith('_new')) {
                  await widget.workspace.values.write(key, null);
                }
              },
            ),
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => error = pricingError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _remove(UniversalProduct product) async {
    final yes = await showDialog<bool>(
      useRootNavigator: false,
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${product.name}?'),
        content: const Text(
          'This changes the draft. Published versions keep their original prices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      final current = draft!;
      draft = await widget.workspace.repository.saveDraft(
        widget.profileId,
        UniversalRateCardDraft(
          name: current.card.name,
          currency: current.card.currency,
          categories: current.card.categories,
          products: current.card.products
              .where((p) => p.id != product.id)
              .toList(),
          description: current.card.description,
          industryTemplate: current.card.industryTemplate,
        ),
        expectedRevision: current.revision,
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => error = pricingError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _history() async {
    try {
      final history = await widget.workspace.repository.history(
        widget.profileId,
      );
      if (!mounted) return;
      await showDialog<void>(
        useRootNavigator: false,
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Published versions'),
          content: SizedBox(
            width: 400,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (history.isEmpty) const Text('No versions published yet.'),
                for (final version in history)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Version ${version.version}'),
                    subtitle: Text(
                      'Effective ${version.effectiveAt.toLocal().toString().substring(0, 16)}\n${version.card.products.length} products',
                    ),
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
    } catch (e) {
      if (mounted) setState(() => error = pricingError(e));
    }
  }

  Future<void> _archive() async {
    final yes = await showDialog<bool>(
      useRootNavigator: false,
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive this calculator?'),
        content: const Text(
          'It will no longer be available for new calculations. Its published history stays saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await widget.workspace.repository.archive(widget.profileId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = pricingError(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(draft?.card.name ?? 'Rate card'),
      actions: [
        IconButton(
          tooltip: 'Version history',
          onPressed: busy ? null : _history,
          icon: const Icon(Icons.history),
        ),
        if (!widget.archived)
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'archive') _archive();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'archive',
                child: Text('Archive calculator'),
              ),
            ],
          ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (error != null) MessageLine(error!, error: true),
              if (draft == null && error == null)
                const Center(child: CircularProgressIndicator()),
              if (draft != null) ...[
                Text(
                  widget.archived
                      ? 'Archived calculator'
                      : 'Your draft rate card',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '${draft!.card.currency.code} · ${draft!.card.products.length} products',
                ),
                if (draft!.card.products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      'Add a product, choose how it is priced and enter your selling rate.',
                    ),
                  ),
                for (final product in draft!.card.products)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        strategyLabels[product.rule.strategy.kind.name]!,
                      ),
                      onTap: busy || widget.archived
                          ? null
                          : () => _edit(product),
                      trailing: widget.archived
                          ? null
                          : IconButton(
                              tooltip: 'Remove ${product.name}',
                              onPressed: busy ? null : () => _remove(product),
                              icon: const Icon(Icons.delete_outline),
                            ),
                    ),
                  ),
                if (!widget.archived) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _edit,
                    icon: const Icon(Icons.add),
                    label: Text(
                      pendingSetup ? 'Continue product setup' : 'Add product',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy || draft!.card.products.isEmpty
                        ? null
                        : () async {
                            final published = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute<bool>(
                                builder: (_) => PublishRateCardScreen(
                                  workspace: widget.workspace,
                                  draft: draft!,
                                ),
                              ),
                            );
                            if (published == true && context.mounted) {
                              Navigator.pop(context, widget.profileId);
                              return;
                            }
                            await _load();
                          },
                    child: const Text('Preview & publish'),
                  ),
                  const SizedBox(height: 8),
                  const MessageLine(
                    'Draft changes only become selling rates after you publish.',
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class PublishRateCardScreen extends StatefulWidget {
  const PublishRateCardScreen({
    super.key,
    required this.workspace,
    required this.draft,
  });
  final QuickPriceWorkspace workspace;
  final UniversalStoredDraft draft;
  @override
  State<PublishRateCardScreen> createState() => _PublishRateCardScreenState();
}

class _PublishRateCardScreenState extends State<PublishRateCardScreen> {
  final session = CalculatorSession();
  final Set<String> checkedProducts = {};
  bool confirmed = false, busy = false, loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    session.addListener(_changed);
    _select(widget.draft.card.products.first);
  }

  @override
  void dispose() {
    session.removeListener(_changed);
    session.dispose();
    super.dispose();
  }

  void _changed() {
    if (session.result != null) checkedProducts.add(session.product!.id);
    if (mounted) setState(() {});
  }

  Future<void> _select(UniversalProduct product) async {
    setState(() => loading = true);
    session.select(product);
    try {
      final setup = await widget.workspace.values.read(
        'setup_${widget.draft.profileId}_${product.id}',
      );
      if (!mounted || session.product?.id != product.id) return;
      if (setup?['preview'] is Map<String, dynamic>) {
        session.restore(setup!['preview'] as Map<String, dynamic>);
      }
    } catch (e) {
      if (mounted) setState(() => error = pricingError(e));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _publish() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      for (final product in widget.draft.card.products) {
        await widget.workspace.values.approve(product.rule.tax);
      }
      await widget.workspace.repository.publish(
        widget.draft.profileId,
        expectedRevision: widget.draft.revision,
        effectiveAt: DateTime.now().toUtc(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = pricingError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Preview & publish')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Check each product once',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Published prices are saved as a fixed version. Later edits create a new version.',
              ),
              if (error != null) MessageLine(error!, error: true),
              const SizedBox(height: 20),
              SelectField(
                label: 'Preview product',
                value: session.product?.id,
                options: {
                  for (final p in widget.draft.card.products)
                    p.id:
                        '${checkedProducts.contains(p.id) ? '✓ ' : ''}${p.name}',
                },
                onChanged: (v) => _select(
                  widget.draft.card.products.singleWhere((p) => p.id == v),
                ),
              ),
              const SizedBox(height: 20),
              if (loading)
                const LinearProgressIndicator()
              else ...[
                DynamicInputs(session: session),
                QuantityControl(session: session),
                const SizedBox(height: 12),
                PricePanel(session: session),
              ],
              const Divider(height: 32),
              Text(
                '${checkedProducts.length} of ${widget.draft.card.products.length} products checked',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: confirmed,
                onChanged: busy
                    ? null
                    : (v) => setState(() => confirmed = v ?? false),
                title: const Text(
                  'I have checked these selling rates and tax settings for my business.',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed:
                    busy ||
                        !confirmed ||
                        checkedProducts.length !=
                            widget.draft.card.products.length
                    ? null
                    : _publish,
                child: Text(busy ? 'Publishing…' : 'Publish rates'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
