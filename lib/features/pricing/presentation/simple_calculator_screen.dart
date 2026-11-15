import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inventory/domain/product.dart' show parseMoney, parseUnits;
import '../../inventory/presentation/inventory_controller.dart';
import '../application/calculator_inventory_link.dart';
import '../application/calculator_session.dart';
import '../application/product_setup.dart';
import '../application/simple_calculator.dart';
import '../application/workspace.dart';
import '../domain/exact.dart';
import '../domain/pricing_models.dart';
import '../domain/universal/rate_card.dart';
import 'pricing_widgets.dart';

class SimpleCalculatorScreen extends ConsumerStatefulWidget {
  const SimpleCalculatorScreen({
    super.key,
    required this.workspace,
    this.profileId,
  });
  final QuickPriceWorkspace workspace;
  final String? profileId;
  @override
  ConsumerState<SimpleCalculatorScreen> createState() =>
      _SimpleCalculatorScreenState();
}

class _SimpleRow {
  _SimpleRow(this.setup, {this.original});
  final ProductSetup setup;
  final UniversalProduct? original;
  String get name => setup.data['name'] as String;
  List<Map<String, dynamic>> get varieties => (setup.data.putIfAbsent(
    'simpleVarieties',
    () => <Map<String, dynamic>>[],
  ) as List).cast<Map<String, dynamic>>();
  String get rate =>
      (varieties.isEmpty
              ? setup.rows('rates').first['amount']
              : varieties.first['amount'])
          as String;
  String get unit =>
      original?.rule.rateLookup.rates
          .where((r) => r.key == 'base')
          .firstOrNull
          ?.unit ??
      setup.data['rateUnit'] as String;
}

