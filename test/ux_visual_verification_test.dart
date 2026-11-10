import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/hyner_app.dart' as business;
import 'package:hyner/app/routing/app_router.dart';
import 'package:hyner/features/pricing/application/calculator_session.dart';
import 'package:hyner/features/pricing/application/simple_calculator.dart';
import 'package:hyner/features/pricing/data/preview_workspace.dart';
import 'package:hyner/features/pricing/domain/pricing_models.dart';
import 'package:hyner/features/pricing/domain/universal/rate_card.dart';
import 'package:hyner/features/pricing/presentation/simple_calculator_screen.dart';
import 'package:hyner/features/pricing/presentation/quickprice_screen.dart';
import 'package:hyner/features/pricing/presentation/pricing_widgets.dart';
import 'package:hyner/features/customers/domain/customer.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/settings/domain/payment_settings.dart';
import 'package:hyner/features/inventory/domain/product.dart';

import 'business/support/fakes.dart';
import 'business/support/inventory_fakes.dart';
import 'business/support/sales_fakes.dart';
import 'support/setup_fixture.dart' as f;

void main() {
  testWidgets(
    'render simplified setup, calculator, business screens and bill PDF',
    (tester) async {
      final output = Directory('build/verification/ux-0.5.0')
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
      const captureKey = ValueKey('capture-ux');
      Future<void> image(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(captureKey),
        );
        await tester.runAsync(() async {
          final bitmap = await boundary.toImage(pixelRatio: 1);
          final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          await File('${output.path}/$name.png')
              .writeAsBytes(data!.buffer.asUint8List());
          bitmap.dispose();
        });
      }

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final workspace = createPreviewWorkspace();
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: hynerTheme(Brightness.light),
            home: SimpleCalculatorScreen(workspace: workspace),
          ),
        ),
      );
      await image('simple-setup');
      await tester.pumpWidget(const SizedBox());
      final setup = quickProduct('doors', name: 'Basic flush door');
      setup.rows('rates').first['amount'] = '150';
      final product = setup.compile(workspace.businessId, f.currency);
      await workspace.repository.createProfile(
        'doors',
        UniversalRateCardDraft(
          name: 'Doors',
          currency: f.currency,
          industryTemplate: 'doors',
          categories: [PricingCategory(id: product.categoryId, name: 'Doors')],
          products: [product],
        ),
      );
      await workspace.values.approve(product.rule.tax);
      final published = await workspace.repository.publish(
        'doors',
        expectedRevision: 1,
        effectiveAt: DateTime.now().toUtc(),
      );
      final session = CalculatorSession()
        ..select(published.card.products.single);
      session.change('height', 'text', '84');
      session.change('width', 'text', '36');
      session.changeQuantity('2');
      await workspace.values.write('calculator', {
        ...session.toJson(),
        'profileId': 'doors',
      });
      session.dispose();
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: hynerTheme(Brightness.light),
            home: QuickPriceScreen(workspace: workspace),
          ),
        ),
      );
      await image('calculator-390');
      await tester.pumpWidget(const SizedBox());
      tester.view.physicalSize = const Size(320, 740);
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: hynerTheme(Brightness.dark),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.7)),
              child: child!,
            ),
            home: QuickPriceScreen(workspace: workspace),
          ),
        ),
      );
      await image('calculator-dark-large-320');
      await tester.pumpWidget(const SizedBox());
      tester.view.physicalSize = const Size(390, 844);
      final auth = FakeAuth(user: testIdentity);
      final inventory = FakeInventory();
      final sales = FakeSales(inventory);
      final sale = Sale(
        id: 'BILL-EXAMPLE',
        createdAt: DateTime.utc(2026, 11, 9),
        draft: SaleDraft(
          currency: 'INR',
          customerId: 'ASHA-HARDWARE-919876543210-ABC123',
          customerName: 'Asha Hardware',
          customerPhone: '+91 98765 43210',
          customerAddress: '42 Market Road, Chennai',
          initialPaymentMinor: 0,
          lines: [
            SaleLine(
              sku: 'DOOR',
              name: 'Basic flush door',
              unitPriceMinor: 315025,
              quantity: 2,
              parameters: const [
                ProductParameter(name: 'Size', value: '84 x 36 in'),
              ],
            ),
          ],
        ),
      );
      sales.sales(testIdentity.uid)[sale.id] = sale;
      final dependencies = connectedTestDependencies(
        auth,
        FakeProfiles(),
        inventory: inventory,
        sales: sales,
      );
      await dependencies.customers.save(
        testIdentity.uid,
        const CustomerDraft(
          name: 'Asha Hardware',
          phone: '+91 98765 43210',
          address: '42 Market Road, Chennai',
        ),
        id: sale.draft.customerId,
      );
      await dependencies.paymentSettings.save(
        testIdentity.uid,
        const PaymentSettings(
          merchantName: 'Hyner Hardware',
          businessAddress: 'Main Road, Chennai',
          businessPhone: '9876543210',
          footerText: 'Thank you for your business.',
        ),
      );
      final container = ProviderContainer(
        overrides: [dependenciesProvider.overrideWithValue(dependencies)],
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: UncontrolledProviderScope(
            container: container,
            child: const business.HynerApp(),
          ),
        ),
      );
      await image('dashboard-390');
      container.read(routerProvider).go('/sales/${sale.id}');
      await image('saved-bill-actions');
      container.read(routerProvider).go('/bill-settings');
      await image('bill-appearance-390');
      final save = find.text('Save bill details');
      await tester.scrollUntilVisible(
        save,
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await image('bill-appearance-bottom-390');
      container.read(routerProvider).go('/customers/${sale.draft.customerId}');
      await image('customer-history-top-390');
      await tester.scrollUntilVisible(
        find.text('View bill'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await image('customer-history-products-390');
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await auth.close();
    },
    skip: !const bool.fromEnvironment('CAPTURE_UX_QA'),
  );
}
