import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/pricing/application/calculator_session.dart';
import 'package:hyner/features/pricing/application/workspace.dart';
import 'package:hyner/features/pricing/presentation/pricing_widgets.dart';
import 'package:hyner/features/pricing/presentation/product_setup_screen.dart';
import 'package:hyner/features/pricing/presentation/quickprice_screen.dart';

import 'calculator_ui_test.dart' show configuredWorkspace;
import 'support/setup_fixture.dart' as f;

void main() {
  testWidgets(
    'capture actual Flutter layouts and host category-switch timings',
    (tester) async {
      final fontDir = Platform.environment['HYNER_TEST_FONT_DIR'];
      if (fontDir == null) {
        throw StateError(
          'Set HYNER_TEST_FONT_DIR to Flutter material_fonts for visual verification',
        );
      }
      await tester.runAsync(() async {
        final loader = FontLoader('Roboto');
        for (final name in [
          'Roboto-Regular.ttf',
          'Roboto-Bold.ttf',
          'Roboto-Black.ttf',
        ]) {
          loader.addFont(
            Future.value(
              ByteData.sublistView(await File('$fontDir/$name').readAsBytes()),
            ),
          );
        }
        await loader.load();
        final icons = FontLoader('MaterialIcons');
        icons.addFont(
          Future.value(
            ByteData.sublistView(
              await File('$fontDir/MaterialIcons-Regular.otf').readAsBytes(),
            ),
          ),
        );
        await icons.load();
      });
      final backing = await configuredWorkspace();
      final workspace = QuickPriceWorkspace(
        businessId: backing.businessId,
        repository: backing.repository,
        values: backing.values,
      );
      final card = (await workspace.repository.activeCard(
        'doors',
        at: DateTime.now(),
      ))!;
      final session = CalculatorSession()..select(card.card.products.first);
      session.change('height', 'text', '7');
      session.change('width', 'text', '3');
      session.changeQuantity('2');
      await workspace.values.write('calculator', {
        ...session.toJson(),
        'profileId': 'doors',
      });
      final timings = <int>[];
      for (var i = 0; i < 1050; i++) {
        session.select(card.card.products[i % 2]);
        if (i >= 50) timings.add(session.lastCalculationMicros);
      }
      timings.sort();
      final output = Directory('build/verification');
      output.createSync(recursive: true);
      File('${output.path}/category-switch-host.json').writeAsStringSync(
        jsonEncode({
          'platform': Platform.operatingSystem,
          'samples': timings.length,
          'scope': 'local calculation only; excludes Flutter rendering and device IO',
          'p50Microseconds': timings[499],
          'p95Microseconds': timings[949],
          'maxMicroseconds': timings.last,
        }),
      );
      session.dispose();
      const captureKey = ValueKey('capture');
      Future<void> capture(
        String name,
        Widget home,
        Size size,
        Brightness brightness,
        double scale,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: hynerTheme(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: home,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(captureKey),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${output.path}/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }

      await capture(
        'calculator-light-390',
        QuickPriceScreen(workspace: workspace),
        const Size(390, 844),
        Brightness.light,
        1,
      );
      await capture(
        'calculator-dark-320',
        QuickPriceScreen(workspace: workspace),
        const Size(320, 740),
        Brightness.dark,
        1,
      );
      await capture(
        'calculator-large-text-320',
        QuickPriceScreen(workspace: workspace),
        const Size(320, 740),
        Brightness.light,
        2,
      );
      final setup = f.setup('area', name: 'Basic flush door')..data['step'] = 1;
      await capture(
        'owner-pricing-390',
        ProductSetupScreen(
          workspace: workspace,
          setup: setup,
          storageKey: 'visual-setup',
          currency: f.currency,
          categories: [],
          onSave: (_, _) async {},
        ),
        const Size(390, 844),
        Brightness.light,
        1,
      );
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
    skip: !const bool.fromEnvironment('CAPTURE_SCREENSHOTS'),
  );
}
