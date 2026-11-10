import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/pricing/application/workspace.dart';
import 'package:hyner/features/pricing/data/preview_workspace.dart';
import 'package:hyner/features/pricing/domain/pricing_models.dart';
import 'package:hyner/features/pricing/domain/universal/rate_card.dart';
import 'package:hyner/features/pricing/presentation/pricing_widgets.dart';
import 'package:hyner/features/pricing/presentation/quickprice_screen.dart';

import 'support/setup_fixture.dart';

Future<QuickPriceWorkspace> configuredWorkspace() async {
  final workspace = createPreviewWorkspace();
  final products = [
    setup('area', name: 'Basic flush', rate: '150'),
    setup('area', name: 'Premium flush', rate: '200'),
  ].map((s) => s.compile(workspace.businessId, currency)).toList();
  await workspace.repository.createProfile(
    'doors',
    UniversalRateCardDraft(
      name: 'Door prices',
      currency: currency,
      categories: [
        for (final p in products)
          PricingCategory(id: p.categoryId, name: p.name),
      ],
      products: products,
    ),
  );
  for (final p in products) {
    await workspace.values.approve(p.rule.tax);
  }
  await workspace.repository.publish(
    'doors',
    expectedRevision: 1,
    effectiveAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
  );
  return workspace;
}

Finder input(String id) => find.descendant(
  of: find.byKey(ValueKey('input-$id')),
  matching: find.byType(TextField),
);

void main() {
  testWidgets(
    'seller switches products instantly and inputs survive reopening',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final workspace = await configuredWorkspace();
      Widget app() => MaterialApp(
        theme: hynerTheme(Brightness.light),
        home: QuickPriceScreen(workspace: workspace),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.enterText(input('height'), '7');
      await tester.enterText(input('width'), '3');
      await tester.tap(find.byTooltip('Increase quantity'));
      await tester.pumpAndSettle();
      expect(find.text('₹6,300.00'), findsOneWidget);
      await tester.tap(find.text('Premium flush'));
      await tester.pump();
      expect(find.text('₹8,400.00'), findsOneWidget);
      expect(tester.widget<TextField>(input('height')).controller!.text, '7');
      expect(tester.widget<TextField>(input('width')).controller!.text, '3');
      await tester.pumpAndSettle();
      final saved = await workspace.values.read('calculator');
      expect(saved!['quantity'], '2');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('₹8,400.00'), findsOneWidget);
      await tester.enterText(input('height'), '0');
      await tester.pump();
      expect(find.text('₹8,400.00'), findsNothing);
      final copy = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Copy price'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(copy.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('320 dp ${brightness.name} text scale $scale stays usable', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final workspace = await configuredWorkspace();
        final card = (await workspace.repository.activeCard(
          'doors',
          at: DateTime.now(),
        ))!;
        await workspace.values.write('calculator', {
          'schemaVersion': 1,
          'profileId': 'doors',
          'productId': card.card.products.first.id,
          'quantity': '2',
          'entries': {
            'height': {
              'text': '7',
              'unit': 'ft',
              'inches': '',
              'choice': null,
              'checked': false,
            },
            'width': {
              'text': '3',
              'unit': 'ft',
              'inches': '',
              'choice': null,
              'checked': false,
            },
          },
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: hynerTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: QuickPriceScreen(workspace: workspace),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('₹6,300.00'), findsOneWidget);
        expect(find.text('Copy price'), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
