import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/theme/app_theme.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/customers/domain/customer.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/inventory/presentation/inventory_controller.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/sales/domain/sale_checkout_seed.dart';
import 'package:hyner/features/sales/domain/sale_price_snapshot.dart';
import 'package:hyner/features/sales/presentation/sale_detail_screen.dart';
import 'package:hyner/features/sales/presentation/sale_editor_screen.dart';

import '../support/universal_fixture.dart' as pricing;
import 'support/fakes.dart';
import 'support/inventory_fakes.dart';
import 'support/sales_fakes.dart';

final _accountProvider = NotifierProvider<_Account, String?>(_Account.new);

class _Account extends Notifier<String?> {
  @override
  String? build() => testIdentity.uid;

  void select(String? uid) => state = uid;
}

class _CheckoutInventory extends FakeInventory {
  final gets = <String>[];

  @override
  Future<Product> get(String uid, String sku) {
    gets.add(sku);
    return super.get(uid, sku);
  }
}

/// Keeps these editor tests independent of the shared inventory-only fake.
class _CheckoutSales extends FakeSales {
  _CheckoutSales(super.inventory);

  final attemptedIds = <String>[];
  final attemptedUids = <String>[];

  @override
  Future<void> create(String uid, String id, SaleDraft draft) async {
    attemptedIds.add(id);
    attemptedUids.add(uid);
    if (pendingWrite != null) await pendingWrite!.future;
    if (failure != null) throw failure!;
    draft.validateForNewBill();
    final existing = sales(uid)[id];
    if (existing != null) {
      if (!existing.draft.matches(draft)) {
        throw inventoryInvalid('Sale reference already used');
      }
      return;
    }
    for (final line in draft.lines.where((line) => line.pricing == null)) {
      final product = inventory.products(uid)[line.sku];
      if (product == null || product.quantity < line.quantity) {
        throw inventoryInvalid('Insufficient available stock.');
      }
      inventory.products(uid)[line.sku] = inventoryFixture(
        sku: product.sku,
        name: product.name,
        quantity: product.quantity - line.quantity,
        priceMinor: product.priceMinor,
        revision: product.revision + 1,
      );
    }
    sales(uid)[id] = Sale(
      id: id,
      draft: draft,
      createdAt: DateTime.utc(2026, 11, 9),
    );
    writes++;
    if (failAfterCommit) {
      throw const AppFailure(FailureKind.network, 'Connection interrupted');
    }
  }
}

SaleLine _pricedLine(int index, {int quantity = 1, String rate = '12.50'}) {
  final result = pricing.price(
    pricing.rule(
      strategy: pricing.piece('piece'),
      rates: [pricing.rate('piece', rate, 'piece')],
    ),
    quantity: quantity,
  );
  final snapshot = SalePriceSnapshot.fromResult(result);
  return SaleLine(
    sku: 'QP_${index.toString().padLeft(32, '0')}',
    name: 'Measured item $index',
    quantity: snapshot.quantity,
    unitPriceMinor: snapshot.unitPriceMinor,
    pricing: snapshot,
    parameters: [ProductParameter(name: 'Finish', value: 'Finish $index')],
  );
}

SaleCheckoutSeed _seed({
  String uid = 'test-alice',
  String operationId = 'estimate-operation-1',
  List<SaleLine>? lines,
  Future<void> Function(String saleId)? onSaved,
}) => SaleCheckoutSeed(
  uid: uid,
  operationId: operationId,
  lines: lines ?? [_pricedLine(1)],
  onSaved: onSaved,
);

