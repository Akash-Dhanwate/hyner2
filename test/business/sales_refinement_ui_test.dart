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
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/sales/presentation/sales_controller.dart';

import '../support/design_fixture.dart';
import 'support/fakes.dart';
import 'support/inventory_fakes.dart';
import 'support/sales_fakes.dart';

void main() {
  late ProviderContainer container;
  late FakeSales sales;
  final boundary = GlobalKey();
  const capture = bool.fromEnvironment('CAPTURE_SALES_REFINEMENT');
  Future<void> mount(WidgetTester tester, {bool expired = false}) async {
    final fontDir = Platform.environment['HYNER_TEST_FONT_DIR'];
    if (capture && fontDir != null) {
      await tester.runAsync(() async {
        for (final entry in {
          'Roboto': '$fontDir/Roboto-Regular.ttf',
          'Manrope': 'assets/fonts/Manrope.ttf',
          'MaterialIcons': '$fontDir/MaterialIcons-Regular.otf',
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
    final auth = FakeAuth(user: testIdentity);
    final inventory = FakeInventory();
    sales = FakeSales(inventory);
    for (var i = 0; i < 5; i++) {
      sales.sales(testIdentity.uid)['recent-$i'] = Sale(
        id: 'recent-$i',
        createdAt: DateTime.now().subtract(Duration(days: expired ? 8 + i : i)),
        draft: SaleDraft(
          currency: 'INR',
          customerName: i == 4 ? 'Older Sudeep' : 'Customer $i',
          customerPhone: '987654321$i',
          lines: [
            SaleLine(
              sku: 'DOOR',
              name: 'Flush door',
              quantity: 1,
              unitPriceMinor: i == 4 ? 2500000 : 16500,
            ),
          ],
        ),
      );
    }
    container = ProviderContainer(
      overrides: [
        dependenciesProvider.overrideWithValue(
          connectedTestDependencies(
            auth,
            FakeProfiles(),
            inventory: inventory,
            sales: sales,
          ),
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
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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
    container.read(routerProvider).go('/sales');
    await tester.pumpAndSettle();
  }

  Future<void> picture(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (!capture) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/sales-refinement/after/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'product-first entry previews only three bills and searches beyond them',
    (tester) async {
      await mount(tester);
      expect(find.byKey(const Key('sale-customer-name')), findsNothing);
      expect(find.byKey(const Key('save-sale')), findsNothing);
      expect(find.byKey(const Key('sale-recent-0')), findsOneWidget);
      expect(find.byKey(const Key('sale-recent-2')), findsOneWidget);
      expect(find.byKey(const Key('sale-recent-3')), findsNothing);
      await picture(tester, 'sales-entry');
      await tester.enterText(
        find.byKey(const Key('recent-bill-search')),
        'Sudeep',
      );
      await tap(tester, find.byTooltip('Search saved bills'));
      expect(container.read(salesProvider).search, 'Sudeep');
      expect(container.read(routerProvider).state.uri.query, isEmpty);
      expect(find.text('Older Sudeep'), findsOneWidget);
      final tile = find.byKey(const Key('sale-recent-4'));
      expect(
        tester.getTopLeft(find.text('Older Sudeep')).dy,
        lessThan(
          tester
              .getTopLeft(
                find.descendant(of: tile, matching: find.text('INR 25000.00')),
              )
              .dy,
        ),
      );
      await picture(tester, 'saved-bill-search');
      await tester.enterText(find.byKey(const Key('bill-search')), '₹25,000');
      await tap(tester, find.byTooltip('Search bills'));
      expect(container.read(salesProvider).sales.single.id, 'recent-4');
      await tester.enterText(
        find.byKey(const Key('bill-search')),
        '9876543214',
      );
      await tap(tester, find.byTooltip('Search bills'));
      expect(container.read(salesProvider).sales.single.id, 'recent-4');
      expect(sales.writes, 0);
    },
  );
  testWidgets(
    'contact editor changes only contact and keeps bill money and reference',
    (tester) async {
      await mount(tester);
      container.read(routerProvider).go('/sales/recent-0');
      await tester.pumpAndSettle();
      final before = sales.sales(testIdentity.uid)['recent-0']!;
      expect(find.text('Customer 0'), findsOneWidget);
      expect(
        find.text('Set up UPI in Settings to show a QR code.'),
        findsNothing,
      );
      await picture(tester, 'bill-details');
      await tap(tester, find.byKey(const Key('edit-bill-contact')));
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        findsNWidgets(2),
      );
      await tester.enterText(
        find.byKey(const Key('bill-contact-name')),
        'Sudip Buyer',
      );
      await tester.enterText(
        find.byKey(const Key('bill-contact-phone')),
        '8765432109',
      );
      await picture(tester, 'edit-bill-customer');
      await tap(tester, find.byKey(const Key('save-bill-contact')));
      await tester.pumpAndSettle();
      final after = sales.sales(testIdentity.uid)['recent-0']!;
      expect(after.draft.customerPhone, '8765432109');
      final scroll = find
          .descendant(
            of: find.byType(CustomScrollView).last,
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(scroll).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Sudip Buyer'), findsOneWidget);
      expect(after.id, before.id);
      expect(after.createdAt, before.createdAt);
      expect(after.draft.lines, orderedEquals(before.draft.lines));
      expect(after.paidMinor, before.paidMinor);
      expect(after.draft.totalMinor, before.draft.totalMinor);
      expect(
        sales.sales(testIdentity.uid)['recent-1']!.draft.customerName,
        'Customer 1',
      );
    },
  );
  testWidgets(
    'expired bills remain readable with locked contacts and no edit action',
    (tester) async {
      await mount(tester, expired: true);
      container.read(routerProvider).go('/sales/recent-0');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bill-customer-heading')), findsOneWidget);
      expect(find.byKey(const Key('edit-bill-contact')), findsNothing);
      expect(find.byTooltip('View Contact edit window'), findsOneWidget);
      expect(find.textContaining('Customer details are locked'), findsNothing);
      await tap(tester, find.byTooltip('View Contact edit window'));
      expect(find.textContaining('seven days'), findsWidgets);
    },
  );
  testWidgets(
    'contact form remains reachable with small screen large text and keyboard',
    (tester) async {
      await mount(tester);
      tester.view.physicalSize = const Size(320, 740);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      await container
          .read(themeControllerProvider.notifier)
          .select(ThemeMode.dark);
      container.read(routerProvider).go('/sales/recent-0');
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('edit-bill-contact')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('bill-contact-phone')));
      await tester.enterText(
        find.byKey(const Key('bill-contact-phone')),
        '123',
      );
      await tap(tester, find.byKey(const Key('save-bill-contact')));
      expect(find.text('Enter a valid mobile number.'), findsOneWidget);
      await picture(tester, 'contact-dark-large-keyboard-320');
      await tap(tester, find.text('Cancel'));
      expect(find.byKey(const Key('bill-contact-phone')), findsNothing);
    },
  );
}
