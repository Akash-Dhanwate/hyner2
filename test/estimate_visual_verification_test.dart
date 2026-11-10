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
import 'package:hyner/features/pricing/application/calculator_session.dart';
import 'package:hyner/features/pricing/application/estimate_builder.dart';
import 'package:hyner/features/pricing/presentation/workspace_quickprice_screen.dart';
import 'package:hyner/features/sales/data/bill_pdf_service.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/settings/domain/payment_settings.dart';

import 'business/support/fakes.dart';
import 'business/support/inventory_fakes.dart';
import 'business/support/sales_fakes.dart';
import 'business/support/quickprice_sales_fixture.dart';
import 'calculator_ui_test.dart' show configuredWorkspace;

void main() {
  testWidgets(
    'render six-item estimate, prefilled checkout, and exact invoice PDFs',
    (tester) async {
      final output = Directory('build/verification/ux-0.6.0')
        ..createSync(recursive: true);
      final fontDir = Platform.environment['HYNER_TEST_FONT_DIR']!;
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
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const capture = ValueKey('estimate-qa-capture');
      Future<void> shot(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        await tester.runAsync(() async {
          final bitmap = await boundary.toImage(pixelRatio: 1);
          final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          await File('${output.path}/$name.png')
              .writeAsBytes(data!.buffer.asUint8List());
          bitmap.dispose();
        });
      }

      final workspace = await configuredWorkspace();
      final card = (await workspace.repository.activeCard(
        'doors',
        at: DateTime.now(),
      ))!;
      final calculator = CalculatorSession();
      var estimate = QuickPriceEstimate.empty(workspace.businessId);
      for (final row in [
        (0, '7', '3', '1'),
        (1, '7', '2.5', '2'),
        (0, '6.5', '3', '1'),
        (1, '7', '3', '3'),
        (0, '8', '4', '2'),
        (1, '6', '2', '1'),
      ]) {
        calculator.select(card.card.products[row.$1]);
        calculator.change('height', 'text', row.$2);
        calculator.change('width', 'text', row.$3);
        calculator.changeQuantity(row.$4);
        estimate = estimate.append(
          EstimateLine.capture(session: calculator, profileId: 'doors'),
        );
      }
      await workspace.values.write('calculator', {
        ...calculator.toJson(),
        'profileId': 'doors',
      });
      calculator.dispose();
      await EstimateRepository(workspace).save(estimate);
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
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: UncontrolledProviderScope(
            container: container,
            child: const HynerApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/quickprice');
      await shot('calculator-with-estimate-390');
      await tester.tap(find.byTooltip('View estimate'));
      await shot('estimate-six-items-390');
      await tester.drag(
        find.byType(ReorderableListView),
        const Offset(0, -350),
      );
      await shot('estimate-last-items-390');
      await tester.tap(find.byKey(const Key('estimate-checkout')));
      await shot('checkout-prefilled-390');
      container.read(routerProvider).go('/quickprice');
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(320, 740);
      tester.platformDispatcher.textScaleFactorTestValue = 1.7;
      await container
          .read(themeControllerProvider.notifier)
          .select(ThemeMode.dark);
      await tester.pumpAndSettle();
      await shot('estimate-dark-large-320');
      await tester.tap(find.byKey(const Key('estimate-checkout')));
      await shot('checkout-dark-large-320');

      const settings = PaymentSettings(
        merchantName: 'Hyner Hardware',
        businessAddress: 'Main Market Road, Pune',
        businessPhone: '9876543210',
        footerText: 'Thank you for your business.',
      );
      final bill = Sale(
        id: estimate.operationId,
        createdAt: DateTime.utc(2026, 11, 10),
        draft: SaleDraft(
          currency: 'INR',
          customerName: 'Asha Hardware',
          customerId: 'ASHA-HARDWARE-9876543210-ABC123',
          customerPhone: '9876543210',
          customerAddress: '42 Market Road, Pune',
          initialPaymentMinor: 0,
          lines: estimate.toCheckoutSeed(testIdentity.uid).lines,
        ),
      );
      for (final copy in BillCopy.values) {
        final bytes = await BillPdfService.build(
          sale: bill,
          settings: settings,
          copy: copy,
        );
        File('${output.path}/six-items-${copy.name}.pdf')
            .writeAsBytesSync(bytes);
      }
      final rounded = Sale(
        id: 'rounded-quote',
        createdAt: DateTime.utc(2026, 11, 10),
        draft: customSaleDraft([measuredSaleLine(0)]),
      );
      File('${output.path}/rounded-tax-original.pdf').writeAsBytesSync(
        await BillPdfService.build(sale: rounded, settings: settings),
      );
      expect(bill.draft.totalMinor, 3767500);
      expect(rounded.draft.totalMinor, 340);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await auth.close();
    },
    skip: !const bool.fromEnvironment('CAPTURE_ESTIMATE_QA'),
  );
}
