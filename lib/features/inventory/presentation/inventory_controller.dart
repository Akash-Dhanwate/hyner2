import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/local_inventory_repository.dart';
import '../../pricing/application/calculator_inventory_link.dart';
import '../../pricing/application/pricing_workspace_provider.dart';
import '../../pricing/domain/universal/rate_card.dart';
import '../domain/inventory_repository.dart';
import '../domain/product.dart';

final inventoryUidProvider = Provider<String?>((ref) {
  final session = ref.watch(sessionProvider);
  return session.isAuthenticated ? session.profile!.uid : null;
});
final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => ref.watch(dependenciesProvider).inventory,
);

final inventoryProvider = NotifierProvider<InventoryController, InventoryState>(
  InventoryController.new,
);

class InventoryState {
  const InventoryState({
    this.products = const [],
    this.query = const InventoryQuery(),
    this.next,
    this.loading = false,
    this.loadingMore = false,
    this.failure,
    this.pricingSyncWarning,
  });
  final List<Product> products;
  final InventoryQuery query;
  final InventoryCursor? next;
  final bool loading;
  final bool loadingMore;
  final AppFailure? failure;
  final String? pricingSyncWarning;
}

class InventoryController extends Notifier<InventoryState> {
  String? _uid;
  int _generation = 0;
  final _syncedPricingUids = <String>{};
  final _pricingSyncs = <String, Future<void>>{};

  @override
  InventoryState build() {
    _uid = ref.watch(inventoryUidProvider);
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    if (_uid != null) {
      scheduleMicrotask(() {
        if (ref.mounted && generation == _generation) unawaited(refresh());
      });
    }
    return InventoryState(loading: _uid != null);
  }

  bool _current(String uid, int generation) =>
      ref.mounted && _uid == uid && generation == _generation;

  void didWrite(
    String uid,
    String sku, {
    bool refreshProduct = true,
    bool clearSearch = false,
  }) => didWriteMany(
    uid,
    [sku],
    refreshProduct: refreshProduct,
    clearSearch: clearSearch,
  );

  void didWriteMany(
    String uid,
    Iterable<String> skus, {
    bool refreshProduct = true,
    bool clearSearch = false,
  }) {
    if (!ref.mounted || _uid != uid) return;
    final uniqueSkus = skus.toSet();
    if (refreshProduct) {
      for (final sku in uniqueSkus) {
        ref.invalidate(inventoryProductProvider(sku));
      }
    }
    final query = clearSearch
        ? InventoryQuery(
            archived: state.query.archived,
            searchBy: state.query.searchBy,
          )
        : state.query;
    unawaited(refresh(query: query));
    for (final sku in uniqueSkus) {
      checkStock(uid, sku);
    }
  }

  void checkStock(String uid, String sku) {
    if (!ref.mounted || _uid != uid) return;
    unawaited(_syncStockAlert(uid, sku));
  }

  Future<void> checkAllLowStock() async {
    final uid = _uid;
    if (uid == null || !ref.mounted) return;
    final repository = ref.read(inventoryRepositoryProvider);
    InventoryCursor? cursor;
    do {
      final page = await repository.list(
        uid,
        const InventoryQuery(),
        after: cursor,
      );
      if (!ref.mounted || _uid != uid) return;
      for (final product in page.products) {
        if (product.isLowStock) {
          await LocalNotificationService.instance.lowStock(
            sku: product.sku,
            productName: product.name,
            quantity: product.quantity,
            reorderLevel: product.reorderLevel,
          );
        }
      }
      cursor = page.next;
    } while (cursor != null);
  }

  Future<void> _syncStockAlert(String uid, String sku) async {
    try {
      final product = await ref.read(inventoryRepositoryProvider).get(uid, sku);
      if (!ref.mounted || _uid != uid) return;
      if (product.isLowStock) {
        await LocalNotificationService.instance.lowStock(
          sku: product.sku,
          productName: product.name,
          quantity: product.quantity,
          reorderLevel: product.reorderLevel,
        );
      } else {
        await LocalNotificationService.instance.clearLowStock(sku);
      }
    } catch (_) {
      // A notification check must never interrupt a stock save or sign-out.
    }
  }

  Future<void> refresh({InventoryQuery? query}) async {
    final uid = _uid;
    if (uid == null) return;
    final generation = ++_generation;
    final filter = query ?? state.query;
    state = InventoryState(query: filter, loading: true);
    String? pricingSyncWarning;
    try {
      try {
        await _syncCalculatorProducts(uid);
      } catch (_) {
        pricingSyncWarning = 'Some calculator products could not be added to Inventory. Open QuickPrice and refresh Inventory to retry.';
      }
      if (!_current(uid, generation)) return;
      final page = await ref
          .read(inventoryRepositoryProvider)
          .list(uid, filter);
      if (!_current(uid, generation)) return;
      state = InventoryState(
        products: page.products,
        query: filter,
        next: page.next,
        pricingSyncWarning: pricingSyncWarning,
      );
    } catch (error) {
      if (_current(uid, generation)) {
        state = InventoryState(
          query: filter,
          failure: AppFailure.from(error),
          pricingSyncWarning: pricingSyncWarning,
        );
      }
    }
  }

  Future<void> _syncCalculatorProducts(String uid) async {
    // Calculator pricing is a local SQLite companion to the local inventory
    // register. Non-local repository implementations do not share this
    // workspace and must not be mutated by this bridge.
    if (ref.read(inventoryRepositoryProvider) is! LocalInventoryRepository) {
      return;
    }
    if (_syncedPricingUids.contains(uid)) return;
    final existing = _pricingSyncs[uid];
    if (existing != null) return existing;
    final work = _performCalculatorSync(uid);
    _pricingSyncs[uid] = work;
    try {
      await work;
      _syncedPricingUids.add(uid);
    } finally {
      _pricingSyncs.remove(uid);
    }
  }

