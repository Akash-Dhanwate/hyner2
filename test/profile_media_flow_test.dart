import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as raster;
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/hyner_app.dart';
import 'package:hyner/app/routing/app_router.dart';
import 'package:hyner/features/auth/presentation/session_controller.dart';

import 'business/support/fakes.dart';

class PhotoPicker extends FilePicker {
  PhotoPicker() {
    final image = raster.Image(width: 400, height: 200, numChannels: 4);
    raster.fill(image, color: raster.ColorRgba8(20, 60, 80, 255));
    bytes = Uint8List.fromList(raster.encodePng(image));
  }
  late Uint8List bytes;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(name: 'photo.png', size: bytes.length, bytes: bytes),
  ]);
}

void main() {
  setUpAll(() => FilePicker.platform = PhotoPicker());
  Future<void> tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      final scroll = find
          .descendant(
            of: find.byType(CustomScrollView).last,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        finder,
        150,
        scrollable: scroll,
        maxScrolls: 60,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> imageReady(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump();
      if (find.byKey(const Key('use-edited-image')).evaluate().isNotEmpty &&
          tester
                  .widget<FilledButton>(
                    find.byKey(const Key('use-edited-image')),
                  )
                  .onPressed !=
              null) {
        await tester.pumpAndSettle();
        return;
      }
    }
    fail('Image editing did not become ready.');
  }

  testWidgets(
    'profile and signature uploads require an approved crop, show previews and persist image pixels instead of visible paths',
    (tester) async {
      final previousPicker = FilePicker.platform;
      FilePicker.platform = PhotoPicker();
      addTearDown(() => FilePicker.platform = previousPicker);
      final directory = Directory.systemTemp.createTempSync(
        'hyner-photo-flow-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(paths, (_) async => directory.path);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(paths, null),
      );
      final auth = FakeAuth(user: testIdentity);
      final deps = connectedTestDependencies(auth, FakeProfiles());
      final container = ProviderContainer(
        overrides: [dependenciesProvider.overrideWithValue(deps)],
      );
      addTearDown(() async {
        container.dispose();
        await auth.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HynerApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/profile');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration?.labelText ?? '').contains('photo URL'),
        ),
        findsNothing,
      );
      await tap(tester, find.byKey(const Key('choose-profile-photo')));
      await imageReady(tester);
      expect(container.read(sessionProvider).profile!.photoUrl, isNull);
      await tester.ensureVisible(find.byKey(const Key('use-edited-image')));
      await tester.runAsync(() async {
        tester
            .widget<FilledButton>(find.byKey(const Key('use-edited-image')))
            .onPressed!();
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('New profile photo preview'),
        findsOneWidget,
      );
      final save = find.widgetWithText(FilledButton, 'Save profile');
      await tester.ensureVisible(save);
      await tester.runAsync(() async {
        tester.widget<FilledButton>(save).onPressed!();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final path = container.read(sessionProvider).profile!.photoUrl!;
      expect(path, contains('/profile-images/'));
      final photo = raster.decodePng(File(path).readAsBytesSync())!;
      expect(photo.width, photo.height);
      expect(photo.width, lessThanOrEqualTo(512));
      expect(find.textContaining('/profile-images/'), findsNothing);
      container.read(routerProvider).go('/bill-settings');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Logo and signature'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Add signature'));
      await imageReady(tester);
      await tester.ensureVisible(find.byKey(const Key('use-edited-image')));
      await tester.runAsync(() async {
        tester
            .widget<FilledButton>(find.byKey(const Key('use-edited-image')))
            .onPressed!();
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      await tap(tester, find.text('Save bill details'));
      await tester.pumpAndSettle();
      final settings = await deps.paymentSettings.read(testIdentity.uid);
      final signature = raster.decodePng(
        base64Decode(settings.signatureBase64),
      )!;
      expect(signature.width / signature.height, closeTo(2.6, .03));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'leaving the account while cropping removes the old photo editing route',
    (tester) async {
      final previousPicker = FilePicker.platform;
      FilePicker.platform = PhotoPicker();
      addTearDown(() => FilePicker.platform = previousPicker);
      final auth = FakeAuth(user: testIdentity);
      final container = ProviderContainer(
        overrides: [
          dependenciesProvider.overrideWithValue(
            connectedTestDependencies(auth, FakeProfiles()),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await auth.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HynerApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/profile');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('choose-profile-photo')));
      await imageReady(tester);
      auth.changeAccount(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('image-crop-area')), findsNothing);
      expect(find.byKey(const Key('use-edited-image')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
