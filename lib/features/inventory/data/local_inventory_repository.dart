import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/storage/local_business_database.dart';
import '../domain/inventory_repository.dart';
import '../domain/product.dart';
import '../domain/pricing_formula.dart';
import 'inventory_codec.dart';

const _pageSize = 30;

class LocalInventoryRepository implements InventoryRepository {
  LocalInventoryRepository(
    this._store, {
    this.legacySource,
    this.legacyImportTimeout = const Duration(seconds: 2),
  });
  final LocalBusinessDatabase _store;
  final InventoryRepository? legacySource;
  final Duration legacyImportTimeout;
  final Map<String, Future<void>> _imports = {};
  final Map<String, DateTime> _lastImportAttempts = {};
  final _failedImportUids = <String>{};
  bool get legacyImportFailed => _failedImportUids.isNotEmpty;
  bool legacyImportFailedFor(String uid) => _failedImportUids.contains(uid);

  /// Manual refresh may retry immediately; ordinary reads keep their cooldown.
  void allowLegacyImportRetry(String uid) => _lastImportAttempts.remove(uid);

  @override
  String newOperationId() => _localId();

  @override
  Future<InventoryPage> list(
    String uid,
    InventoryQuery filter, {
    InventoryCursor? after,
  }) async {
    _checkOwner(uid);
    await _tryImportLegacyInventory(uid);
    final db = await _store.databaseFor(uid);
    final prefix = filter.searchBy == ProductSearch.name
        ? filter.search.trim()
        : normalizeSku(filter.search);
    final sortColumn = filter.searchBy == ProductSearch.name ? 'name' : 'sku';
    final conditions = <String>['archived = ?'];
    final args = <Object?>[filter.archived ? 1 : 0];
    final unicodeNameSearch =
        filter.searchBy == ProductSearch.name &&
        RegExp(r'[^\x00-\x7f]').hasMatch(prefix);
    if (prefix.isNotEmpty && !unicodeNameSearch) {
      conditions.add("$sortColumn LIKE ? ESCAPE '\\' COLLATE NOCASE");
      final literalPrefix = prefix
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      args.add('$literalPrefix%');
    }
    if (after != null) {
      conditions.add(
        '($sortColumn COLLATE NOCASE > ? OR ($sortColumn COLLATE NOCASE = ? AND sku > ?))',
      );
      args.addAll([after.sortValue, after.sortValue, after.sku]);
    }
    final rows = await db.query(
      'products',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: '$sortColumn COLLATE NOCASE ASC, sku ASC',
      limit: unicodeNameSearch ? null : _pageSize + 1,
    );
    final matching = unicodeNameSearch
        ? rows
              .where(
                (row) => (row['name']! as String).toLowerCase().startsWith(
                  prefix.toLowerCase(),
                ),
              )
              .take(_pageSize + 1)
              .toList()
        : rows;
    final hasNext = matching.length > _pageSize;
    final page = matching.take(_pageSize).map(_productFromRow).toList();
    final last = page.lastOrNull;
    return InventoryPage(
      page,
      hasNext && last != null
          ? InventoryCursor(
              filter.searchBy == ProductSearch.name ? last.name : last.sku,
              last.sku,
            )
          : null,
    );
  }

  @override
  Future<Product> get(String uid, String sku) async {
    _checkOwner(uid);
    await _tryImportLegacyInventory(uid);
    final db = await _store.databaseFor(uid);
    final rows = await db.query(
      'products',
      where: 'sku = ?',
      whereArgs: [sku],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw inventoryInvalid(
        'This product no longer exists. Refresh inventory.',
      );
    }
    return _productFromRow(rows.single);
  }

