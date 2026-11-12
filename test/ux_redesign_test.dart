import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/hyner_app.dart';
import 'package:hyner/app/routing/app_router.dart';
import 'package:hyner/app/theme/app_theme.dart';
import 'package:hyner/core/widgets/workspace_components.dart';
import 'package:hyner/features/pricing/application/simple_calculator.dart';
import 'package:hyner/features/pricing/data/preview_workspace.dart';
import 'package:hyner/features/pricing/domain/pricing_models.dart';
import 'package:hyner/features/pricing/domain/exact.dart';
import 'package:hyner/features/pricing/domain/universal/rate_card.dart';
import 'package:hyner/features/pricing/presentation/pricing_widgets.dart';
import 'package:hyner/features/pricing/presentation/simple_calculator_screen.dart';
import 'package:hyner/features/reports/presentation/report_charts.dart';
import 'package:hyner/features/reports/presentation/reports_controller.dart';

import 'business/support/fakes.dart';
import 'business/support/inventory_fakes.dart';
import 'support/design_fixture.dart';

void main() {
  for (final brightness in Brightness.values) {
    test(
      'shared ${brightness.name} palette provides readable normal text and controls',
      () {
        final scheme = HynerTheme.build(brightness).colorScheme;
        double contrast(Color a, Color b) {
          final x = a.computeLuminance(), y = b.computeLuminance();
          return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
        }

        expect(
          contrast(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.primary, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.outline, scheme.surfaceContainerLow),
          greaterThanOrEqualTo(3),
        );
        expect(
          hynerTheme(brightness).colorScheme,
          HynerTheme.build(brightness).colorScheme,
        );
      },
    );
  }

  testWidgets(
    'optional controls preserve edits and reopen when validation fails',
    (tester) async {
      final controller = TextEditingController(text: '150');
      final error = ValueNotifier(false);
      addTearDown(controller.dispose);
      addTearDown(error.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: HynerTheme.build(Brightness.light),
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: error,
              builder: (context, invalid, _) => DisclosureSection(
                title: 'Options',
                revealError: invalid,
                children: [TextField(controller: controller)],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Options'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '155');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.text('Options'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      error.value = true;
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '155',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Back protects unsaved changes to an existing calculator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final workspace = createPreviewWorkspace();
    final setup = quickProduct('doors', name: 'Door');
    setup.rows('rates').first['amount'] = '150';
    final product = setup.compile(workspace.businessId, Currency('INR', 2));
    await workspace.repository.createProfile(
      'doors',
      UniversalRateCardDraft(
        name: 'Doors',
        currency: Currency('INR', 2),
        products: [product],
        categories: [PricingCategory(id: product.categoryId, name: 'Doors')],
      ),
    );
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: hynerTheme(Brightness.light),
        home: const Scaffold(body: Text('Home')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SimpleCalculatorScreen(workspace: workspace, profileId: 'doors'),
      ),
    );
    await tester.pumpAndSettle();
    final rate = find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is ValueField && w.label.startsWith('Selling rate'),
      ),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(rate);
    await tester.enterText(rate, '155');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard rate changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(rate).controller!.text, '155');
    expect(
      (await workspace.repository.readDraft('doors'))
          .card
          .products
          .single
          .rule
          .rateLookup
          .rates
          .single
          .amount
          .toString(),
      '150',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'inventory specifications are optional and keep input while folded',
    (tester) async {
      final auth = FakeAuth(user: testIdentity);
      final container = ProviderContainer(
        overrides: [
          dependenciesProvider.overrideWithValue(
            connectedTestDependencies(
              auth,
              FakeProfiles(),
              inventory: FakeInventory(),
            ),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await auth.close();
      });
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HynerApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/inventory/add');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('product-category')), findsNothing);
      expect(find.byKey(const Key('product-price')), findsOneWidget);
      final disclosure = find.text('Product specifications');
      await tester.ensureVisible(disclosure);
      await tester.pumpAndSettle();
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('product-category')),
        'Doors',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(disclosure);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('product-category')), findsNothing);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('product-category')))
            .controller!
            .text,
        'Doors',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'chart semantics communicate amounts without relying on bar colours',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: hynerTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ActivityBarChart(report: designReport()),
                  PaymentDonutChart(report: designReport()),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(
          RegExp('Revenue and expenses.*10 Nov: revenue INR 2100.00'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(
            'Payment status. Received INR 3150.00. Balance due INR 3150.00.',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    },
  );

  testWidgets('report scope and optional financial detail remain accessible', (
    tester,
  ) async {
    final auth = FakeAuth(user: testIdentity);
    final container = ProviderContainer(
      overrides: [
        dependenciesProvider.overrideWithValue(
          connectedTestDependencies(auth, FakeProfiles()),
        ),
        businessReportProvider.overrideWith(
          (ref, query) async => designReport(),
        ),
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
    container.read(routerProvider).go('/reports');
    await tester.pumpAndSettle();
    expect(find.text('Monthly highlights'), findsOneWidget);
    expect(find.text('Current inventory value'), findsNothing);
    await tester.ensureVisible(find.text('Profit and stock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profit and stock'));
    await tester.pumpAndSettle();
    expect(find.text('Current inventory value'), findsOneWidget);
    final scroll = find
        .descendant(
          of: find.byType(CustomScrollView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    final period = find.byWidgetPredicate(
      (w) => w is DropdownButtonFormField && w.decoration.labelText == 'Period',
    );
    await tester.ensureVisible(period);
    await tester.pumpAndSettle();
    await tester.tap(period);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    expect(find.text('Monthly highlights'), findsNothing);
    expect(find.text('Period highlights'), findsOneWidget);
    expect(find.text('Download report PDF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
