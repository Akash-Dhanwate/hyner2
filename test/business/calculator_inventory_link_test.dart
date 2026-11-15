import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/features/inventory/data/local_inventory_repository.dart';
import 'package:hyner/features/inventory/domain/inventory_repository.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/pricing/application/calculator_inventory_link.dart';
import 'package:hyner/features/pricing/application/product_setup.dart';
import 'package:hyner/features/pricing/application/simple_calculator.dart';
import 'package:hyner/features/pricing/domain/exact.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late LocalBusinessDatabase store;
  late LocalInventoryRepository inventory;
  late CalculatorInventoryLinker linker;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hyner-calc-inventory-');
    store = LocalBusinessDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    inventory = LocalInventoryRepository(store);
    linker = CalculatorInventoryLinker(inventory);
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  test(
    'creates one inventory item and retries without duplicate stock',
    () async {
      final firstSku = await linker.link(
        uid: 'shop',
        productId: 'aabbccdd',
        name: 'Door PVC',
        category: 'Doors',
        currency: 'INR',
        costMinor: 50000,
        priceMinor: 75000,
        openingStock: 50,
        reorderLevel: 5,
        isWorkspaceCurrent: () => true,
      );
      expect(firstSku, 'QPAABBCCDD');

      final retriedSku = await linker.link(
        uid: 'shop',
        productId: 'aabbccdd',
        name: 'Door PVC Updated',
        category: 'Doors',
        currency: 'INR',
        costMinor: 51000,
        priceMinor: 76000,
        openingStock: 900,
        reorderLevel: 6,
        isWorkspaceCurrent: () => true,
      );
      expect(retriedSku, firstSku);

      final product = await inventory.get('shop', firstSku);
      expect(product.name, 'Door PVC Updated');
      expect(product.quantity, 50, reason: 'A retry must not reset stock.');
      expect(product.costMinor, 51000);
      expect(product.priceMinor, 76000);
      expect(product.reorderLevel, 6);
      final movements = await inventory.movements('shop', firstSku);
      expect(movements.movements, hasLength(1));
      expect(movements.movements.single.afterQuantity, 50);
    },
  );

  test(
    'links a matching existing item without replacing its stock or price',
    () async {
      await inventory.create(
        'shop',
        ProductDraft(
          sku: 'DOOR-1',
          name: 'Door PVC',
          category: 'Hardware',
          currency: 'INR',
          costMinor: 34000,
          priceMinor: 62000,
          openingStock: 12,
          reorderLevel: 2,
        ),
        'opening_door',
      );

      final sku = await linker.link(
        uid: 'shop',
        productId: '11223344',
        name: '  DOOR   PVC ',
        category: 'Doors',
        currency: 'INR',
        costMinor: 0,
        priceMinor: 0,
        openingStock: 50,
        reorderLevel: 5,
        isWorkspaceCurrent: () => true,
      );
      final product = await inventory.get('shop', sku);
      expect(sku, 'DOOR-1');
      expect(product.quantity, 12);
      expect(product.costMinor, 34000);
      expect(product.priceMinor, 62000);
      expect(await inventory.movements('shop', sku), isNotNull);
    },
  );

  test('rejects writes after the active workspace changes', () async {
    await expectLater(
      linker.link(
        uid: 'shop',
        productId: '11223344',
        name: 'Door PVC',
        category: 'Doors',
        currency: 'INR',
        costMinor: 0,
        priceMinor: 0,
        openingStock: 50,
        reorderLevel: 5,
        isWorkspaceCurrent: () => false,
      ),
      throwsStateError,
    );
    expect(await inventory.list('shop', const InventoryQuery()), isNotNull);
    expect(
      (await inventory.list('shop', const InventoryQuery())).products,
      isEmpty,
    );
  });

  test(
    'calculator varieties become unique stock products with their rates',
    () async {
      final setup = ProductSetup.create(kind: 'area');
      setup.data['name'] = 'PVC Door';
      setup.data['taxBehavior'] = 'exempt';
      configureSimpleVarieties(setup, [
        {'id': 'solid', 'name': 'Solid', 'amount': '125'},
        {'id': 'grooved', 'name': 'Grooved', 'amount': '175'},
      ]);
      final product = setup.compile('shop', Currency('INR', 2));

      final linked = await linkCalculatorProductVariants(
        linker: linker,
        uid: 'shop',
        product: product,
        category: 'Doors',
        costMinor: 8000,
        costMinorByRateId: {'solid': 8000, 'grooved': 9500},
        fallbackPriceMinor: 0,
        openingStock: 100,
        reorderLevel: 10,
        isWorkspaceCurrent: () => true,
      );

      expect(linked.inventorySkuByRateId, hasLength(2));
      expect(linked.inventorySkuByRateId.values.toSet(), hasLength(2));
      final products = (await inventory.list(
        'shop',
        const InventoryQuery(),
      )).products;
      expect(products, hasLength(2));
      final solid = products.singleWhere((p) => p.name.contains('Solid'));
      final grooved = products.singleWhere((p) => p.name.contains('Grooved'));
      expect(solid.sku, isNot(grooved.sku));
      expect(solid.priceMinor, 12500);
      expect(grooved.priceMinor, 17500);
      expect(solid.costMinor, 8000);
      expect(grooved.costMinor, 9500);
      for (final item in products) {
        expect(item.quantity, 100);
        expect(item.reorderLevel, 10);
        expect(item.parameters, hasLength(1));
      }

      await linkCalculatorProductVariants(
        linker: linker,
        uid: 'shop',
        product: linked,
        category: 'Doors',
        costMinor: 9000,
        fallbackPriceMinor: 0,
        openingStock: 999,
        reorderLevel: 10,
        isWorkspaceCurrent: () => true,
      );
      final afterRetry = (await inventory.list(
        'shop',
        const InventoryQuery(),
      )).products;
      expect(afterRetry, hasLength(2));
      expect(afterRetry.map((p) => p.quantity), everyElement(100));
      expect(afterRetry.map((p) => p.costMinor), everyElement(9000));
    },
  );

  test('a calculator without varieties remains one product', () async {
    final setup = ProductSetup.create(kind: 'perUnit');
    setup.data['name'] = 'Screw';
    setup.data['taxBehavior'] = 'exempt';
    setup.rows('rates').first['amount'] = '4.50';
    final linked = await linkCalculatorProductVariants(
      linker: linker,
      uid: 'shop',
      product: setup.compile('shop', Currency('INR', 2)),
      category: 'Hardware',
      costMinor: 200,
      fallbackPriceMinor: 0,
      openingStock: 100,
      reorderLevel: 10,
      isWorkspaceCurrent: () => true,
    );
    final page = await inventory.list('shop', const InventoryQuery());
    expect(page.products, hasLength(1));
    expect(page.products.single.name, 'Screw');
    expect(page.products.single.priceMinor, 450);
    expect(linked.inventorySku, page.products.single.sku);
  });
}
