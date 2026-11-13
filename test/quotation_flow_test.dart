import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/hyner_app.dart';
import 'package:hyner/app/routing/app_router.dart';
import 'package:hyner/features/pricing/application/estimate_builder.dart';
import 'package:hyner/features/pricing/presentation/estimate_screen.dart';
import 'package:hyner/features/pricing/presentation/workspace_quickprice_screen.dart';
import 'package:hyner/features/quotations/data/local_quotation_repository.dart';
import 'package:hyner/features/quotations/domain/quotation.dart';
import 'package:hyner/features/quotations/presentation/quotation_controller.dart';
import 'package:hyner/features/sales/data/bill_pdf_actions.dart';

import 'business/support/fakes.dart';
import 'business/support/inventory_fakes.dart';
import 'business/support/sales_fakes.dart';
import 'calculator_ui_test.dart' show configuredWorkspace;
import 'quotation_documents_test.dart' show quotationEstimate, pdfText;

class MemoryQuotations implements QuotationRepository {
  final values = <String, Quotation>{};
  int writes = 0;
  @override
  Future<void> save(String uid, Quotation quote) async {
    values.putIfAbsent('$uid/${quote.id}', () {
      writes++;
      return quote;
    });
  }

  @override
  Future<Quotation> get(String uid, String id) async => values['$uid/$id']!;
  @override
  Future<List<Map<String, Object?>>> list(
    String uid, {
    String? beforeTime,
    String? beforeId,
  }) async => [
    for (final e in values.entries)
      if (e.key.startsWith('$uid/')) e.value.toRow(),
  ];
}

void main() {
  Future<void> tap(WidgetTester tester, Finder finder) async {
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
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'ten estimate items become an independent customer quotation with PDF download, copy and targeted share',
    (tester) async {
      const capture = bool.fromEnvironment('CAPTURE_QUOTATION_UI');
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
      final boundary = GlobalKey();
      Future<void> picture(String name) async {
        ScaffoldMessenger.maybeOf(tester.element(find.byType(Scaffold).last))
            ?.removeCurrentSnackBar();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (!capture) return;
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/quotation-release/screens/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final workspace = await configuredWorkspace();
      final estimate = quotationEstimate(business: workspace.businessId);
      await EstimateRepository(workspace).save(estimate);
      final auth = FakeAuth(user: testIdentity);
      final inventory = FakeInventory();
      final sales = FakeSales(inventory);
      final quotes = MemoryQuotations();
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
          quotationRepositoryProvider.overrideWithValue(quotes),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await auth.close();
      });
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(BillPdfActions.channel, (call) async {
            calls.add(call);
            return call.method == 'savePdf'
                ? 'content://documents/quotation.pdf'
                : null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(BillPdfActions.channel, null),
      );
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
      container.read(routerProvider).go('/quickprice');
      await tester.pumpAndSettle();
      expect(find.text('Copy price'), findsNothing);
      await tap(tester, find.byTooltip('View estimate'));
      await tap(tester, find.byKey(const Key('estimate-quotation')));
      expect(find.byKey(const Key('quotation-customer-name')), findsOneWidget);
      await tap(tester, find.byKey(const Key('generate-quotation')));
      expect(find.text('Enter the customer name.'), findsOneWidget);
      expect(find.text('Enter a valid mobile number.'), findsOneWidget);
      expect(quotes.writes, 0);
      await tester.enterText(
        find.byKey(const Key('quotation-customer-name')),
        'Sudip Buyer',
      );
      await tester.enterText(
        find.byKey(const Key('quotation-customer-phone')),
        '9876543210',
      );
      await tester.enterText(
        find.byKey(const Key('quotation-customer-address')),
        'Market road',
      );
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Leave this quotation?'), findsOneWidget);
      await tap(tester, find.text('Stay'));
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('quotation-customer-name')),
            )
            .controller!
            .text,
        'Sudip Buyer',
      );
      expect(quotes.writes, 0);
      final formScroll = find
          .descendant(
            of: find.byType(CustomScrollView).last,
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(formScroll).position.jumpTo(0);
      await tester.pumpAndSettle();
      await picture('customer-quotation-form-390');
      await tap(tester, find.byKey(const Key('generate-quotation')));
      await picture('quotation-actions-390');
      expect(quotes.writes, 1);
      expect(
        quotes.values.values.single.draft.totalMinor,
        estimate.totalMinor.toInt(),
      );
      expect(quotes.values.values.single.draft.lines, hasLength(10));
      expect(sales.writes, 0);
      expect(inventory.products(testIdentity.uid), isEmpty);
      await tap(tester, find.byKey(const Key('quotation-download')));
      await tap(tester, find.byKey(const Key('quotation-copy')));
      await tap(tester, find.byKey(const Key('quotation-whatsapp')));
      expect(calls.map((c) => c.method), [
        'savePdf',
        'copyPdf',
        'shareWhatsApp',
      ]);
      expect(calls.last.arguments['phone'], '9876543210');
      expect(calls.last.arguments['filename'], startsWith('hyner-quotation-'));
      final text = pdfText(calls.last.arguments['bytes'] as Uint8List);
      expect(text, contains('QUOTATION'));
      expect(text, contains('Market road'));
      expect(text, isNot(contains('Balance due')));
      expect(quotes.writes, 1);
      final retained = await EstimateRepository(workspace).load();
      expect(retained.convertedSaleId, isNull);
      expect(retained.totalMinor, estimate.totalMinor);
      container.read(routerProvider).go('/quickprice');
      await tester.pumpAndSettle();
      if (find.byType(EstimateScreen).evaluate().isNotEmpty) {
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      await tap(tester, find.byTooltip('Saved quotations'));
      expect(find.text('Sudip Buyer'), findsOneWidget);
      await tap(tester, find.text('Sudip Buyer'));
      expect(find.byKey(const Key('quotation-download')), findsOneWidget);
      expect(tester.takeException(), isNull);
      container.read(routerProvider).go('/profile');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Edit profile'));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration?.labelText ?? '').contains('photo URL'),
        ),
        findsNothing,
      );
      await picture('profile-image-controls-390');
      container.read(routerProvider).go('/bill-settings');
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('pdf-template-ledger')));
      await picture('pdf-styles-390');
      tester.view.physicalSize = const Size(320, 740);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await container
          .read(themeControllerProvider.notifier)
          .select(ThemeMode.dark);
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('pdf-template-centered')));
      await picture('pdf-styles-dark-large-320');
    },
  );
}