  Future<void> _performCalculatorSync(String uid) async {
    bool current() => ref.mounted && _uid == uid;
    final profile = ref.read(sessionProvider).profile;
    final pricingUid = profile?.localOnly == true ? null : uid;
    final workspace = await ref.read(
      pricingWorkspaceProvider(pricingUid).future,
    );
    if (!current()) {
      throw StateError('Workspace changed during inventory sync.');
    }
    if (workspace.preview) return;
    final linker = CalculatorInventoryLinker(
      ref.read(inventoryRepositoryProvider),
    );
    final profiles = await workspace.profiles();
    for (final profile in profiles.where(
      (profile) => profile.status != 'archived',
    )) {
      if (!current()) {
        throw StateError('Workspace changed during inventory sync.');
      }
      final stored = await workspace.repository.readDraft(profile.id);
      final products = [...stored.card.products];
      var changed = false;
      for (var index = 0; index < products.length; index++) {
        final product = products[index];
        final variants = calculatorInventoryVariants(product);
        if (variants.every(
          (variant) => product.inventorySkuByRateId.containsKey(variant.rateId),
        )) {
          continue;
        }
        if (!current()) {
          throw StateError('Workspace changed during inventory sync.');
        }
        final setup = await workspace.values.read(
          'setup_${profile.id}_${product.id}',
        );
        int moneyValue(String key) {
          try {
            return parseMoney(setup?[key] as String? ?? '0.00');
          } catch (_) {
            return 0;
          }
        }

        int unitsValue(String key, int fallback) {
          try {
            return parseUnits(setup?[key] as String? ?? '$fallback');
          } catch (_) {
            return fallback;
          }
        }

        final rawVariantCosts = setup?['inventoryVariantCosts'];
        final variantCosts = <String, int>{};
        if (rawVariantCosts is Map) {
          for (final entry in rawVariantCosts.entries) {
            if (entry.key is String && entry.value is String) {
              try {
                variantCosts[entry.key as String] = parseMoney(
                  entry.value as String,
                );
              } catch (_) {
                // Ignore one malformed optional cost; retain the product cost.
              }
            }
          }
        }

        final previouslyTracked = setup?['inventoryTracking'] == true;
        var inventoryCost = previouslyTracked ? moneyValue('inventoryCost') : 0;
        if (!previouslyTracked && product.inventorySku != null) {
          inventoryCost =
              (await ref
                      .read(inventoryRepositoryProvider)
                      .get(uid, product.inventorySku!))
                  .costMinor;
          if (!current()) {
            throw StateError('Workspace changed during inventory sync.');
          }
        }
        final category = stored.card.categories
            .where((category) => category.id == product.categoryId)
            .map((category) => category.name)
            .firstOrNull;
        final linked = await linkCalculatorProductVariants(
          linker: linker,
          uid: uid,
          product: product,
          category: category ?? stored.card.name,
          costMinor: inventoryCost,
          costMinorByRateId: variantCosts,
          fallbackPriceMinor: previouslyTracked
              ? moneyValue('inventoryPrice')
              : 0,
          openingStock: 100,
          reorderLevel: previouslyTracked
              ? unitsValue('inventoryReorderLevel', 10)
              : 10,
          isWorkspaceCurrent: current,
        );
        if (linked.inventorySkuByRateId.length !=
                product.inventorySkuByRateId.length ||
            linked.inventorySkuByRateId.entries.any(
              (entry) => product.inventorySkuByRateId[entry.key] != entry.value,
            ) ||
            linked.inventorySku != product.inventorySku) {
          products[index] = linked;
          changed = true;
        }
      }
      if (changed) {
        if (!current()) {
          throw StateError('Workspace changed during inventory sync.');
        }
        await workspace.repository.saveDraft(
          profile.id,
          UniversalRateCardDraft(
            name: stored.card.name,
            currency: stored.card.currency,
            description: stored.card.description,
            industryTemplate: stored.card.industryTemplate,
            categories: stored.card.categories,
            products: products,
          ),
          expectedRevision: stored.revision,
        );
      }
    }
  }

  Future<void> loadMore() async {
    final uid = _uid;
    final cursor = state.next;
    if (uid == null || cursor == null || state.loading || state.loadingMore) {
      return;
    }
    final generation = _generation;
    final previous = state;
    state = InventoryState(
      products: previous.products,
      query: previous.query,
      next: cursor,
      loadingMore: true,
    );
    try {
      final page = await ref
          .read(inventoryRepositoryProvider)
          .list(uid, previous.query, after: cursor);
      if (!_current(uid, generation)) return;
      final combined = {
        for (final product in previous.products) product.sku: product,
        for (final product in page.products) product.sku: product,
      };
      state = InventoryState(
        products: combined.values.toList(),
        query: previous.query,
        next: page.next,
        pricingSyncWarning: previous.pricingSyncWarning,
      );
    } catch (error) {
      if (_current(uid, generation)) {
        state = InventoryState(
          products: previous.products,
          query: previous.query,
          next: cursor,
          failure: AppFailure.from(error),
          pricingSyncWarning: previous.pricingSyncWarning,
        );
      }
    }
  }
}

final inventoryProductProvider = FutureProvider.autoDispose
    .family<Product, String>((ref, sku) {
      final uid = ref.watch(inventoryUidProvider);
      if (uid == null) {
        throw const AppFailure(
          FailureKind.permission,
          'Sign in before opening inventory.',
        );
      }
      return ref.watch(inventoryRepositoryProvider).get(uid, sku);
    });
