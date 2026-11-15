import 'dart:convert';

import '../../inventory/domain/inventory_repository.dart';
import '../../inventory/domain/product.dart';
import '../domain/universal/rates.dart';
import '../domain/universal/rate_card.dart';

final class CalculatorInventoryVariant {
  const CalculatorInventoryVariant({
    required this.rateId,
    required this.name,
    required this.isVariety,
    required this.priceMinor,
    this.parameters = const [],
  });

  final String rateId;
  final String name;
  final bool isVariety;
  final int? priceMinor;
  final List<ProductParameter> parameters;
}

/// Turns selectable base-rate rows into distinct stock items. A single
/// unvaried base rate remains one Inventory product.
List<CalculatorInventoryVariant> calculatorInventoryVariants(
  UniversalProduct product,
) {
  final baseRates = product.rule.rateLookup.rates
      .where((rate) => rate.key == 'base')
      .toList();
  final selectedRates = baseRates
      .where((rate) => rate.selectors.isNotEmpty)
      .toList();
  final rates = selectedRates.isNotEmpty
      ? selectedRates
      : baseRates.where((rate) => rate.selectors.isEmpty).take(1).toList();
  if (rates.isEmpty) {
    return [
      CalculatorInventoryVariant(
        rateId: product.id,
        name: product.name,
        isVariety: false,
        priceMinor: null,
        parameters: [
          for (final entry in product.attributes.entries)
            ProductParameter(name: entry.key, value: entry.value),
        ],
      ),
    ];
  }
  final variants = [
    for (final rate in rates)
      CalculatorInventoryVariant(
        rateId: rate.id,
        name: _variantName(product, rate),
        isVariety: rate.selectors.isNotEmpty,
        priceMinor: product.rule.currency
            .minor(rate.amount, product.rule.rounding)
            .toInt(),
        parameters: [
          for (final field in product.rule.schema.fields)
            if (rate.selectors.containsKey(field.id))
              ProductParameter(
                name: field.label,
                value: rate.selectors[field.id]!,
              ),
        ],
      ),
  ];
  final nameCounts = <String, int>{};
  return [
    for (final variant in variants)
      () {
        final key = variant.name.trim().toLowerCase();
        final duplicateIndex = (nameCounts[key] ?? 0) + 1;
        nameCounts[key] = duplicateIndex;
        if (duplicateIndex == 1) return variant;
        return CalculatorInventoryVariant(
          rateId: variant.rateId,
          name: '${variant.name} · Variant $duplicateIndex',
          isVariety: variant.isVariety,
          priceMinor: variant.priceMinor,
          parameters: variant.parameters,
        );
      }(),
  ];
}

String _variantName(UniversalProduct product, SellingRate rate) {
  if (rate.selectors.isEmpty) return product.name;
  final values = [
    for (final field in product.rule.schema.fields)
      if (rate.selectors.containsKey(field.id))
        '${field.label}: ${rate.selectors[field.id]!}',
  ];
  final suffix = values.join(' / ');
  final prefix = product.name.trim();
  final combined = '$prefix — $suffix';
  if (combined.length <= 120) return combined;
  final allowedPrefix = (120 - suffix.length - 3).clamp(1, 120).toInt();
  return '${prefix.substring(0, prefix.length.clamp(0, allowedPrefix).toInt())} — ${suffix.substring(0, suffix.length.clamp(0, 117).toInt())}';
}

/// Persists each calculator variety as its own Inventory product and stores
/// the stable rate-to-SKU mapping in the pricing draft.
Future<UniversalProduct> linkCalculatorProductVariants({
  required CalculatorInventoryLinker linker,
  required String uid,
  required UniversalProduct product,
  required String category,
  required int costMinor,
  Map<String, int> costMinorByRateId = const {},
  required int fallbackPriceMinor,
  required int openingStock,
  required int reorderLevel,
  required bool Function() isWorkspaceCurrent,
}) async {
  final variants = calculatorInventoryVariants(product);
  final skus = <String, String>{};
  final mayReuseLegacySku = product.inventorySkuByRateId.isEmpty;
  for (var index = 0; index < variants.length; index++) {
    if (!isWorkspaceCurrent()) {
      throw StateError('Your workspace changed. Reopen calculator setup.');
    }
    final variant = variants[index];
    final existingSku =
        product.inventorySkuByRateId[variant.rateId] ??
        (mayReuseLegacySku && index == 0 ? product.inventorySku : null);
    final sku = await linker.link(
      uid: uid,
      productId: product.id,
      variantId: variant.isVariety ? variant.rateId : null,
      name: variant.name,
      category: category,
      currency: product.rule.currency.code,
      costMinor: costMinorByRateId[variant.rateId] ?? costMinor,
      priceMinor: variant.priceMinor ?? fallbackPriceMinor,
      parameters: variant.parameters,
      openingStock: openingStock,
      reorderLevel: reorderLevel,
      existingSku: existingSku,
      isWorkspaceCurrent: isWorkspaceCurrent,
    );
    skus[variant.rateId] = sku;
  }
  final primarySku = skus[variants.first.rateId];
  return product.withInventoryVariants(skus, primarySku: primarySku);
}

