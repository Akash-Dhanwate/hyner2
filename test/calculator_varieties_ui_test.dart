import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/pricing/application/simple_calculator.dart';
import 'package:hyner/features/pricing/data/preview_workspace.dart';
import 'package:hyner/features/pricing/presentation/pricing_widgets.dart';
import 'package:hyner/main.dart';

import 'calculator_ui_test.dart' show input;
import 'owner_setup_ui_test.dart' show field, reveal;

Finder customerRate() => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is ValueField && w.label.startsWith('Customer rate ('),
  ),
  matching: find.byType(TextField),
);

void main() {
  testWidgets(
    'owner creates varieties, negotiates a rate and keeps separate estimate items',
    (tester) async {
      tester.view.physicalSize = const Size(500, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fontDirectory = Platform.environment['HYNER_TEST_FONT_DIR'];
      if (const bool.fromEnvironment('CAPTURE_VARIETIES') &&
          fontDirectory != null) {
        await tester.runAsync(() async {
          for (final entry in {
            'Roboto': '$fontDirectory/Roboto-Regular.ttf',
            'Manrope': 'assets/fonts/Manrope.ttf',
            'MaterialIcons': '$fontDirectory/MaterialIcons-Regular.otf',
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
      final workspace = createPreviewWorkspace();
      final boundary = GlobalKey();
      Widget app() => RepaintBoundary(
        key: boundary,
        child: HynerApp(workspace: Future.value(workspace)),
      );
      Future<void> capture(String name) async {
        if (!const bool.fromEnvironment('CAPTURE_VARIETIES')) return;
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File('build/feature-varieties/$name.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create calculator'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Calculator name'), 'Door prices');
      await tester.enterText(field('Product name'), 'Door');
      await tester.enterText(field('Selling rate (INR / ft²)'), '150');
      await reveal(tester, find.text('Add variety'));
      await tester.tap(find.text('Add variety'));
      await tester.pumpAndSettle();
      expect(field('Product name'), findsOneWidget);
      await tester.enterText(field('Variety name').at(0), 'Flush');
      await tester.enterText(field('Variety name').at(1), 'Laminated');
      await tester.enterText(field('Selling rate (INR / ft²)').at(1), '175');
      await tester.pumpAndSettle();
      await capture('setup-varieties');
      await reveal(tester, find.text('Save and use calculator'));
      await tester.tap(find.text('Save and use calculator'));
      await tester.pumpAndSettle();
      final profile = (await workspace.profiles()).single;
      final card = (await workspace.repository.activeCard(
        profile.id,
        at: DateTime.now(),
      ))!;
      expect(simpleVarieties(card.card.products.single).map((v) => v['name']), [
        'Flush',
        'Laminated',
      ]);
      final metadata = (await workspace.values.read(
        'setup_${profile.id}_${card.card.products.single.id}',
      ))!;
      expect(
        (metadata['fields'] as List).any((f) => f['id'] == simpleVarietyField),
        isTrue,
      );
      await tester.enterText(input('height'), '84');
      await tester.enterText(input('width'), '36');
      await tester.pumpAndSettle();
      expect(find.text('₹3,150.00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('input-quickprice_variety')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Laminated').last);
      await tester.pumpAndSettle();
      expect(find.text('₹3,675.00'), findsOneWidget);
      await reveal(tester, customerRate());
      await tester.enterText(customerRate(), '155');
      await tester.pumpAndSettle();
      expect(find.text('₹3,255.00'), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-to-estimate')));
      await tester.pumpAndSettle();
      // Switching the variety does not carry the negotiated rate to another type.
      await reveal(
        tester,
        find.byKey(const ValueKey('input-quickprice_variety')),
      );
      await tester.tap(find.byKey(const ValueKey('input-quickprice_variety')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flush').last);
      await tester.pumpAndSettle();
      expect(find.text('₹3,150.00'), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-to-estimate')));
      await tester.pumpAndSettle();
      final estimate = (await workspace.values.read('estimate'))!;
      expect((estimate['lines'] as List), hasLength(2));
      final items = estimate['lines'] as List;
      expect(items[0]['calculatorState']['baseRateOverride'], '155');
      expect(
        items[0]['calculatorState']['entries'][simpleVarietyField]['choice'],
        'Laminated',
      );
      expect(items[1]['calculatorState']['baseRateOverride'], isNull);
      expect(
        items[1]['calculatorState']['entries'][simpleVarietyField]['choice'],
        'Flush',
      );
      // Editing saved rates reconstructs varieties from the published rule.
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit selling rates'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Variety name').at(0)).controller!.text,
        'Flush',
      );
      expect(
        tester.widget<TextField>(field('Variety name').at(1)).controller!.text,
        'Laminated',
      );
      await tester.enterText(field('Selling rate (INR / ft²)').at(1), '180');
      await reveal(tester, find.text('Save and use calculator'));
      await tester.tap(find.text('Save and use calculator'));
      await tester.pumpAndSettle();
      expect(
        (await workspace.repository.readVersion(
          profile.id,
          1,
        )).card.products.single.rule.rateLookup.rates.last.amount.toString(),
        '175',
      );
      // New publication does not rewrite already captured customer quotes.
      final stillSaved = (await workspace.values.read('estimate'))!;
      expect(stillSaved['lines'], estimate['lines']);
      tester.view.physicalSize = const Size(320, 740);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await capture('calculator-varieties');
    },
  );
}