class _SimpleCalculatorScreenState
    extends ConsumerState<SimpleCalculatorScreen> {
  late final writer = DraftWriter(widget.workspace.values);
  late String profileId = widget.profileId ?? newPricingId();
  String template = 'doors', name = 'Doors', currency = 'INR';
  String? error;
  bool loading = true, saving = false, taxEnabled = false, loadFailed = false;
  String taxPercent = '', taxBehavior = 'exclusive';
  bool _dirty = false, _allowExit = false, _askingToLeave = false;
  UniversalStoredDraft? existing;
  List<_SimpleRow> rows = [];
  String get storageKey => 'simple_setup_${widget.profileId ?? 'new'}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.profileId != null) {
        final draft = await widget.workspace.repository.readDraft(profileId);
        existing = draft;
        name = draft.card.name;
        template = quickTemplates.containsKey(draft.card.industryTemplate)
            ? draft.card.industryTemplate
            : 'doors';
        currency = draft.card.currency.code;
        for (final product in draft.card.products) {
          final base = product.rule.rateLookup.rates
              .where((r) => r.key == 'base' && r.selectors.isEmpty)
              .toList();
          if (base.length != 1) {
            throw StateError(
              'This calculator uses advanced rates. Open Advanced settings to edit it.',
            );
          }
          final setup = quickProduct(template, name: product.name);
          final decimal = decimalText(base.single.amount, places: 12);
          setup
              .rows('rates')
              .first['amount'] = Exact.parse(decimal) == base.single.amount
              ? decimal
              : '${base.single.amount}';
          setup.data['simpleVarieties'] = simpleVarieties(product);
          // Older simple calculators had no explicit stock setting. Editing
          // and saving one now offers inventory linking by default; an
          // existing saved opt-out remains respected below.
          setup.data['inventoryTracking'] = true;
          setup.data['inventorySku'] = product.inventorySku ?? '';
          final savedSetup = await widget.workspace.values.read(
            'setup_${widget.profileId}_${product.id}',
          );
          if (savedSetup != null) {
            for (final key in [
              'inventoryTracking',
              'inventorySku',
              'inventoryOpeningStock',
              'inventoryReorderLevel',
              'inventoryCost',
              'inventoryPrice',
            ]) {
              if (savedSetup.containsKey(key)) {
                setup.data[key] = savedSetup[key];
              }
            }
            final variantCosts = Map<String, String>.from(
              savedSetup['inventoryVariantCosts'] as Map? ?? const {},
            );
            for (final variety
                in (setup.data['simpleVarieties'] as List).cast<Map>()) {
              variety['purchaseCost'] = variantCosts[variety['id']] ?? '';
            }
          }
          rows.add(_SimpleRow(setup, original: product));
        }
      } else {
        final pending = await widget.workspace.values.read(storageKey);
        if (pending != null &&
            pending['rows'] is List &&
            pending['profileId'] is String) {
          profileId = pending['profileId'] as String;
          template = pending['template'] as String;
          name = pending['name'] as String;
          currency = pending['currency'] as String;
          taxEnabled = pending['taxEnabled'] == true;
          taxPercent = pending['taxPercent'] as String? ?? '';
          taxBehavior = pending['taxBehavior'] as String? ?? 'exclusive';
          rows = [
            for (final row in (pending['rows'] as List).take(100))
              _SimpleRow(
                ProductSetup.fromJson(Map<String, dynamic>.from(row as Map)),
              ),
          ];
          // Recover an interrupted save without creating a duplicate profile.
          if ((await widget.workspace.profiles()).any(
            (p) => p.id == profileId,
          )) {
            existing = await widget.workspace.repository.readDraft(profileId);
          }
        }
      }
      if (rows.isEmpty) rows = [_SimpleRow(quickProduct(template))];
      if (widget.workspace.preview) {
        for (final row in rows) {
          row.setup.data['inventoryTracking'] = false;
        }
      }
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = pricingError(e);
          loading = false;
          loadFailed = true;
        });
      }
    }
  }

  void _changed() {
    setState(() {
      error = null;
      _dirty = true;
    });
    if (widget.profileId != null) return;
    unawaited(
      writer
          .write(storageKey, {
            'profileId': profileId,
            'template': template,
            'name': name,
            'currency': currency,
            'taxEnabled': taxEnabled,
            'taxPercent': taxPercent,
            'taxBehavior': taxBehavior,
            'rows': rows.map((r) => r.setup.data).toList(),
          })
          .catchError((Object e) {
            if (mounted) {
              setState(
                () => error = 'Changes could not be saved. ${pricingError(e)}',
              );
            }
          }),
    );
  }

  Future<UniversalProduct> _ensureInventoryProducts({
    required String uid,
    required _SimpleRow row,
    required UniversalProduct product,
  }) => linkCalculatorProductVariants(
    linker: CalculatorInventoryLinker(ref.read(inventoryRepositoryProvider)),
    uid: uid,
    product: product,
    category: 'QuickPrice',
    costMinor: parseMoney(row.setup.data['inventoryCost'] as String? ?? '0.00'),
    costMinorByRateId: {
      for (final variety in row.varieties)
        if ((variety['purchaseCost'] as String? ?? '').trim().isNotEmpty)
          variety['id'] as String: parseMoney(
            variety['purchaseCost'] as String,
          ),
    },
    fallbackPriceMinor: parseMoney(
      row.setup.data['inventoryPrice'] as String? ?? '0.00',
    ),
    openingStock: parseUnits(
      row.setup.data['inventoryOpeningStock'] as String? ?? '100',
    ),
    reorderLevel: parseUnits(
      row.setup.data['inventoryReorderLevel'] as String? ?? '10',
    ),
    isWorkspaceCurrent: () => ref.read(inventoryUidProvider) == uid,
  );

  Future<void> _save() async {
    if (saving || loading || loadFailed || rows.isEmpty) return;
    FocusScope.of(context).unfocus();
    final inventoryUid = widget.workspace.preview
        ? null
        : ref.read(inventoryUidProvider);
    setState(() {
      saving = true;
      error = null;
    });
    try {
      validateName(name.trim());
      final money = existing?.card.currency ?? Currency(currency, 2);
      final products = <UniversalProduct>[];
      final categories = [...?existing?.card.categories];
      for (final row in rows) {
        final amount = Exact.parse(row.rate.trim());
        if (amount <= Exact.zero) {
          throw ArgumentError(
            'Enter a selling rate greater than zero for ${row.name}.',
          );
        }
        if (row.original == null) {
          row.setup.data['taxBehavior'] = taxEnabled ? taxBehavior : 'exempt';
          row.setup.data['taxPercent'] = taxPercent;
        }
        configureSimpleVarieties(row.setup, row.varieties);
        row.setup.data['inventoryVariantCosts'] = {
          for (final variety in row.varieties)
            if ((variety['purchaseCost'] as String? ?? '').trim().isNotEmpty)
              variety['id'] as String: variety['purchaseCost'] as String,
        };
        final product = row.original == null
            ? row.setup.compile(widget.workspace.businessId, money)
            : replaceSimpleVarieties(
                row.original!,
                row.name,
                row.rate,
                row.varieties,
              );
        products.add(product);
        if (!categories.any((c) => c.id == product.categoryId)) {
          categories.add(
            PricingCategory(
              id: product.categoryId,
              name: product.name,
              sortOrder: categories.length,
            ),
          );
        }
      }
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        final tracking = row.setup.data['inventoryTracking'] == true;
        if (!tracking) {
          row.setup.data['inventorySku'] = '';
          products[index] = products[index].withInventorySku(null);
          continue;
        }
        if (inventoryUid == null) {
          throw StateError(
            'Choose your account or device workspace, or turn off inventory tracking for this calculator.',
          );
        }
        products[index] = await _ensureInventoryProducts(
          uid: inventoryUid,
          row: row,
          product: products[index],
        );
        row.setup.data['inventorySku'] = products[index].inventorySku ?? '';
      }
      final card = UniversalRateCardDraft(
        name: name.trim(),
        currency: money,
        industryTemplate: existing?.card.industryTemplate ?? template,
        description: existing?.card.description ?? '',
        categories: categories,
        products: products,
      );
      await writer.flush();
      if (inventoryUid != null &&
          ref.read(inventoryUidProvider) != inventoryUid) {
        throw StateError('Your workspace changed. Reopen calculator setup.');
      }
      final stored = existing == null
          ? await widget.workspace.repository.createProfile(profileId, card)
          : await widget.workspace.repository.saveDraft(
              profileId,
              card,
              expectedRevision: existing!.revision,
            );
      existing = stored;
      if (inventoryUid != null) {
        ref
            .read(inventoryProvider.notifier)
            .didWriteMany(
              inventoryUid,
              products.expand((product) => product.inventorySkuByRateId.values),
            );
      }
      for (final product in products) {
        await widget.workspace.values.approve(product.rule.tax);
      }
      for (final row in rows.where((r) => r.original == null)) {
        await widget.workspace.values.write(
          'setup_${profileId}_${row.setup.id}',
          row.setup.data,
        );
      }
      for (final row in rows.where((r) => r.original != null)) {
        final key = 'setup_${profileId}_${row.original!.id}';
        final metadata = await widget.workspace.values.read(key);
        if (metadata == null) continue;
        final setup = ProductSetup.fromJson(metadata);
        setup.data['name'] = row.name.trim();
        for (final rate in setup.rows('rates')) {
          if (rate['key'] == 'base' && (rate['selectors'] as Map).isEmpty) {
            rate['amount'] = row.rate.trim();
          }
        }
        setup.data['simpleVarieties'] = row.varieties;
        setup.data['inventoryTracking'] =
            row.setup.data['inventoryTracking'] == true;
        setup.data['inventorySku'] = row.setup.data['inventorySku'] ?? '';
        setup.data['inventoryOpeningStock'] =
            row.setup.data['inventoryOpeningStock'] ?? '100';
        setup.data['inventoryReorderLevel'] =
            row.setup.data['inventoryReorderLevel'] ?? '10';
        setup.data['inventoryCost'] = row.setup.data['inventoryCost'] ?? '0.00';
        setup.data['inventoryPrice'] =
            row.setup.data['inventoryPrice'] ?? '0.00';
        setup.data['inventoryVariantCosts'] = {
          for (final variety in row.varieties)
            if ((variety['purchaseCost'] as String? ?? '').trim().isNotEmpty)
              variety['id'] as String: variety['purchaseCost'] as String,
        };
        configureSimpleVarieties(setup, row.varieties);
        await widget.workspace.values.write(key, setup.data);
      }
      await widget.workspace.repository.publish(
        profileId,
        expectedRevision: stored.revision,
        effectiveAt: DateTime.now().toUtc(),
      );
      // Clear an unfinished new form only after publication is durable.
      await widget.workspace.values.write(storageKey, null);
      if (mounted) {
        setState(() {
          _dirty = false;
          _allowExit = true;
        });
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context, profileId);
      }
    } catch (e) {
      if (existing != null) {
        try {
          existing = await widget.workspace.repository.readDraft(profileId);
        } catch (_) {
          /* Keep the error and allow retry. */
        }
      }
      if (mounted) {
        setState(() {
          saving = false;
          error = pricingError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && (widget.profileId == null || !_dirty || _allowExit),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !saving) unawaited(_confirmLeave());
    },
    child: Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? BackButton(
                onPressed: () {
                  if (saving) return;
                  if (widget.profileId != null && _dirty && !_allowExit) {
                    unawaited(_confirmLeave());
                  } else {
                    Navigator.maybePop(context);
                  }
                },
              )
            : null,
        title: Text(
          widget.profileId == null ? 'Set up calculator' : 'Edit selling rates',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : AbsorbPointer(
                    absorbing: saving || loadFailed,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        if (error != null) MessageLine(error!, error: true),
                        if (widget.profileId == null)
                          SelectField(
                            label: 'What do you sell?',
                            value: template,
                            options: quickTemplates,
                            onChanged: saving
                                ? (_) {}
                                : (value) {
                                    if (value == template) return;
                                    template = value;
                                    name = quickTemplates[value]!;
                                    rows = [_SimpleRow(quickProduct(template))];
                                    _changed();
                                  },
                          ),
                        const SizedBox(height: 16),
                        ValueField(
                          label: 'Calculator name',
                          value: name,
                          onChanged: (v) {
                            name = v;
                            _changed();
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Products and selling rates',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter your rates once, then use this calculator anytime.',
                        ),
                        for (final row in rows) ...[
                          const SizedBox(height: 20),
                          ValueField(
                            key: ValueKey('simple-name-${row.setup.id}'),
                            label: 'Product name',
                            value: row.name,
                            onChanged: (v) {
                              row.setup.data['name'] = v;
                              _changed();
                            },
                          ),
                          const SizedBox(height: 12),
                          if (row.varieties.isEmpty)
                            ValueField(
                              key: ValueKey('simple-rate-${row.setup.id}'),
                              label:
                                  'Selling rate ($currency / ${unitShort[row.unit] ?? row.unit})',
                              numeric: true,
                              value: row.rate,
                              onChanged: (v) {
                                row.setup.rows('rates').first['amount'] = v;
                                _changed();
                              },
                            ),
                          ..._varietyFields(row),
                          if (!widget.workspace.preview)
                            ..._inventorySetup(row),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              key: ValueKey('add-variety-${row.setup.id}'),
                              onPressed: row.varieties.length >= 100
                                  ? null
                                  : () {
                                      if (row.varieties.isEmpty) {
                                        row.varieties.add({
                                          'id': newPricingId(),
                                          'name': 'Standard',
                                          'amount': row.rate,
                                        });
                                      }
                                      row.varieties.add({
                                        'id': newPricingId(),
                                        'name': '',
                                        'amount': '',
                                      });
                                      _changed();
                                    },
                              icon: const Icon(Icons.add),
                              label: const Text('Add variety'),
                            ),
                          ),
                          if (row.setup.kind == 'packaging' &&
                              row.original == null) ...[
                            const SizedBox(height: 12),
                            ValueField(
                              label: 'Area covered by one box (ft²)',
                              numeric: true,
                              value: row.setup.data['coverage'] as String,
                              onChanged: (v) {
                                row.setup.data['coverage'] = v;
                                _changed();
                              },
                            ),
                          ],
                          if (row.original == null && rows.length > 1)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: saving
                                    ? null
                                    : () {
                                        rows.remove(row);
                                        _changed();
                                      },
                                child: const Text('Remove product'),
                              ),
                            ),
                          const Divider(height: 28),
                        ],
                        OutlinedButton.icon(
                          onPressed: saving || rows.length >= 100
                              ? null
                              : () {
                                  rows.add(
                                    _SimpleRow(
                                      quickProduct(template, name: ''),
                                    ),
                                  );
                                  _changed();
                                },
                          icon: const Icon(Icons.add),
                          label: const Text('Add another product'),
                        ),
                        const SizedBox(height: 16),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Optional settings'),
                          children: [
                            if (widget.profileId == null) ...[
                              SelectField(
                                label: 'Currency',
                                value: currency,
                                options: const {
                                  'INR': 'INR',
                                  'USD': 'USD',
                                  'EUR': 'EUR',
                                  'GBP': 'GBP',
                                },
                                onChanged: (v) {
                                  currency = v;
                                  _changed();
                                },
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Charge tax'),
                                value: taxEnabled,
                                onChanged: saving
                                    ? null
                                    : (v) {
                                        taxEnabled = v;
                                        _changed();
                                      },
                              ),
                              if (taxEnabled) ...[
                                ValueField(
                                  label: 'Tax percentage',
                                  numeric: true,
                                  value: taxPercent,
                                  onChanged: (v) {
                                    taxPercent = v;
                                    _changed();
                                  },
                                ),
                                SelectField(
                                  label: 'Tax treatment',
                                  value: taxBehavior,
                                  options: const {
                                    'exclusive': 'Add tax',
                                    'inclusive': 'Tax included',
                                  },
                                  onChanged: (v) {
                                    taxBehavior = v;
                                    _changed();
                                  },
                                ),
                              ],
                              const Text(
                                'No tax is charged unless enabled. Final prices round to the nearest paisa / cent, with half-paisa values rounded up.',
                              ),
                            ] else
                              const Text(
                                'Existing tax, accessories, discounts and billing rules are kept. Use Advanced settings to change them.',
                              ),
                            const SizedBox(height: 12),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (error != null) MessageLine(error!, error: true),
                        FilledButton.icon(
                          onPressed:
                              saving ||
                                  loadFailed ||
                                  (error != null && rows.isEmpty)
                              ? null
                              : _save,
                          icon: const Icon(Icons.check),
                          label: Text(
                            saving ? 'Saving…' : 'Save and use calculator',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    ),
  );

  Future<void> _confirmLeave() async {
    if (_askingToLeave) return;
    _askingToLeave = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard rate changes?'),
        content: const Text('Your saved selling rates will stay as they are.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard changes'),
          ),
        ],
      ),
    );
    _askingToLeave = false;
    if (mounted && discard == true) {
      setState(() => _allowExit = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    }
  }

  List<Widget> _varietyFields(_SimpleRow row) => [
    if (row.varieties.isNotEmpty) ...[
      const Text('Varieties', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text(
        'Each variety has its own rate. The first is selected by default.',
      ),
      for (final variety in row.varieties) ...[
        const SizedBox(height: 16),
        ValueField(
          key: ValueKey('variety-name-${variety['id']}'),
          label: 'Variety name',
          value: variety['name'] as String,
          onChanged: (v) {
            variety['name'] = v;
            _changed();
          },
        ),
        const SizedBox(height: 12),
        ValueField(
          key: ValueKey('variety-rate-${variety['id']}'),
          label:
              'Selling rate ($currency / ${unitShort[row.unit] ?? row.unit})',
          numeric: true,
          value: variety['amount'] as String,
          onChanged: (v) {
            variety['amount'] = v;
            _changed();
          },
        ),
        const SizedBox(height: 12),
        ValueField(
          key: ValueKey('variety-cost-${variety['id']}'),
          label: 'Purchase cost per unit ($currency)',
          numeric: true,
          value: variety['purchaseCost'] as String? ?? '',
          helper: 'Leave blank to use the product purchase cost below.',
          prefixIcon: Icons.shopping_cart_outlined,
          onChanged: (value) {
            variety['purchaseCost'] = value;
            _changed();
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              row.setup.rows('rates').first['amount'] = row.rate;
              row.varieties.remove(variety);
              _changed();
            },
            child: const Text('Remove variety'),
          ),
        ),
      ],
    ],
  ];

  List<Widget> _inventorySetup(_SimpleRow row) {
    final data = row.setup.data;
    final tracking = data['inventoryTracking'] == true;
    final inventorySku = (data['inventorySku'] as String? ?? '').trim();
    final uid = ref.watch(inventoryUidProvider);
    return [
      const SizedBox(height: 8),
      ExpansionTile(
        key: PageStorageKey<String>('inventory-${row.setup.id}'),
        tilePadding: EdgeInsets.zero,
        leading: const Icon(Icons.inventory_2_outlined),
        title: const Text('Inventory and costs'),
        subtitle: Text(
          !tracking
              ? 'Price only · does not change stock'
              : inventorySku.isNotEmpty
              ? 'Linked to inventory · $inventorySku'
              : 'New stock item · ${data['inventoryOpeningStock']} units, alert at ${data['inventoryReorderLevel']}',
        ),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Track this product in Inventory'),
            subtitle: const Text(
              'Linked bill quantities will reduce stock automatically.',
            ),
            value: tracking,
            onChanged: (value) {
              data['inventoryTracking'] = value;
              _changed();
            },
          ),
          if (tracking && uid == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: MessageLine(
                'Choose your account or device workspace before saving a stock-linked calculator.',
              ),
            ),
          if (tracking && inventorySku.isNotEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.link_outlined),
              title: Text('Existing inventory item linked'),
              subtitle: Text(
                'Its current stock and cost are preserved. Edit them in Inventory.',
              ),
            ),
          if (tracking && inventorySku.isEmpty) ...[
            ValueField(
              key: ValueKey('qp-opening-${row.setup.id}'),
              label: 'Opening stock (units)',
              numeric: true,
              value: data['inventoryOpeningStock'] as String? ?? '100',
              helper: 'Enter the actual count before saving.',
              prefixIcon: Icons.inventory_2_outlined,
              onChanged: (value) {
                data['inventoryOpeningStock'] = value;
                _changed();
              },
            ),
            const SizedBox(height: 10),
            ValueField(
              key: ValueKey('qp-reorder-${row.setup.id}'),
              label: 'Low-stock alert at (units)',
              numeric: true,
              value: data['inventoryReorderLevel'] as String? ?? '10',
              prefixIcon: Icons.notifications_active_outlined,
              onChanged: (value) {
                data['inventoryReorderLevel'] = value;
                _changed();
              },
            ),
            const SizedBox(height: 10),
            ValueField(
              key: ValueKey('qp-cost-${row.setup.id}'),
              label: 'Purchase cost per stock unit ($currency)',
              numeric: true,
              value: data['inventoryCost'] as String? ?? '0.00',
              helper: 'Used to estimate gross profit on bills.',
              prefixIcon: Icons.shopping_cart_outlined,
              onChanged: (value) {
                data['inventoryCost'] = value;
                _changed();
              },
            ),
            const SizedBox(height: 10),
            ValueField(
              key: ValueKey('qp-price-${row.setup.id}'),
              label: 'Standard selling price per stock unit ($currency)',
              numeric: true,
              value: data['inventoryPrice'] as String? ?? '0.00',
              helper: 'This inventory price is separate from measured QuickPrice rates.',
              prefixIcon: Icons.sell_outlined,
              onChanged: (value) {
                data['inventoryPrice'] = value;
                _changed();
              },
            ),
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: MessageLine(
                'A matching stock item keeps its quantity. Calculator variety rates and saved purchase cost update its prices.',
              ),
            ),
          ],
        ],
      ),
    ];
  }
}
