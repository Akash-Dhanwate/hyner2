import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/hyner_app.dart';
import 'package:hyner/app/routing/app_router.dart';
import 'package:hyner/features/auth/presentation/session_controller.dart';
import 'package:hyner/features/settings/domain/payment_settings.dart';
import 'package:hyner/features/settings/presentation/settings_screen.dart';
import 'package:hyner/features/settings/presentation/settings_image_helper.dart';

import 'support/fakes.dart';

const _pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAeklEQVR4nO3QoQ3EMADA'
    'wKzxk3SX3589flLSbhAWXaoaGFqyPD7H95rx+59Tnu4PHaD9BugA7TdAB2i/ATpA+2P'
    '3wNV+A3SA9hugA7TfAB2g/QbsHrjab4AO0H4DdID2G6ADtN+A3QNX+w3QAdpvgA7QfgN'
    '0gPZfP+AGMSEJS8b9bscAAAAASUVORK5CYII=';

const _branding = PaymentSettings(
  upiId: 'shop@bank',
  merchantName: 'Asha Store',
  businessPhone: '9876543210',
  businessAddress: '12 Market Road',
  taxId: 'GST-123',
  billLayout: BillLayout.centered,
  logoBase64: _pixel,
  signatureBase64: _pixel,
  headerFontSize: 24,
  footerText: 'Visit again.',
  fontColors: {
    BillTextSection.businessName: 0xc62828,
    BillTextSection.items: 0x000000,
  },
);

class _SettingsRepository extends MemoryPaymentSettings {
  Completer<PaymentSettings>? nextRead;
  final savedUids = <String>[];

  @override
  Future<PaymentSettings> read(String uid) {
    final pending = nextRead;
    nextRead = null;
    return pending?.future ?? super.read(uid);
  }

