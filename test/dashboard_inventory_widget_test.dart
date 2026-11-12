import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/hyner_app.dart';
import 'package:hyner/app/routing/app_router.dart';
import 'package:hyner/features/auth/data/device_access_repository.dart';
import 'package:hyner/features/customers/domain/customer.dart';
import 'package:hyner/features/customers/presentation/customers_controller.dart';
import 'package:hyner/features/dashboard/presentation/dashboard_screen.dart';
import 'package:hyner/features/inventory/presentation/inventory_controller.dart';
import 'package:hyner/features/inventory/domain/inventory_repository.dart';
import 'package:hyner/features/reports/domain/business_report.dart';
import 'package:hyner/features/reports/presentation/report_charts.dart';
import 'package:hyner/features/reports/presentation/reports_controller.dart';
import 'package:hyner/features/profile/domain/user_profile.dart';

import 'business/support/fakes.dart';
import 'business/support/inventory_fakes.dart';

BusinessReport _report() => BusinessReport(
  currency: 'INR',
  start: DateTime.utc(2026),
  end: DateTime.utc(2027),
  salesCount: 7,
  soldUnits: 12,
  paidSalesCount: 5,
  unpaidSalesCount: 2,
  revenueMinor: BigInt.from(123456),
  paidRevenueMinor: BigInt.from(100000),
  unpaidRevenueMinor: BigInt.from(23456),
  trackedRevenueMinor: BigInt.from(123456),
  costOfGoodsMinor: BigInt.from(50000),
  grossProfitMinor: BigInt.from(73456),
  uncostedSalesCount: 0,
  purchaseCount: 2,
  purchaseSpendMinor: BigInt.from(50000),
  returnValueMinor: BigInt.zero,
  inventoryValueMinor: BigInt.from(100000),
  topProducts: const [],
  activity: [
    ReportActivityPoint(
      periodStart: DateTime.utc(2026),
      label: 'Jan',
      revenueMinor: BigInt.from(123456),
      expenseMinor: BigInt.from(50000),
    ),
  ],
);

