import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/hyner_app.dart';
import 'package:hyner/app/routing/app_router.dart';
import 'package:hyner/features/auth/domain/auth_repository.dart';
import 'package:hyner/features/auth/data/device_access_repository.dart';
import 'package:hyner/features/auth/presentation/session_controller.dart';
import 'package:hyner/features/profile/domain/user_profile.dart';
import 'package:hyner/features/pricing/application/estimate_builder.dart';
import 'package:hyner/features/pricing/application/calculator_session.dart';
import 'package:hyner/features/pricing/presentation/estimate_screen.dart';
import 'package:hyner/features/pricing/presentation/quickprice_screen.dart';
import 'package:hyner/features/pricing/presentation/workspace_quickprice_screen.dart';

import 'business/support/fakes.dart';
import 'business/support/inventory_fakes.dart';
import 'business/support/sales_fakes.dart';
import 'calculator_ui_test.dart' show configuredWorkspace, input;

class _LocalEstimateProfiles extends FakeProfiles {
  @override
  Future<UserProfile> synchronize(AccountIdentity identity) async =>
      UserProfile(
        uid: identity.uid,
        email: identity.email,
        localOnly: identity.localOnly,
        createdAt: DateTime.utc(2026),
        lastLoginAt: DateTime.utc(2026),
      );
}