  @override
  Future<void> save(String uid, PaymentSettings settings) async {
    savedUids.add(uid);
    await super.save(uid, settings);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAuth auth;
  late _SettingsRepository repository;
  late ProviderContainer container;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('hyner/notifications'),
          (_) async => false,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('hyner/notifications'),
          null,
        );
  });

  Future<void> mount(
    WidgetTester tester, {
    String path = '/bill-settings',
    PaymentSettings initial = _branding,
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    auth = FakeAuth(user: testIdentity);
    repository = _SettingsRepository()..values[testIdentity.uid] = initial;
    final base = connectedTestDependencies(auth, FakeProfiles());
    container = ProviderContainer(
      overrides: [
        dependenciesProvider.overrideWithValue(
          AppDependencies(
            auth: base.auth,
            profiles: base.profiles,
            inventory: base.inventory,
            sales: base.sales,
            customers: base.customers,
            paymentSettings: repository,
            purchases: base.purchases,
            reports: base.reports,
            appearance: base.appearance,
            config: base.config,
          ),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await auth.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HynerApp()),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go(path);
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    // An active field can schedule its own scroll after ensureVisible, pulling
    // the save button offscreen again. Finish that work before scrolling.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
          of: find.byType(CustomScrollView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    if (finder.evaluate().isEmpty) {
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          finder,
          180,
          scrollable: scrollable,
          maxScrolls: 80,
        );
      }
    }
    // Lazy slivers may revise their scroll extent after the first layout.
    for (var attempt = 0; attempt < 3; attempt++) {
      await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
      await tester.pumpAndSettle();
      if (finder.hitTestable().evaluate().isNotEmpty) break;
    }
    expect(finder.hitTestable(), findsOneWidget);
  }

  test('bill appearance requires an authenticated synchronized account', () {
    for (final status in [
      SessionStatus.loading,
      SessionStatus.signedOut,
      SessionStatus.signingIn,
      SessionStatus.synchronizing,
      SessionStatus.profileError,
    ]) {
      expect(
        sessionRedirect(SessionState(status), '/bill-settings'),
        isNotNull,
      );
    }
    expect(
      sessionRedirect(
        const SessionState(SessionStatus.signedIn),
        '/bill-settings',
      ),
      '/welcome',
    );
    expect(
      sessionRedirect(
        SessionState(SessionStatus.signedIn, profile: testProfile()),
        '/bill-settings',
      ),
      isNull,
    );
  });

  testWidgets('business name persists without configuring UPI', (tester) async {
    await mount(tester, initial: const PaymentSettings());
    await tester.enterText(field('Business name'), 'Independent Business');
    await reveal(tester, find.text('Save bill details'));
    await tester.tap(find.text('Save bill details'));
    await tester.pumpAndSettle();
    expect(
      repository.values[testIdentity.uid]!.merchantName,
      'Independent Business',
    );
    expect(repository.values[testIdentity.uid]!.upiId, isEmpty);

    container.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    expect(field('Business name'), findsNothing);
    expect(field('Business name shown in UPI app'), findsNothing);
    await reveal(tester, find.text('Bill appearance'));
    await tester.tap(find.text('Bill appearance'));
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, '/bill-settings');
    expect(
      tester.widget<TextField>(field('Business name')).controller!.text,
      'Independent Business',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('UPI save preserves branding changed after form load', (
    tester,
  ) async {
    await mount(tester, path: '/settings', initial: const PaymentSettings());
    // Simulate a branding save while an older UPI form remains mounted.
    repository.values[testIdentity.uid] = _branding;
    await reveal(tester, field('Your UPI ID'));
    await tester.enterText(field('Your UPI ID'), 'newshop@bank');
    await reveal(tester, find.text('Save UPI details'));
    await tester.tap(find.text('Save UPI details'));
    await tester.pumpAndSettle();
    final saved = repository.values[testIdentity.uid]!;
    expect(saved.upiId, 'newshop@bank');
    expect(saved.merchantName, _branding.merchantName);
    expect(saved.businessPhone, _branding.businessPhone);
    expect(saved.businessAddress, _branding.businessAddress);
    expect(saved.taxId, _branding.taxId);
    expect(saved.billLayout, _branding.billLayout);
    expect(saved.logoBase64, _branding.logoBase64);
    expect(saved.signatureBase64, _branding.signatureBase64);
    expect(saved.headerFontSize, _branding.headerFontSize);
    expect(saved.footerText, _branding.footerText);
    expect(saved.fontColors, _branding.fontColors);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'font presets and custom colours save independently and reject invalid input',
    (tester) async {
      await mount(tester);
      await reveal(tester, find.text('Typography and colours'));
      await tester.tap(find.text('Typography and colours'));
      await tester.pumpAndSettle();
      final palette = find.byTooltip('Choose Business name colour');
      await reveal(tester, palette);
      await tester.tap(palette);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(field('Business name colour'))
            .controller!
            .text,
        '#1565C0',
      );
      await reveal(tester, field('Customer details colour'));
      await tester.enterText(field('Customer details colour'), '#FF00ZZ');
      await reveal(tester, find.text('Save bill details'));
      await tester.tap(find.text('Save bill details'));
      await tester.pumpAndSettle();
      expect(repository.savedUids, isEmpty);
      await reveal(tester, field('Customer details colour'));
      await tester.enterText(field('Customer details colour'), '#112233');
      await reveal(tester, find.text('Save bill details'));
      await tester.tap(find.text('Save bill details'));
      await tester.pumpAndSettle();
      final saved = repository.values[testIdentity.uid]!;
      expect(saved.fontColor(BillTextSection.businessName), 0x1565c0);
      expect(saved.fontColor(BillTextSection.customer), 0x112233);
      expect(saved.fontColor(BillTextSection.items), 0x000000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'branding preview keeps a stable image provider through unrelated form rebuilds',
    (tester) async {
      await mount(tester);
      Finder logo() => find.byWidgetPredicate(
        (widget) =>
            widget is Image && widget.semanticLabel == 'Shop logo preview',
      );
      await reveal(tester, logo());
      final original = tester.widget<Image>(logo()).image;
      await reveal(tester, find.text('Typography and colours'));
      await tester.tap(find.text('Typography and colours'));
      await tester.pumpAndSettle();
      await reveal(tester, field('Business name colour'));
      await tester.enterText(field('Business name colour'), '#112233');
      await tester.pumpAndSettle();
      await reveal(tester, logo());
      expect(identical(original, tester.widget<Image>(logo()).image), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loaded route fits 320dp with enlarged text and previews', (
    tester,
  ) async {
    await mount(tester, width: 320, scale: 1.8);
    expect(find.byType(BillAppearanceScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(field('Business name')).controller!.text,
      'Asha Store',
    );
    expect(find.textContaining('Only the Original'), findsNothing);
    await tester.tap(find.byTooltip('View Details').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Only the Original'), findsOneWidget);
    expect(find.textContaining('compact Duplicate'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await reveal(tester, find.text('Typography and colours'));
    await tester.tap(find.text('Typography and colours'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(DropdownButtonFormField<BillLayout>));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(DropdownButtonFormField<BillLayout>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Business details on the right').last);
    await tester.pumpAndSettle();
    await reveal(tester, find.bySemanticsLabel('Shop logo preview'));
    expect(tester.takeException(), isNull);
    await reveal(tester, find.bySemanticsLabel('Signature preview'));
    expect(tester.takeException(), isNull);
    await reveal(tester, find.text('Save bill details'));
    expect(tester.takeException(), isNull);
  });

  Future<void> expectPreparedPng(
    Uint8List source, {
    required int width,
    required int height,
  }) async {
    final prepared = await prepareSettingsImage(source);
    expect(prepared.length, lessThanOrEqualTo(maxSavedSettingsImageBytes));
    expect(prepared.take(8), orderedEquals([137, 80, 78, 71, 13, 10, 26, 10]));
    final codec = await ui.instantiateImageCodec(prepared);
    ui.Image? image;
    try {
      expect(codec.frameCount, 1);
      image = (await codec.getNextFrame()).image;
      expect(image.width, width);
      expect(image.height, height);
    } finally {
      image?.dispose();
      codec.dispose();
    }
  }

  testWidgets('prepareSettingsImage accepts PNG without upscaling', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await expectPreparedPng(base64Decode(_pixel), width: 64, height: 32);
    });
  });

  testWidgets(
    'prepareSettingsImage bounds dimensions and preserves aspect ratio',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder)
            .drawColor(const ui.Color(0xff6952d9), ui.BlendMode.src);
        final picture = recorder.endRecording();
        ui.Image? source;
        late Uint8List bytes;
        try {
          source = await picture.toImage(2048, 1024);
          final data = await source.toByteData(format: ui.ImageByteFormat.png);
          expect(data, isNotNull);
          bytes = data!.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        } finally {
          source?.dispose();
          picture.dispose();
        }
        await expectPreparedPng(bytes, width: 1024, height: 512);
      });
    },
  );

  testWidgets('prepareSettingsImage rejects corrupt and unsupported data', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final bytes in [
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
        Uint8List.fromList([255, 216, 255, 0, 0]),
        Uint8List.fromList('not an image'.codeUnits),
        Uint8List(0),
        Uint8List(maxSettingsImageBytes + 1),
      ]) {
        await expectLater(
          prepareSettingsImage(bytes),
          throwsA(isA<FormatException>()),
        );
      }
    });
  });

  for (final path in ['/bill-settings', '/settings']) {
    testWidgets('$path does not save after account changes during read', (
      tester,
    ) async {
      await mount(tester, path: path);
      final saveLabel = path == '/bill-settings'
          ? 'Save bill details'
          : 'Save UPI details';
      await reveal(tester, find.text(saveLabel));
      final pending = Completer<PaymentSettings>();
      repository.nextRead = pending;
      await tester.tap(find.text(saveLabel));
      await tester.pump();
      auth.changeAccount(null);
      await tester.pumpAndSettle();
      pending.complete(_branding);
      await tester.pumpAndSettle();
      expect(repository.savedUids, isEmpty);
      expect(container.read(routerProvider).state.uri.path, '/welcome');
      expect(tester.takeException(), isNull);
    });
  }
}