/// Creates or refreshes the inventory side of a calculator product link.
/// Pricing and inventory are separate databases, so the deterministic SKU and
/// movement ID make retry after an interrupted cross-database save idempotent.
final class CalculatorInventoryLinker {
  const CalculatorInventoryLinker(this.repository);

  final InventoryRepository repository;

  String skuFor(String productId) {
    final id = productId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (id.isEmpty) throw ArgumentError('Calculator product ID is invalid.');
    final suffix = id.length > 34 ? id.substring(id.length - 34) : id;
    return 'QP$suffix';
  }

  String operationIdFor(String productId) => 'CALC_$productId';

  String skuForVariant(String productId, String rateId) {
    final identity = '$productId:$rateId';
    var hash = 0x811c9dc5;
    for (final unit in identity.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    final digest = hash.toRadixString(16).padLeft(8, '0').toUpperCase();
    final stem = identity.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    return 'QV${stem.substring(0, stem.length.clamp(0, 30).toInt())}$digest';
  }

  Future<String> link({
    required String uid,
    required String productId,
    required String name,
    required String category,
    required String currency,
    required int costMinor,
    required int priceMinor,
    required int openingStock,
    required int reorderLevel,
    List<ProductParameter> parameters = const [],
    String? variantId,
    String? existingSku,
    required bool Function() isWorkspaceCurrent,
  }) async {
    void checkWorkspace() {
      if (!isWorkspaceCurrent()) {
        throw StateError('Your workspace changed. Reopen calculator setup.');
      }
    }

    checkWorkspace();
    if (existingSku != null) {
      final linked = await repository.get(uid, existingSku);
      checkWorkspace();
      return _updateLinked(
        uid: uid,
        current: linked,
        name: name,
        category: category,
        currency: currency,
        costMinor: costMinor == 0 ? linked.costMinor : costMinor,
        priceMinor: priceMinor == 0 ? linked.priceMinor : priceMinor,
        reorderLevel: reorderLevel,
        parameters: parameters,
        checkWorkspace: checkWorkspace,
      );
    }

    final deterministicSku = variantId == null
        ? skuFor(productId)
        : skuForVariant(productId, variantId);
    final alreadyCreated = await _findSku(
      uid,
      deterministicSku,
      isWorkspaceCurrent: isWorkspaceCurrent,
    );
    if (alreadyCreated != null) {
      if (alreadyCreated.archived) {
        throw StateError(
          'The linked inventory item is archived. Restore it in Inventory first.',
        );
      }
      return _updateLinked(
        uid: uid,
        current: alreadyCreated,
        name: name,
        category: category,
        currency: currency,
        costMinor: costMinor == 0 ? alreadyCreated.costMinor : costMinor,
        priceMinor: priceMinor == 0 ? alreadyCreated.priceMinor : priceMinor,
        reorderLevel: reorderLevel,
        parameters: parameters,
        checkWorkspace: checkWorkspace,
      );
    }

    final activeMatches = await _findExactName(
      uid,
      name,
      archived: false,
      isWorkspaceCurrent: isWorkspaceCurrent,
    );
    if (activeMatches.length > 1) {
      throw StateError(
        'More than one inventory product has this name. Resolve the duplicates before linking it.',
      );
    }
    if (activeMatches.isNotEmpty) {
      final match = activeMatches.single;
      if (match.currency != currency) {
        throw StateError(
          'An inventory product with this name uses ${match.currency}. Review it in Inventory before linking.',
        );
      }
      return _updateLinked(
        uid: uid,
        current: match,
        name: name,
        category: category,
        currency: currency,
        costMinor: costMinor == 0 ? match.costMinor : costMinor,
        priceMinor: priceMinor == 0 ? match.priceMinor : priceMinor,
        reorderLevel: reorderLevel,
        parameters: parameters,
        checkWorkspace: checkWorkspace,
      );
    }
    final archivedMatches = await _findExactName(
      uid,
      name,
      archived: true,
      isWorkspaceCurrent: isWorkspaceCurrent,
    );
    if (archivedMatches.isNotEmpty) {
      throw StateError(
        'An archived inventory product already has this name. Restore it before linking.',
      );
    }

    checkWorkspace();
    final draft = ProductDraft(
      sku: deterministicSku,
      name: name.trim(),
      category: category.trim().isEmpty ? 'QuickPrice' : category.trim(),
      currency: currency,
      costMinor: costMinor,
      priceMinor: priceMinor,
      openingStock: openingStock,
      reorderLevel: reorderLevel,
      parameters: parameters,
    );
    try {
      await repository.create(
        uid,
        draft,
        variantId == null
            ? operationIdFor(productId)
            : operationIdFor(deterministicSku),
      );
    } catch (_) {
      // If another save completed the same deterministic operation, continue
      // by reading and validating that row instead of making a second one.
      checkWorkspace();
      final raced = await _findSku(
        uid,
        deterministicSku,
        isWorkspaceCurrent: isWorkspaceCurrent,
      );
      if (raced == null || raced.archived || raced.currency != currency) {
        rethrow;
      }
      return _updateLinked(
        uid: uid,
        current: raced,
        name: name,
        category: category,
        currency: currency,
        costMinor: costMinor == 0 ? raced.costMinor : costMinor,
        priceMinor: priceMinor == 0 ? raced.priceMinor : priceMinor,
        reorderLevel: reorderLevel,
        parameters: parameters,
        checkWorkspace: checkWorkspace,
      );
    }
    checkWorkspace();
    return deterministicSku;
  }

  Future<String> _updateLinked({
    required String uid,
    required Product current,
    required String name,
    required String category,
    required String currency,
    required int costMinor,
    required int priceMinor,
    required int reorderLevel,
    required List<ProductParameter> parameters,
    required void Function() checkWorkspace,
  }) async {
    if (current.archived) {
      throw StateError(
        'Restore the linked inventory product before editing it.',
      );
    }
    if (current.currency != currency) {
      throw StateError(
        'The calculator currency does not match its linked inventory product.',
      );
    }
    final normalizedCategory = category.trim().isEmpty
        ? current.category
        : category.trim();
    final draft = ProductDraft(
      sku: current.sku,
      name: name.trim(),
      category: normalizedCategory,
      currency: currency,
      costMinor: costMinor,
      priceMinor: priceMinor,
      openingStock: current.quantity,
      reorderLevel: reorderLevel,
      parameters: parameters,
      pricingFormula: current.pricingFormula,
    );
    if (current.name != draft.name ||
        current.category != draft.category ||
        current.costMinor != draft.costMinor ||
        current.priceMinor != draft.priceMinor ||
        current.reorderLevel != draft.reorderLevel ||
        jsonEncode(current.parameters.map((p) => p.toMap()).toList()) !=
            jsonEncode(draft.parameters.map((p) => p.toMap()).toList())) {
      checkWorkspace();
      await repository.update(uid, draft, current.revision);
      checkWorkspace();
    }
    return current.sku;
  }

  Future<Product?> _findSku(
    String uid,
    String sku, {
    required bool Function() isWorkspaceCurrent,
  }) async {
    for (final archived in [false, true]) {
      final page = await repository.list(
        uid,
        InventoryQuery(
          archived: archived,
          search: sku,
          searchBy: ProductSearch.code,
        ),
      );
      if (!isWorkspaceCurrent()) {
        throw StateError('Your workspace changed. Reopen calculator setup.');
      }
      final match = page.products.where((product) => product.sku == sku);
      if (match.isNotEmpty) return match.first;
    }
    return null;
  }

  Future<List<Product>> _findExactName(
    String uid,
    String name, {
    required bool archived,
    required bool Function() isWorkspaceCurrent,
  }) async {
    String comparable(String value) =>
        value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    final matches = <Product>[];
    InventoryCursor? cursor;
    do {
      final prefix = name.trim().split(RegExp(r'\s+')).firstOrNull ?? '';
      final page = await repository.list(
        uid,
        InventoryQuery(archived: archived, search: prefix),
        after: cursor,
      );
      if (!isWorkspaceCurrent()) {
        throw StateError('Your workspace changed. Reopen calculator setup.');
      }
      for (final candidate in page.products) {
        if (comparable(candidate.name) == comparable(name)) {
          matches.add(candidate);
        }
      }
      cursor = page.next;
    } while (cursor != null);
    return matches;
  }
}