  @override
  Future<void> create(
    String uid,
    ProductDraft draft,
    String operationId,
  ) async {
    _checkOwner(uid);
    await _tryImportLegacyInventory(uid);
    draft.validate();
    if (!InventoryCodec.validOperationId(operationId)) {
      throw inventoryInvalid('Invalid stock operation.');
    }
    final db = await _store.databaseFor(uid);
    final now = DateTime.now().toUtc();
    await db.transaction((tx) async {
      final existing = await tx.query(
        'products',
        where: 'sku = ?',
        whereArgs: [draft.sku],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final prior = await tx.query(
          'movements',
          where: 'sku = ? AND id = ?',
          whereArgs: [draft.sku, operationId],
          limit: 1,
        );
        if (prior.isNotEmpty &&
            prior.single['sku'] == draft.sku &&
            prior.single['type'] == 'opening' &&
            prior.single['afterQuantity'] == draft.openingStock) {
          final current = _productFromRow(existing.single);
          if (current.name == draft.name &&
              current.category == draft.category &&
              current.currency == draft.currency &&
              current.costMinor == draft.costMinor &&
              current.priceMinor == draft.priceMinor &&
              current.reorderLevel == draft.reorderLevel &&
              jsonEncode(current.parameters.map((p) => p.toMap()).toList()) ==
                  jsonEncode(draft.parameters.map((p) => p.toMap()).toList()) &&
              jsonEncode(current.pricingFormula?.toMap()) ==
                  jsonEncode(draft.pricingFormula?.toMap())) {
            return;
          }
        }
        throw inventoryInvalid(
          'This product code is already used, including archived products. Choose another code.',
        );
      }
      await tx.insert(
        'products',
        _productValues(
          sku: draft.sku,
          name: draft.name,
          category: draft.category,
          currency: draft.currency,
          costMinor: draft.costMinor,
          priceMinor: draft.priceMinor,
          quantity: draft.openingStock,
          reorderLevel: draft.reorderLevel,
          parameters: draft.parameters,
          pricingFormula: draft.pricingFormula,
          archived: false,
          revision: 1,
          lastMovementId: operationId,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await tx.insert(
        'movements',
        _movementValues(
          id: operationId,
          sku: draft.sku,
          type: 'opening',
          before: 0,
          after: draft.openingStock,
          reason: 'Opening stock',
          uid: uid,
          revision: 1,
          createdAt: now,
        ),
      );
    });
  }

  @override
  Future<void> update(
    String uid,
    ProductDraft draft,
    int expectedRevision,
  ) async {
    _checkOwner(uid);
    await _tryImportLegacyInventory(uid);
    draft.validate();
    final db = await _store.databaseFor(uid);
    await db.transaction((tx) async {
      final current = await _readProduct(tx, draft.sku);
      if (current.revision != expectedRevision) throw _stale;
      if (current.archived) {
        throw inventoryInvalid('Restore this product before editing it.');
      }
      if (current.currency != draft.currency) {
        throw inventoryInvalid('A saved product’s currency cannot be changed.');
      }
      await tx.update(
        'products',
        {
          'name': draft.name,
          'category': draft.category,
          'costMinor': draft.costMinor,
          'priceMinor': draft.priceMinor,
          'reorderLevel': draft.reorderLevel,
          'parameters': jsonEncode([
            for (final parameter in draft.parameters) parameter.toMap(),
          ]),
          'pricingFormula': draft.pricingFormula == null
              ? null
              : jsonEncode(draft.pricingFormula!.toMap()),
          'revision': current.revision + 1,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'sku = ?',
        whereArgs: [draft.sku],
      );
    });
  }

  @override
  Future<void> setArchived(String uid, Product product, bool archived) async {
    _checkOwner(uid);
    await _tryImportLegacyInventory(uid);
    final db = await _store.databaseFor(uid);
    await db.transaction((tx) async {
      final current = await _readProduct(tx, product.sku);
      if (current.archived == archived) return;
      if (current.revision != product.revision) throw _stale;
      if (current.quantity != 0) {
        throw inventoryInvalid(
          'Stock must be zero before archiving. Record a stock adjustment first.',
        );
      }
      await tx.update(
        'products',
        {
          'archived': archived ? 1 : 0,
          'revision': current.revision + 1,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'sku = ?',
        whereArgs: [product.sku],
      );
    });
  }

  @override
  Future<void> adjust(
    String uid,
    Product product,
    int delta,
    String reason,
    String operationId,
  ) async {
    _checkOwner(uid);
    await _tryImportLegacyInventory(uid);
    if (delta == 0 ||
        delta.abs() > maxStock ||
        reason.trim().isEmpty ||
        reason.length > 200 ||
        !InventoryCodec.validOperationId(operationId)) {
      throw inventoryInvalid(
        'Enter valid units and a reason for this adjustment.',
      );
    }
    final db = await _store.databaseFor(uid);
    await db.transaction((tx) async {
      final prior = await tx.query(
        'movements',
        where: 'sku = ? AND id = ?',
        whereArgs: [product.sku, operationId],
        limit: 1,
      );
      if (prior.isNotEmpty) {
        if (prior.single['sku'] == product.sku &&
            prior.single['type'] == 'adjustment' &&
            prior.single['delta'] == delta &&
            prior.single['reason'] == reason) {
          return;
        }
        throw inventoryInvalid(
          'This change was already recorded with different details. Refresh before another adjustment.',
        );
      }
      final current = await _readProduct(tx, product.sku);
      if (current.archived) {
        throw inventoryInvalid(
          'Restore this product before changing its stock.',
        );
      }
      if (current.revision != product.revision) throw _stale;
      final after = current.quantity + delta;
      if (after < 0 || after > maxStock) {
        throw inventoryInvalid(
          'This adjustment would put stock outside the supported range.',
        );
      }
      final now = DateTime.now().toUtc();
      await tx.update(
        'products',
        {
          'quantity': after,
          'revision': current.revision + 1,
          'lastMovementId': operationId,
          'updatedAt': now.toIso8601String(),
        },
        where: 'sku = ?',
        whereArgs: [product.sku],
      );
      await tx.insert(
        'movements',
        _movementValues(
          id: operationId,
          sku: product.sku,
          type: 'adjustment',
          before: current.quantity,
          after: after,
          reason: reason,
          uid: uid,
          revision: current.revision + 1,
          createdAt: now,
        ),
      );
    });
  }

  @override
  Future<MovementPage> movements(
    String uid,
    String sku, {
    MovementCursor? after,
  }) async {
    _checkOwner(uid);
    await _tryImportLegacyInventory(uid);
    final db = await _store.databaseFor(uid);
    final rows = await db.query(
      'movements',
      where: after == null
          ? 'sku = ?'
          : 'sku = ? AND (createdAt < ? OR (createdAt = ? AND id < ?))',
      whereArgs: after == null
          ? [sku]
          : [
              sku,
              after.time.toUtc().toIso8601String(),
              after.time.toUtc().toIso8601String(),
              after.id,
            ],
      orderBy: 'createdAt DESC, id DESC',
      limit: _pageSize + 1,
    );
    final hasNext = rows.length > _pageSize;
    final page = rows.take(_pageSize).map(_movementFromRow).toList();
    final last = page.lastOrNull;
    return MovementPage(
      page,
      hasNext && last != null ? MovementCursor(last.createdAt, last.id) : null,
    );
  }

  Future<Product> _readProduct(DatabaseExecutor tx, String sku) async {
    final rows = await tx.query(
      'products',
      where: 'sku = ?',
      whereArgs: [sku],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw inventoryInvalid(
        'This product no longer exists. Refresh inventory.',
      );
    }
    return _productFromRow(rows.single);
  }

  Future<void> _tryImportLegacyInventory(String uid) async {
    final source = legacySource;
    if (source == null || uid == 'device-local-owner') return;
    final db = await _store.databaseFor(uid);
    final marker = 'legacy_inventory_imported_$uid';
    final marked = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [marker],
      limit: 1,
    );
    if (marked.isNotEmpty) return;
    // Join an active import before applying the retry cooldown. Otherwise a
    // second caller can edit/create stock while the first import is running.
    final inFlight = _imports[uid];
    if (inFlight != null) {
      return inFlight;
    }
    final last = _lastImportAttempts[uid];
    if (last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 1)) {
      return;
    }
    final task = _importLegacy(uid, source, db, marker);
    _imports[uid] = task;
    try {
      await task;
    } finally {
      _imports.remove(uid);
    }
  }

  Future<void> _importLegacy(
    String uid,
    InventoryRepository source,
    Database db,
    String marker,
  ) async {
    _lastImportAttempts[uid] = DateTime.now();
    final timer = Stopwatch()..start();
    Future<T> bounded<T>(Future<T> request) {
      final remaining = legacyImportTimeout - timer.elapsed;
      return request.timeout(remaining.isNegative ? Duration.zero : remaining);
    }

    try {
      final products = <Product>[];
      for (final archived in [false, true]) {
        InventoryCursor? cursor;
        do {
          final page = await bounded(
            source.list(uid, InventoryQuery(archived: archived), after: cursor),
          );
          products.addAll(page.products);
          cursor = page.next;
        } while (cursor != null);
      }
      final histories = <String, List<StockMovement>>{};
      for (final product in products) {
        final movements = <StockMovement>[];
        MovementCursor? cursor;
        do {
          final page = await bounded(
            source.movements(uid, product.sku, after: cursor),
          );
          movements.addAll(page.movements);
          cursor = page.next;
        } while (cursor != null);
        histories[product.sku] = movements;
      }
      await db.transaction((tx) async {
        for (final product in products) {
          // A local product may have been created while an earlier offline
          // import failed. Its stock/history form one local ledger: do not
          // attach an unrelated cloud history to it.
          final existing = await tx.query(
            'products',
            columns: ['sku'],
            where: 'sku = ?',
            whereArgs: [product.sku],
          );
          if (existing.isNotEmpty) continue;
          await tx.insert(
            'products',
            _productValues(
              sku: product.sku,
              name: product.name,
              category: product.category,
              currency: product.currency,
              costMinor: product.costMinor,
              priceMinor: product.priceMinor,
              quantity: product.quantity,
              reorderLevel: product.reorderLevel,
              archived: product.archived,
              revision: product.revision,
              lastMovementId: product.lastMovementId,
              createdAt: product.createdAt,
              updatedAt: product.updatedAt,
              parameters: product.parameters,
              pricingFormula: product.pricingFormula,
            ),
          );
          for (final movement
              in histories[product.sku] ?? const <StockMovement>[]) {
            await tx.insert('movements', {
              'id': movement.id,
              'sku': product.sku,
              'type': movement.type,
              'beforeQuantity': movement.beforeQuantity,
              'afterQuantity': movement.afterQuantity,
              'delta': movement.delta,
              'reason': movement.reason,
              'actorUid': movement.actorUid,
              'revision': movement.revision,
              'createdAt': movement.createdAt.toUtc().toIso8601String(),
            });
          }
        }
        await tx.insert('settings', {
          'key': marker,
          'value': '1',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
      _failedImportUids.remove(uid);
    } catch (_) {
      // Keep local register use available if the device is offline or legacy
      // Firestore reads are denied. Retry on a later operation.
      _failedImportUids.add(uid);
    }
  }
}

const _stale = AppFailure(
  FailureKind.invalidData,
  'This product changed on another screen. Refresh it before saving again.',
);

void _checkOwner(String uid) {
  if (uid.isEmpty || uid.contains('/')) {
    throw inventoryInvalid('Sign in again before using inventory.');
  }
}

Product _productFromRow(Map<String, Object?> row) {
  final rawParameters = jsonDecode(row['parameters']! as String);
  if (rawParameters is! List ||
      rawParameters.any(
        (entry) =>
            entry is! Map ||
            entry['name'] is! String ||
            entry['value'] is! String,
      )) {
    throw inventoryInvalid('This product’s parameters could not be read.');
  }
  PricingFormula? pricingFormula;
  final rawFormula = row['pricingFormula'] as String?;
  if (rawFormula != null && rawFormula.isNotEmpty) {
    final decoded = jsonDecode(rawFormula);
    if (decoded is! Map) {
      throw inventoryInvalid(
        'This product’s pricing formula could not be read.',
      );
    }
    pricingFormula = PricingFormula.fromMap(decoded);
  }
  final product = Product(
    sku: row['sku']! as String,
    name: row['name']! as String,
    category: row['category']! as String,
    currency: row['currency']! as String,
    costMinor: row['costMinor']! as int,
    priceMinor: row['priceMinor']! as int,
    quantity: row['quantity']! as int,
    reorderLevel: row['reorderLevel']! as int,
    archived: row['archived'] == 1,
    revision: row['revision']! as int,
    lastMovementId: row['lastMovementId']! as String,
    createdAt: DateTime.parse(row['createdAt']! as String),
    updatedAt: DateTime.parse(row['updatedAt']! as String),
    parameters: [
      for (final entry in rawParameters)
        ProductParameter.fromMap(entry as Map<dynamic, dynamic>),
    ],
    pricingFormula: pricingFormula,
  );
  product.draft.validate();
  return product;
}

Map<String, Object?> _productValues({
  required String sku,
  required String name,
  required String category,
  required String currency,
  required int costMinor,
  required int priceMinor,
  required int quantity,
  required int reorderLevel,
  required bool archived,
  required int revision,
  required String lastMovementId,
  required DateTime createdAt,
  required DateTime updatedAt,
  List<ProductParameter> parameters = const [],
  PricingFormula? pricingFormula,
}) => {
  'sku': sku,
  'name': name,
  'category': category,
  'parameters': jsonEncode([
    for (final parameter in parameters) parameter.toMap(),
  ]),
  'pricingFormula': pricingFormula == null
      ? null
      : jsonEncode(pricingFormula.toMap()),
  'currency': currency,
  'costMinor': costMinor,
  'priceMinor': priceMinor,
  'quantity': quantity,
  'reorderLevel': reorderLevel,
  'archived': archived ? 1 : 0,
  'revision': revision,
  'lastMovementId': lastMovementId,
  'createdAt': createdAt.toUtc().toIso8601String(),
  'updatedAt': updatedAt.toUtc().toIso8601String(),
};

Map<String, Object?> _movementValues({
  required String id,
  required String sku,
  required String type,
  required int before,
  required int after,
  required String reason,
  required String uid,
  required int revision,
  required DateTime createdAt,
}) => {
  'id': id,
  'sku': sku,
  'type': type,
  'beforeQuantity': before,
  'afterQuantity': after,
  'delta': after - before,
  'reason': reason,
  'actorUid': uid,
  'revision': revision,
  'createdAt': createdAt.toUtc().toIso8601String(),
};

StockMovement _movementFromRow(Map<String, Object?> row) => StockMovement(
  id: row['id']! as String,
  type: row['type']! as String,
  beforeQuantity: row['beforeQuantity']! as int,
  afterQuantity: row['afterQuantity']! as int,
  delta: row['delta']! as int,
  reason: row['reason']! as String,
  actorUid: row['actorUid']! as String,
  revision: row['revision']! as int,
  createdAt: DateTime.parse(row['createdAt']! as String),
);

String _localId() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
}