void main() {
  late FakeAuth auth;
  late FakeProfiles profiles;
  late FakeInventory inventory;
  late ProviderContainer container;

  Future<void> mount(
    WidgetTester tester, {
    String path = '/dashboard',
    double width = 390,
    double scale = 1,
    bool customerError = false,
  }) async {
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    auth = FakeAuth(user: testIdentity);
    profiles = FakeProfiles();
    inventory = FakeInventory();
    container = ProviderContainer(
      overrides: [
        dependenciesProvider.overrideWithValue(
          connectedTestDependencies(auth, profiles, inventory: inventory),
        ),
        businessReportProvider.overrideWith((ref, query) async => _report()),
        customersProvider.overrideWith((ref) async {
          if (customerError) throw StateError('Unable to read customers');
          return [
            Customer(
              id: 'customer',
              name: 'Test customer',
              phone: '',
              notes: '',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ];
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await auth.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HynerApp()),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go(path);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, text);
    await tester.pump();
  }

  for (final size in [(280.0, 1.0), (320.0, 2.5), (390.0, 3.0), (760.0, 1.0)]) {
    testWidgets(
      'dashboard metrics adapt without clipping at width ${size.$1} and text scale ${size.$2}',
      (tester) async {
        await mount(tester, width: size.$1, scale: size.$2);
        final metrics = [
          for (final name in ['customers', 'sales', 'revenue'])
            find.byKey(ValueKey('dashboard-metric-$name')),
        ];
        final boxes = metrics.map(tester.getRect).toList();
        final stack = size.$1 < 360 || size.$2 > 1.5;
        if (stack) {
          expect(boxes[0].bottom, lessThan(boxes[1].top));
          expect(boxes[1].bottom, lessThan(boxes[2].top));
        } else {
          expect(boxes[0].top, boxes[1].top);
          expect(boxes[1].top, boxes[2].top);
          expect(boxes[0].right, lessThan(boxes[1].left));
          expect(boxes[1].right, lessThan(boxes[2].left));
        }
        expect(boxes[0].width, closeTo(boxes[1].width, .01));
        expect(find.text('INR 1234.56'), findsOneWidget);
        final dashboard = find.byType(DashboardScreen);
        expect(
          find.descendant(of: dashboard, matching: find.text('BUSINESS TOOLS')),
          findsNothing,
        );
        expect(
          find.widgetWithText(FilledButton, 'Open QuickPrice'),
          findsOneWidget,
        );
        for (final label in ['Customers', 'Sales', 'Revenue']) {
          final text = tester.widget<Text>(
            find.descendant(of: dashboard, matching: find.text(label)),
          );
          expect(text.maxLines, isNull);
          expect(text.overflow, isNull);
        }
        final scroll = find
            .descendant(
              of: find.byType(CustomScrollView).last,
              matching: find.byType(Scrollable),
            )
            .first;
        expect(find.byType(ActivityBarChart), findsNothing);
        await tester.scrollUntilVisible(
          find.text('Activity details'),
          300,
          scrollable: scroll,
        );
        await tester.ensureVisible(find.text('Activity details'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Activity details'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byType(ActivityBarChart),
          300,
          scrollable: scroll,
        );
        expect(find.byType(ActivityBarChart), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byType(PaymentDonutChart),
          300,
          scrollable: scroll,
        );
        expect(find.byType(PaymentDonutChart), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'customer error does not turn valid sales and revenue into zero',
    (tester) async {
      await mount(tester, customerError: true);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('dashboard-value-customers')))
            .data,
        '—',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('dashboard-value-sales')))
            .data,
        '7',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('dashboard-value-revenue')))
            .data,
        'INR 1234.56',
      );
      expect(find.text('Customer count could not be loaded.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inventory filter is visible after navigating away and back, and can be cleared',
    (tester) async {
      await mount(tester, path: '/inventory');
      inventory.products(testIdentity.uid)['RICE'] = inventoryFixture(
        sku: 'RICE',
        name: 'Rice',
      );
      await container
          .read(inventoryProvider.notifier)
          .refresh(query: const InventoryQuery(search: 'Missing'));
      await tester.pumpAndSettle();
      expect(find.text('No matching products'), findsOneWidget);
      container.read(routerProvider).go('/dashboard');
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/inventory');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('inventory-search')))
            .controller!
            .text,
        'Missing',
      );
      await tap(tester, find.text('Show all active products'));
      expect(find.byKey(const Key('product-RICE')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('inventory-search')))
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new product is visible after saving from archived and filtered inventory',
    (tester) async {
      await mount(tester, path: '/inventory');
      await container
          .read(inventoryProvider.notifier)
          .refresh(query: const InventoryQuery(archived: true, search: 'Old'));
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('add-product')));
      await enter(tester, 'product-code', 'SAVED');
      await enter(tester, 'product-name', 'Saved product');
      await enter(tester, 'product-price', '12.50');
      await tap(tester, find.byKey(const Key('save-product')));
      expect(container.read(routerProvider).state.uri.path, '/inventory');
      expect(container.read(inventoryProvider).query.archived, isFalse);
      expect(container.read(inventoryProvider).query.search, isEmpty);
      expect(find.byKey(const Key('product-SAVED')), findsOneWidget);
      expect(inventory.products(testIdentity.uid)['SAVED']!.priceMinor, 1250);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('inventory-search')))
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'returning from add refreshes products saved elsewhere without resubmitting',
    (tester) async {
      await mount(tester, path: '/inventory');
      await tap(tester, find.byKey(const Key('add-product')));
      inventory.products(testIdentity.uid)['EXISTING'] = inventoryFixture(
        sku: 'EXISTING',
        name: 'Existing product',
      );
      container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('product-EXISTING')), findsOneWidget);
      expect(inventory.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'device empty guidance explains scope without showing account products',
    (tester) async {
      await mount(tester, path: '/inventory');
      inventory.products(testIdentity.uid)['ACCOUNT'] = inventoryFixture(
        sku: 'ACCOUNT',
        name: 'Account product',
      );
      await container.read(inventoryProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('product-ACCOUNT')), findsOneWidget);
      profiles.result = UserProfile(
        uid: deviceOwnerUid,
        email: '',
        displayName: 'Device owner',
        localOnly: true,
        createdAt: DateTime.utc(2026),
        lastLoginAt: DateTime.utc(2026),
      );
      auth.changeAccount(deviceIdentity);
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/inventory');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('product-ACCOUNT')), findsNothing);
      expect(
        find.text('Device workspace · Saved on this phone'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Account products are separate'),
        findsOneWidget,
      );
      expect(
        inventory.products(testIdentity.uid).containsKey('ACCOUNT'),
        isTrue,
      );
      expect(inventory.products(deviceOwnerUid), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
