import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/images/image_editor_screen.dart';
import 'package:image/image.dart' as raster;

void main() {
  Uint8List source() {
    final image = raster.Image(width: 400, height: 200, numChannels: 4);
    raster.fillRect(
      image,
      x1: 0,
      y1: 0,
      x2: 199,
      y2: 199,
      color: raster.ColorRgba8(240, 30, 20, 255),
    );
    raster.fillRect(
      image,
      x1: 200,
      y1: 0,
      x2: 399,
      y2: 199,
      color: raster.ColorRgba8(20, 30, 240, 255),
    );
    return Uint8List.fromList(raster.encodePng(image));
  }

  Future<void> settleCodec(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      if (find.byKey(const Key('use-edited-image')).evaluate().isNotEmpty &&
          tester
                  .widget<FilledButton>(
                    find.byKey(const Key('use-edited-image')),
                  )
                  .onPressed !=
              null) {
        return;
      }
    }
    fail('Image editor did not finish decoding.');
  }

  testWidgets(
    'rotate and full-image crop export actual transformed pixels and dimensions',
    (tester) async {
      Future<Uint8List?>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => result = Navigator.push<Uint8List>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ImageEditorScreen(bytes: source(), title: 'Edit image'),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await settleCodec(tester);
      await tester.ensureVisible(find.byKey(const Key('rotate-image')));
      await tester.tap(find.byKey(const Key('rotate-image')));
      await settleCodec(tester);
      await tester.ensureVisible(find.text('Full image'));
      await tester.tap(find.text('Full image'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('use-edited-image')));
      await tester.runAsync(() async {
        tester
            .widget<FilledButton>(find.byKey(const Key('use-edited-image')))
            .onPressed!();
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final bytes = await result!;
        final image = raster.decodePng(bytes!)!;
        expect(image.width, 200);
        expect(image.height, 400);
        expect(image.getPixel(100, 40).r, greaterThan(200));
        expect(image.getPixel(100, 350).b, greaterThan(200));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('profile crop pans and zooms then returns a bounded square', (
    tester,
  ) async {
    Future<Uint8List?>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = Navigator.push<Uint8List>(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageEditorScreen(
                    bytes: source(),
                    title: 'Profile crop',
                    profile: true,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await settleCodec(tester);
    tester.widget<Slider>(find.byKey(const Key('image-zoom'))).onChanged!(2);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('image-crop-area'))),
    );
    for (var i = 0; i < 7; i++) {
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('use-edited-image')));
    await tester.runAsync(() async {
      tester
          .widget<FilledButton>(find.byKey(const Key('use-edited-image')))
          .onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final bytes = await result!;
      final image = raster.decodePng(bytes!)!;
      expect(image.width, image.height);
      expect(image.width, lessThanOrEqualTo(512));
      expect(
        image.getPixel(image.width ~/ 2, image.height ~/ 2).r,
        greaterThan(200),
      );
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      '320dp large-text ${brightness.name} signature editing is scrollable and cancellation returns no image',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.8;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        Future<Uint8List?>? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => result = Navigator.push<Uint8List>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImageEditorScreen(
                        bytes: source(),
                        title: 'Signature crop',
                        signature: true,
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await settleCodec(tester);
        await tester.ensureVisible(find.byKey(const Key('rotate-image')));
        await tester.tap(find.byKey(const Key('rotate-image')));
        await settleCodec(tester);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(await result, isNull);
      },
    );
  }
}