void main() {
  late _CheckoutInventory inventory;
  late _CheckoutSales sales;
  late ProviderContainer container;
  late GoRouter router;
  late ValueNotifier<SaleCheckoutSeed> checkout;

  Future<void> mount(
    WidgetTester tester,
    SaleCheckoutSeed seed, {
    Customer? customer,
    String? customerId,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final auth = FakeAuth(user: testIdentity);
    inventory = _CheckoutInventory();
    sales = _CheckoutSales(inventory);
    final dependencies = connectedTestDependencies(
      auth,
      FakeProfiles(),
      inventory: inventory,
      sales: sales,
    );
    if (customer != null) {
      (dependencies.customers as FakeCustomers).accounts[seed.uid] = [customer];
    }
    container = ProviderContainer(
      overrides: [
        dependenciesProvider.overrideWithValue(dependencies),
        inventoryUidProvider.overrideWith((ref) => ref.watch(_accountProvider)),
      ],
    );
    checkout = ValueNotifier(seed);
    router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('QuickPrice')),
        ),
        GoRoute(
          path: '/checkout',
          builder: (_, _) => ValueListenableBuilder<SaleCheckoutSeed>(
            valueListenable: checkout,
            builder: (_, seed, _) =>
                SaleEditorScreen(checkout: seed, customerId: customerId),
          ),
        ),
        GoRoute(
          path: '/sales/:id',
          builder: (_, state) =>
              SaleDetailScreen(id: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(() async {
      router.dispose();
      checkout.dispose();
      container.dispose();
      await auth.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: HynerTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    // Settle onChanged/focus layout before calculating the scroll destination.
    // On a small screen, PageContent may not have built the form sliver yet.
    await tester.pumpAndSettle();
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .last,
        maxScrolls: 80,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await reveal(tester, finder);
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enterCustomer(WidgetTester tester) async {
    for (final entry in {
      'sale-customer-name': 'Asha Buyer',
      'sale-customer-phone': '9876543210',
      'sale-customer-address': '12 Market Road',
    }.entries) {
      final field = find.byKey(Key(entry.key));
      await reveal(tester, field);
      await tester.enterText(field, entry.value);
    }
    await tester.pumpAndSettle();
  }

  test(
    'checkout seed copies lines and validates account, ID and priced items',
    () {
      final lines = [_pricedLine(1)];
      final seed = _seed(lines: lines);
      lines.clear();
      expect(seed.lines, hasLength(1));
      expect(() => seed.lines.clear(), throwsUnsupportedError);
      for (final uid in ['', 'bad/account', ' account ', 'a' * 129]) {
        expect(() => _seed(uid: uid), throwsA(isA<AppFailure>()));
      }
      for (final id in ['', '../sale', 'id with spaces', 'a' * 65]) {
        expect(() => _seed(operationId: id), throwsA(isA<AppFailure>()));
      }
      expect(() => _seed(lines: []), throwsA(isA<AppFailure>()));
      expect(
        () => _seed(lines: [SaleLine.fromProduct(inventoryFixture(), 1)]),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => _seed(lines: [_pricedLine(1), _pricedLine(1)]),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  testWidgets('six seeded items prefill read-only checkout without inventory', (
    tester,
  ) async {
    final lines = [for (var i = 1; i <= 6; i++) _pricedLine(i)];
    final seed = _seed(lines: lines);
    await mount(tester, seed);
    expect(find.text('QuickPrice items (6)'), findsOneWidget);
    expect(find.byKey(const Key('add-sale-product')), findsNothing);
    expect(find.text('Additional products'), findsOneWidget);
    expect(find.text('No products added yet.'), findsNothing);
    expect(find.text('Measured item 6'), findsNothing);
    expect(find.text('Finish · Finish 6'), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('sale-checkout-summary-total')))
          .data,
      'INR 75.00 · Review items',
    );
    expect(
      find.byKey(const Key('sale-customer-name')).hitTestable(),
      findsOneWidget,
    );
    await tap(tester, find.text('QuickPrice items (6)'));
    expect(find.text('Measured item 6'), findsOneWidget);
    expect(find.text('Finish · Finish 6'), findsOneWidget);
    expect(find.text('Quantity 1 · Unit price INR 12.50'), findsNWidgets(6));
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.byType(Dialog), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('sale-total'))).data,
      'INR 75.00',
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('save-sale'))).onPressed,
      isNotNull,
    );
    await tap(tester, find.text('QuickPrice items (6)'));
    expect(find.text('Measured item 6'), findsNothing);
    await tap(tester, find.text('Additional products'));
    expect(find.text('Add product (6 added)'), findsOneWidget);
    await tap(tester, find.text('Additional products'));
    await enterCustomer(tester);
    await tap(tester, find.byKey(const Key('save-sale')));
    final draft = sales.sales(seed.uid)[seed.operationId]!.draft;
    expect(draft.lines, orderedEquals(seed.lines));
    expect(draft.totalMinor, 7500);
    expect(draft.customerName, 'Asha Buyer');
    expect(draft.customerPhone, '9876543210');
    expect(draft.customerAddress, '12 Market Road');
    expect(sales.ids, 0);
    expect(sales.writes, 1);
    expect(inventory.listCalls, 0);
    expect(inventory.gets, isEmpty);
    expect(inventory.writes, 0);
    expect(router.state.uri.path, '/sales/${seed.operationId}');
    expect(find.text('SAVED SALE'), findsOneWidget);
  });

  testWidgets('seeded bill still requires customer name and valid mobile', (
    tester,
  ) async {
    await mount(tester, _seed());
    await tap(tester, find.byKey(const Key('save-sale')));
    expect(find.text('Enter the customer name.'), findsOneWidget);
    expect(find.text('Enter a valid mobile number.'), findsOneWidget);
    expect(sales.attemptedIds, isEmpty);
    await enterCustomer(tester);
    await tap(tester, find.text('Pay later'));
    await tap(tester, find.byKey(const Key('save-sale')));
    final draft = sales
        .sales(testIdentity.uid)[checkout.value.operationId]!
        .draft;
    expect(draft.firstPaymentMinor, 0);
    expect(sales.writes, 1);
  });

  testWidgets('initial customer and advance payment use the shared workflow', (
    tester,
  ) async {
    final customer = Customer(
      id: 'buyer',
      name: 'Existing Buyer',
      phone: '9876543210',
      notes: '',
      address: '7 Market Road',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    await mount(tester, _seed(), customer: customer, customerId: customer.id);
    expect(find.byKey(const Key('sale-customer-name')), findsNothing);
    await tap(tester, find.text('Advance'));
    final advance = find.byKey(const Key('sale-advance-amount'));
    await reveal(tester, advance);
    await tester.enterText(advance, '5.00');
    await tap(tester, find.byKey(const Key('save-sale')));
    final draft = sales
        .sales(testIdentity.uid)[checkout.value.operationId]!
        .draft;
    expect(draft.customerId, customer.id);
    expect(draft.customerAddress, customer.address);
    expect(draft.firstPaymentMinor, 500);
  });

  testWidgets('uncertain save retries the seed ID and frozen draft only once', (
    tester,
  ) async {
    final seed = _seed();
    await mount(tester, seed);
    await enterCustomer(tester);
    sales.failAfterCommit = true;
    await tap(tester, find.byKey(const Key('save-sale')));
    expect(find.text('Connection interrupted'), findsOneWidget);
    expect(sales.writes, 1);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('sale-customer-name')))
          .enabled,
      isFalse,
    );
    await tap(tester, find.text('Additional products'));
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('add-sale-product')))
          .onPressed,
      isNull,
    );
    await tap(tester, find.byKey(const Key('save-sale')));
    expect(sales.attemptedIds, [seed.operationId, seed.operationId]);
    expect(sales.ids, 0);
    expect(sales.writes, 1);
    expect(sales.sales(seed.uid), hasLength(1));
    expect(router.state.uri.path, '/sales/${seed.operationId}');
    expect(inventory.gets, isEmpty);
  });

  testWidgets('quantity and totals preserve a rounded unit price discrepancy', (
    tester,
  ) async {
    final line = _pricedLine(1, quantity: 3, rate: '0.33333');
    final seed = _seed(lines: [line]);
    expect(line.unitPriceMinor, 33);
    expect(line.totalMinor, 100);
    await mount(tester, seed);
    expect(find.text('Line total INR 1.00'), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('sale-checkout-summary-total')))
          .data,
      'INR 1.00 · Review items',
    );
    await tap(tester, find.text('QuickPrice items (1)'));
    expect(
      find.text('Quantity 3 · Unit price approx. INR 0.33'),
      findsOneWidget,
    );
    expect(find.text('Line total INR 1.00'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('sale-total'))).data,
      'INR 1.00',
    );
    await tap(tester, find.text('QuickPrice items (1)'));
    await enterCustomer(tester);
    await tap(tester, find.text('Advance'));
    final advance = find.byKey(const Key('sale-advance-amount'));
    await reveal(tester, advance);
    await tester.enterText(advance, '1.01');
    await tap(tester, find.byKey(const Key('save-sale')));
    expect(sales.writes, 0);
    expect(
      find.text(
        'Enter an amount greater than zero and no more than the bill total.',
      ),
      findsOneWidget,
    );
    await reveal(tester, advance);
    await tester.enterText(advance, '1.00');
    await tap(tester, find.byKey(const Key('save-sale')));
    expect(sales.writes, 1);
    final saved = sales.sales(seed.uid)[seed.operationId]!.draft;
    expect(saved.units, 3);
    expect(saved.totalMinor, 100);
    expect(saved.firstPaymentMinor, 100);
    expect(
      saved.lines.single.pricing!.snapshotJson,
      line.pricing!.snapshotJson,
    );
  });

  testWidgets(
    'manual inventory items append after seed and alone affect stock',
    (tester) async {
      final seed = _seed();
      await mount(tester, seed);
      inventory.products(seed.uid)['TEST-1'] = inventoryFixture(quantity: 5);
      await tap(tester, find.text('Additional products'));
      await tap(tester, find.byKey(const Key('add-sale-product')));
      await tap(tester, find.byKey(const Key('pick-TEST-1')));
      expect(find.text('Add product (2 added)'), findsOneWidget);
      await enterCustomer(tester);
      await tap(tester, find.byKey(const Key('save-sale')));
      final saved = sales.sales(seed.uid)[seed.operationId]!.draft;
      expect(saved.lines.map((line) => line.sku), [
        seed.lines.single.sku,
        'TEST-1',
      ]);
      expect(saved.totalMinor, 13800);
      expect(inventory.products(seed.uid)['TEST-1']!.quantity, 4);
      expect(inventory.gets, isNotEmpty);
      expect(inventory.gets.every((sku) => sku == 'TEST-1'), isTrue);
    },
  );

  testWidgets('checkout completion failure still opens the committed bill', (
    tester,
  ) async {
    final completed = <String>[];
    final seed = _seed(
      onSaved: (id) async {
        completed.add(id);
        throw StateError('Estimate status could not be updated');
      },
    );
    await mount(tester, seed);
    await enterCustomer(tester);
    await tap(tester, find.byKey(const Key('save-sale')));
    expect(completed, [seed.operationId]);
    expect(sales.writes, 1);
    expect(router.state.uri.path, '/sales/${seed.operationId}');
    expect(find.text('SAVED SALE'), findsOneWidget);
    expect(find.text('Check and retry sale'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending save disables a second write and completion waits for it',
    (tester) async {
      final completed = <String>[];
      final seed = _seed(onSaved: (id) async => completed.add(id));
      await mount(tester, seed);
      await enterCustomer(tester);
      sales.pendingWrite = Completer<void>();
      final save = find.byKey(const Key('save-sale'));
      await reveal(tester, save);
      await tester.tap(save);
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(completed, isEmpty);
      sales.pendingWrite!.complete();
      await tester.pumpAndSettle();
      expect(sales.attemptedIds, [seed.operationId]);
      expect(completed, [seed.operationId]);
    },
  );

  testWidgets('switching accounts hides seed and customer details', (
    tester,
  ) async {
    final seed = _seed();
    await mount(tester, seed);
    expect(find.byKey(const Key('sale-checkout-lines')), findsOneWidget);
    await enterCustomer(tester);
    container.read(_accountProvider.notifier).select('bob');
    await tester.pumpAndSettle();
    expect(find.text('Measured item 1'), findsNothing);
    expect(find.byKey(const Key('sale-checkout-lines')), findsNothing);
    expect(find.byKey(const Key('sale-customer-name')), findsNothing);
    expect(find.byKey(const Key('save-sale')), findsNothing);
    expect(sales.writes, 0);
    checkout.value = _seed(uid: 'bob', operationId: 'bob-estimate');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('sale-customer-name')))
          .controller!
          .text,
      isEmpty,
    );
    await enterCustomer(tester);
    await tap(tester, find.byKey(const Key('save-sale')));
    expect(sales.attemptedUids, ['bob']);
    expect(sales.sales(seed.uid), isEmpty);
    expect(sales.sales('bob').keys, ['bob-estimate']);
  });

  testWidgets('account change during write cannot invoke the old completion', (
    tester,
  ) async {
    final completed = <String>[];
    final seed = _seed(onSaved: (id) async => completed.add(id));
    await mount(tester, seed);
    await enterCustomer(tester);
    sales.pendingWrite = Completer<void>();
    final save = find.byKey(const Key('save-sale'));
    await reveal(tester, save);
    await tester.tap(save);
    await tester.pump();
    container.read(_accountProvider.notifier).select('bob');
    await tester.pump();
    sales.pendingWrite!.complete();
    await tester.pumpAndSettle();
    expect(completed, isEmpty);
    expect(router.state.uri.path, '/checkout');
    expect(sales.attemptedUids, [seed.uid]);
    expect(sales.sales('bob'), isEmpty);
  });

  testWidgets('changing operation resets customer details and the save ID', (
    tester,
  ) async {
    await mount(tester, _seed());
    await enterCustomer(tester);
    final next = _seed(operationId: 'next-estimate', lines: [_pricedLine(2)]);
    checkout.value = next;
    await tester.pumpAndSettle();
    await tap(tester, find.text('QuickPrice items (1)'));
    expect(find.text('Measured item 1'), findsNothing);
    expect(find.text('Measured item 2'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('sale-customer-name')))
          .controller!
          .text,
      isEmpty,
    );
    await tap(tester, find.text('QuickPrice items (1)'));
    await enterCustomer(tester);
    await tap(tester, find.byKey(const Key('save-sale')));
    expect(sales.attemptedIds, [next.operationId]);
  });

  testWidgets('seeded checkout participates in the discard confirmation', (
    tester,
  ) async {
    await mount(tester, _seed());
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Discard this bill?'), findsOneWidget);
    await tap(tester, find.text('Stay'));
    expect(find.byKey(const Key('save-sale')), findsOneWidget);
    await tap(tester, find.byKey(const Key('back-to-quickprice')));
    expect(find.text('Discard this bill?'), findsOneWidget);
    expect(sales.writes, 0);
  });

  testWidgets('seed summary fits narrow screens with large text', (
    tester,
  ) async {
    await mount(
      tester,
      _seed(lines: [for (var i = 1; i <= 6; i++) _pricedLine(i, quantity: 3)]),
      size: const Size(320, 568),
      textScale: 1.6,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Measured item 6'), findsNothing);
    await tap(tester, find.text('QuickPrice items (6)'));
    expect(find.text('Measured item 6'), findsOneWidget);
    expect(find.text('Quantity 3 · Unit price INR 12.50'), findsNWidgets(6));
    expect(tester.takeException(), isNull);
    await tap(tester, find.text('QuickPrice items (6)'));
    await enterCustomer(tester);
    final save = find.byKey(const Key('save-sale'));
    await reveal(tester, save);
    expect(save.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
