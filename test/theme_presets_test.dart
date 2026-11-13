import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/hyner_app.dart';
import 'package:hyner/app/routing/app_router.dart';
import 'package:hyner/app/theme/app_theme.dart';
import 'package:hyner/app/theme/appearance_repository.dart';
import 'package:hyner/core/widgets/financial_amount.dart';
import 'package:hyner/features/reports/presentation/reports_controller.dart';
import 'package:hyner/features/sales/domain/sale.dart';
// The preferences plugin already depends on this package. Its test-only memory
// backend exercises the real async repository without adding a runtime package.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'business/support/fakes.dart';
import 'business/support/inventory_fakes.dart';
import 'business/support/sales_fakes.dart';
import 'support/design_fixture.dart';

double _contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final preset in ThemePreset.values) {
    for (final brightness in Brightness.values) {
      test(
        '${preset.label} ${brightness.name} provides readable text/actions/status and cached theme',
        () {
          final theme = HynerTheme.build(brightness, preset: preset);
          final c = theme.colorScheme;
          for (final pair in [
            (c.onSurface, c.surface),
            (c.onSurfaceVariant, c.surface),
            (c.primary, c.surface),
            (c.onPrimary, c.primary),
            (c.onPrimaryContainer, c.primaryContainer),
            (c.onSurface, c.surfaceContainerLow),
            (c.error, c.surface),
            (theme.extension<HynerStatusColors>()!.success, c.surface),
            (theme.extension<HynerStatusColors>()!.warning, c.surface),
          ]) {
            expect(_contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
          }
          expect(
            _contrast(c.outline, c.surfaceContainerLow),
            greaterThanOrEqualTo(3),
          );
          expect(
            identical(theme, HynerTheme.build(brightness, preset: preset)),
            true,
          );
        },
      );
    }
  }

  test('colour preset survives repository recreation independently of dark mode; unknown preset falls back', () async {
    final previous = SharedPreferencesAsyncPlatform.instance;
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'hyner.appearance': 'dark',
          'hyner.theme.preset': 'retired-theme',
        });
    final first = LocalAppearanceRepository();
    expect(await first.readPreset(), ThemePreset.sageGreen);
    expect(await first.read(), ThemeMode.dark);
    await first.writePreset(ThemePreset.warmCopper);
    final reopened = LocalAppearanceRepository();
    expect(await reopened.readPreset(), ThemePreset.warmCopper);
    expect(await reopened.read(), ThemeMode.dark);
    await reopened.write(ThemeMode.light);
    expect(
      await LocalAppearanceRepository().readPreset(),
      ThemePreset.warmCopper,
    );
  });

  late ProviderContainer container;
  late MemoryAppearance appearance;
  late FakeAuth auth;
  var reportLoads = 0;
  final boundary = GlobalKey();
  const capture = bool.fromEnvironment('CAPTURE_UI_POLISH');
  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    if (capture) {
      await tester.runAsync(() async {
        const fonts =
            '/Users/akash/develop/flutter/bin/cache/artifacts/material_fonts';
        for (final entry in {
          'Roboto': '$fonts/Roboto-Regular.ttf',
          'Manrope': 'assets/fonts/Manrope.ttf',
          'MaterialIcons': '$fonts/MaterialIcons-Regular.otf',
        }.entries) {
          await (FontLoader(entry.key)..addFont(
                Future.value(
                  ByteData.sublistView(await File(entry.value).readAsBytes()),
                ),
              ))
              .load();
        }
      });
    }
    auth = FakeAuth(user: testIdentity);
    appearance = MemoryAppearance();
    reportLoads = 0;
    container = ProviderContainer(
      overrides: [
        dependenciesProvider.overrideWithValue(
          connectedTestDependencies(
            auth,
            FakeProfiles(),
            appearance: appearance,
            inventory: FakeInventory(),
          ),
        ),
        businessReportProvider.overrideWith((ref, query) async {
          reportLoads++;
          return designReport();
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await auth.close();
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: UncontrolledProviderScope(
          container: container,
          child: const HynerApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        180,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView).last,
              matching: find.byType(Scrollable),
            )
            .first,
        maxScrolls: 60,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> picture(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull);
    if (!capture) return;
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/ui-polish/screens/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  testWidgets(
    'settings picks all four presets in light/dark without changing appearance or navigation',
    (tester) async {
      await mount(tester);
      final semantics = tester.ensureSemantics();
      try {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          await container.read(themeControllerProvider.notifier).select(mode);
          await tester.pumpAndSettle();
          for (final preset in ThemePreset.values) {
            final finder = find.byKey(ValueKey('theme-preset-${preset.name}'));
            await reveal(tester, finder);
            await tester.tap(finder);
            await tester.pumpAndSettle();
            expect(container.read(themePresetProvider), preset);
            expect(appearance.preset, preset);
            expect(container.read(themeControllerProvider), mode);
            expect(
              container
                  .read(routerProvider)
                  .routeInformationProvider
                  .value
                  .uri
                  .path,
              '/settings',
            );
            final node = tester.getSemantics(
              find.bySemanticsLabel('${preset.label} theme'),
            );
            expect(
              node.getSemanticsData().flagsCollection.isSelected,
              ui.Tristate.isTrue,
            );
            await reveal(tester, find.text('Theme'));
            await picture(tester, 'theme-${preset.name}-${mode.name}-390');
          }
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'failed preset save preserves current palette and can retry; business report cache is not reloaded by theme',
    (tester) async {
      await mount(tester);
      appearance.failWrites = true;
      final slate = find.byKey(const ValueKey('theme-preset-slateBlue'));
      await reveal(tester, slate);
      await tester.tap(slate);
      await tester.pumpAndSettle();
      expect(find.textContaining('Theme could not be saved'), findsOneWidget);
      expect(container.read(themePresetProvider), ThemePreset.sageGreen);
      appearance.failWrites = false;
      await tester.tap(slate);
      await tester.pumpAndSettle();
      expect(container.read(themePresetProvider), ThemePreset.slateBlue);
      container.read(routerProvider).go('/reports');
      await tester.pumpAndSettle();
      final loads = reportLoads;
      await container
          .read(themePresetProvider.notifier)
          .select(ThemePreset.mutedViolet);
      await tester.pumpAndSettle();
      expect(reportLoads, loads);
      expect(find.byKey(const Key('report-earnings')), findsOneWidget);
      await picture(tester, 'reports-mutedViolet-390');
    },
  );

  testWidgets(
    'inventory prices, bill editing cancellation and document actions remain accessible under alternate presets',
    (tester) async {
      await mount(tester);
      final deps = container.read(dependenciesProvider);
      final inventory = deps.inventory as FakeInventory;
      final sales = deps.sales as FakeSales;
      final product = inventoryFixture(
        name: 'Premium laminated door panel',
        quantity: 10,
        priceMinor: 123456789,
      );
      inventory.products(testIdentity.uid)[product.sku] = product;
      await sales.create(
        testIdentity.uid,
        'ui-bill',
        SaleDraft(
          currency: 'INR',
          customerName: 'Sample customer',
          customerPhone: '9876543210',
          lines: [SaleLine.fromProduct(product, 2)],
        ),
      );
      final saved = sales.sales(testIdentity.uid)['ui-bill']!;
      sales.sales(testIdentity.uid)['ui-bill'] = Sale(
        id: saved.id,
        draft: saved.draft,
        createdAt: DateTime.now(),
      );
      await container
          .read(themePresetProvider.notifier)
          .select(ThemePreset.slateBlue);
      container.read(routerProvider).go('/inventory/${product.sku}');
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Edit product'));
      await picture(tester, 'inventory-slateBlue-390');
      container.read(routerProvider).go('/sales/ui-bill');
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('edit-bill-contact')));
      await picture(tester, 'bill-slateBlue-390');
      await tester.tap(find.byKey(const Key('edit-bill-contact')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('bill-contact-name')),
        'Uncommitted change',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        sales.sales(testIdentity.uid)['ui-bill']!.draft.customerName,
        'Sample customer',
      );
      await container
          .read(themePresetProvider.notifier)
          .select(ThemePreset.warmCopper);
      await container
          .read(themeControllerProvider.notifier)
          .select(ThemeMode.dark);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('save-bill-pdf')));
      expect(find.text('WhatsApp PDF'), findsOneWidget);
      expect(find.text('Print original'), findsOneWidget);
      await picture(tester, 'bill-document-actions-copper-dark-390');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'theme picker and large financial values fit 320dp with 1.8x text in dark appearance',
    (tester) async {
      await mount(tester, width: 320, scale: 1.8);
      await container
          .read(themeControllerProvider.notifier)
          .select(ThemeMode.dark);
      for (final preset in ThemePreset.values) {
        final finder = find.byKey(ValueKey('theme-preset-${preset.name}'));
        await reveal(tester, finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await reveal(tester, find.text('Theme'));
      await picture(tester, 'settings-dark-large-320');
      container.read(routerProvider).go('/reports');
      await tester.pumpAndSettle();
      await picture(tester, 'reports-dark-large-320');
      await tester.pumpWidget(
        MaterialApp(
          theme: HynerTheme.build(
            Brightness.dark,
            preset: ThemePreset.warmCopper,
          ),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 272,
                child: FinancialAmount('INR 9,999,999,999.99', prominent: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('INR 9,999,999,999.99'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
