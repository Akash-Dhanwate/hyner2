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
import 'package:hyner/features/reports/presentation/reports_controller.dart';

import 'business/support/fakes.dart';
import 'business/support/inventory_fakes.dart';
import 'support/design_fixture.dart';

void main() {
  testWidgets(
    'working screens keep mobile and desktop layout with reachable labelled actions',
    (tester) async {
      const capture = bool.fromEnvironment('CAPTURE_REDESIGN');
      final fontDir = Platform.environment['HYNER_TEST_FONT_DIR'];
      if (capture && fontDir != null) {
        await tester.runAsync(() async {
          for (final entry in {
            'Roboto': '$fontDir/Roboto-Regular.ttf',
            'Manrope': 'assets/fonts/Manrope.ttf',
            'MaterialIcons': '$fontDir/MaterialIcons-Regular.otf',
          }.entries) {
            final loader = FontLoader(entry.key)
              ..addFont(
                Future.value(
                  ByteData.sublistView(await File(entry.value).readAsBytes()),
                ),
              );
            await loader.load();
          }
        });
      }
      final auth = FakeAuth(user: testIdentity);
      final inventory = FakeInventory();
      inventory.products(testIdentity.uid)['DOOR'] = inventoryFixture(
        sku: 'DOOR',
        name: 'Flush door',
        priceMinor: 15000,
        quantity: 12,
      );
      final dependencies = connectedTestDependencies(
        auth,
        FakeProfiles(),
        inventory: inventory,
      );
      final container = ProviderContainer(
        overrides: [
          dependenciesProvider.overrideWithValue(dependencies),
          businessReportProvider.overrideWith(
            (ref, query) async => designReport(),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await auth.close();
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final boundary = GlobalKey();
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
      Future<void> picture(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: name);
        if (!capture) return;
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final bitmap = await render.toImage(pixelRatio: 1);
          final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          final output = File('build/ux-redesign/after/$name.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(data!.buffer.asUint8List());
          bitmap.dispose();
        });
      }

      await picture('home-filled-390');
      final semantics = tester.ensureSemantics();
      try {
        expect(tester, meetsGuideline(androidTapTargetGuideline));
        expect(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
      for (final route in {
        'inventory': '/inventory',
        'product-entry': '/inventory/add',
        'sales-entry': '/sales',
        'reports': '/reports',
        'settings': '/settings',
      }.entries) {
        container.read(routerProvider).go(route.value);
        await picture('${route.key}-390');
      }
      container.read(routerProvider).go('/dashboard');
      await tester.pumpAndSettle();
      await tester.tap(find.text('More'));
      await picture('more-390');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1024, 900);
      container.read(routerProvider).go('/dashboard');
      await picture('home-1024');
      container.read(routerProvider).go('/reports');
      await picture('reports-1024');
      await container
          .read(themeControllerProvider.notifier)
          .select(ThemeMode.dark);
      tester.view.physicalSize = const Size(320, 740);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      await picture('reports-dark-large-320');
      container.read(routerProvider).go('/inventory/add');
      await picture('product-entry-dark-large-320');
      expect(tester.takeException(), isNull);
    },
  );
}