void main() {
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.pump();
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        160,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 100,
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

  testWidgets(
    'six independently calculated doors become one prefilled bill without inventory',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final workspace = await configuredWorkspace();
      final auth = FakeAuth(user: testIdentity);
      final inventory = FakeInventory();
      final sales = FakeSales(inventory);
      final container = ProviderContainer(
        overrides: [
          dependenciesProvider.overrideWithValue(
            connectedTestDependencies(
              auth,
              FakeProfiles(),
              inventory: inventory,
              sales: sales,
            ),
          ),
          pricingWorkspaceProvider(testIdentity.uid)
              .overrideWith((_) async => workspace),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await auth.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HynerApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/quickprice');
      await tester.pumpAndSettle();
      final rows = [
        ('Basic flush', '7', '3', '1'),
        ('Premium flush', '7', '2.5', '2'),
        ('Basic flush', '6.5', '3', '1'),
        ('Premium flush', '7', '3', '3'),
        ('Basic flush', '8', '4', '2'),
        ('Premium flush', '6', '2', '1'),
      ];
      for (final row in rows) {
        await tap(tester, find.text(row.$1));
        await reveal(tester, input('height'));
        await tester.enterText(input('height'), row.$2);
        await reveal(tester, input('width'));
        await tester.enterText(input('width'), row.$3);
        final quantity = find.descendant(
          of: find.byKey(const ValueKey('quantity')),
          matching: find.byType(TextField),
        );
        await reveal(tester, quantity);
        await tester.enterText(quantity, row.$4);
        await tap(tester, find.byKey(const Key('add-to-estimate')));
      }
      final estimate = await EstimateRepository(workspace).load();
      expect(estimate.lines, hasLength(6));
      expect(estimate.totalMinor, BigInt.from(3767500));
      expect(inventory.products(testIdentity.uid), isEmpty);
      expect(sales.writes, 0);
      await tap(tester, find.byTooltip('View estimate'));
      expect(find.byType(EstimateScreen), findsOneWidget);
      expect(find.text('₹37,675.00'), findsOneWidget);
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = call.arguments['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tap(tester, find.text('Copy estimate'));
      expect(copied, contains('Grand total: ₹37,675.00'));
      expect(copied, contains('6. Premium flush'));
      expect(copied, isNot(contains('businessId')));
      await tap(tester, find.byKey(const Key('estimate-checkout')));
      expect(find.text('QuickPrice items (6)'), findsOneWidget);
      expect(find.byKey(const Key('sale-price-TEST-1')), findsNothing);
      expect(sales.writes, 0);
      for (final entry in {
        'sale-customer-name': 'Asha Door Buyer',
        'sale-customer-phone': '9876543210',
        'sale-customer-address': '42 Market Road',
      }.entries) {
        final field = find.byKey(Key(entry.key));
        await reveal(tester, field);
        await tester.enterText(field, entry.value);
      }
      await tap(tester, find.byKey(const Key('save-sale')));
      final saved = sales.sales(testIdentity.uid)[estimate.operationId]!;
      expect(saved.draft.lines, hasLength(6));
      expect(saved.draft.totalMinor, estimate.totalMinor.toInt());
      expect(saved.draft.customerName, 'Asha Door Buyer');
      expect(
        saved.draft.lines.map((line) => line.pricing!.snapshotJson),
        estimate.lines.map((line) => line.pricing.snapshotJson),
      );
      expect(saved.draft.lines.every((line) => !line.stockTracked), isTrue);
      expect(inventory.products(testIdentity.uid), isEmpty);
      expect(sales.writes, 1);
      expect(
        (await EstimateRepository(workspace).load()).convertedSaleId,
        estimate.operationId,
      );
      // Re-entering the handoff opens the saved bill, without another invoice.
      container.read(routerProvider).go('/sales/quickprice/${estimate.id}');
      await tester.pumpAndSettle();
      expect(sales.writes, 1);
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/sales/${estimate.operationId}',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a public estimate can enter local checkout without a Firebase account',
    (tester) async {
      final workspace = await configuredWorkspace();
      final product = (await workspace.repository.activeCard(
        'doors',
        at: DateTime.now(),
      ))!.card.products.first;
      final calculator = CalculatorSession()..select(product);
      calculator.change('height', 'text', '7');
      calculator.change('width', 'text', '3');
      final estimate = QuickPriceEstimate.empty(
        workspace.businessId,
      ).append(EstimateLine.capture(session: calculator, profileId: 'doors'));
      calculator.dispose();
      await EstimateRepository(workspace).save(estimate);
      final remote = FakeAuth();
      final remoteReady = Completer<AuthRepository>();
      final auth = await DeviceAccessRepository.open(
        remoteReady.future,
        readMode: () async => 'signedOut',
        saveMode: (_) async {},
      );
      final profiles = _LocalEstimateProfiles();
      final base = connectedTestDependencies(remote, profiles);
      final container = ProviderContainer(
        overrides: [
          dependenciesProvider.overrideWithValue(
            AppDependencies(
              auth: auth,
              profiles: profiles,
              inventory: base.inventory,
              sales: base.sales,
              customers: base.customers,
              paymentSettings: base.paymentSettings,
              purchases: base.purchases,
              reports: base.reports,
              appearance: base.appearance,
              config: base.config,
            ),
          ),
          pricingWorkspaceProvider(null).overrideWith((_) async => workspace),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await auth.close();
        remoteReady.complete(remote);
        await remote.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HynerApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/quickprice');
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('View estimate'));
      await reveal(tester, find.byKey(const Key('estimate-checkout')));
      await tester.tap(find.byKey(const Key('estimate-checkout')));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Create a bill on this device?'), findsOneWidget);
      await tester.tap(find.text('Use on this device'));
      await tester.pumpAndSettle();
      expect(container.read(sessionProvider).profile!.localOnly, isTrue);
      expect(remote.currentUser, isNull);
      expect(find.byKey(const Key('sale-customer-name')), findsOneWidget);
      expect(find.text('QuickPrice items (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'estimate stays usable at 320dp with enlarged text in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final workspace = await configuredWorkspace();
        final product = (await workspace.repository.activeCard(
          'doors',
          at: DateTime.now(),
        ))!.card.products.first;
        final session = CalculatorSession()..select(product);
        session.change('height', 'text', '7');
        session.change('width', 'text', '3');
        var estimate = QuickPriceEstimate.empty(workspace.businessId);
        for (var i = 0; i < 6; i++) {
          estimate = estimate.append(
            EstimateLine.capture(session: session, profileId: 'doors'),
          );
        }
        session.dispose();
        await EstimateRepository(workspace).save(estimate);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: EstimateScreen(
              estimate: estimate,
              repository: EstimateRepository(workspace),
              onCheckout: (_) async => null,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('estimate-checkout')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tap(tester, find.byKey(const Key('estimate-checkout')));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'editing, duplicating and removing preserves the other estimate rows',
    (tester) async {
      final workspace = await configuredWorkspace();
      await tester.pumpWidget(
        MaterialApp(home: QuickPriceScreen(workspace: workspace)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(input('height'), '7');
      await tester.enterText(input('width'), '3');
      await tap(tester, find.byKey(const Key('add-to-estimate')));
      await tap(tester, find.byTooltip('View estimate'));
      await tap(tester, find.byTooltip('Item options').first);
      await tap(tester, find.text('Duplicate item'));
      expect((await EstimateRepository(workspace).load()).lines, hasLength(2));
      await tap(tester, find.byTooltip('Item options').first);
      await tap(tester, find.text('Edit item'));
      expect(find.text('Update estimate item'), findsOneWidget);
      await reveal(tester, input('width'));
      await tester.enterText(input('width'), '2');
      await tap(tester, find.text('Update estimate item'));
      var estimate = await EstimateRepository(workspace).load();
      expect(estimate.lines.map((line) => line.pricing.totalMinor), [
        210000,
        315000,
      ]);
      await tap(tester, find.byTooltip('View estimate'));
      await tap(tester, find.byTooltip('Item options').first);
      await tap(tester, find.text('Remove item'));
      estimate = await EstimateRepository(workspace).load();
      expect(estimate.lines, hasLength(1));
      expect(estimate.totalMinor, BigInt.from(315000));
    },
  );
}
