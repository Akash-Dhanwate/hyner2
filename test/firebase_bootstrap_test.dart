import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/firebase/firebase_bootstrap.dart';
import 'package:hyner/main.dart';
import 'package:hyner/features/pricing/data/preview_workspace.dart';

const configuredOptions = FirebaseOptions(
  apiKey: 'test-only',
  appId: FirebaseBootstrap.androidAppId,
  messagingSenderId: '746350362575',
  projectId: FirebaseBootstrap.projectId,
);

void main() {
  test(
    'accepts the registered Android configuration without a network probe',
    () async {
      var initializations = 0;
      final result = await FirebaseBootstrap.initialize(
        platform: TargetPlatform.android,
        isWeb: false,
        initializeSdk: () async {
          initializations++;
          return configuredOptions;
        },
      );
      expect(result, FirebaseSetupStatus.ready);
      expect(initializations, 1);
    },
  );

  for (final options in [
    configuredOptions.copyWith(projectId: 'another-project'),
    configuredOptions.copyWith(appId: 'another-app'),
  ]) {
    test(
      'rejects mismatched configuration ${options.projectId}/${options.appId}',
      () async {
        expect(
          await FirebaseBootstrap.initialize(
            platform: TargetPlatform.android,
            isWeb: false,
            initializeSdk: () async => options,
          ),
          FirebaseSetupStatus.unavailable,
        );
      },
    );
  }

  test('web never initializes with Android credentials', () async {
    expect(
      await FirebaseBootstrap.initialize(
        platform: TargetPlatform.android,
        isWeb: true,
        initializeSdk: () => throw StateError('must not initialize'),
      ),
      FirebaseSetupStatus.notConfigured,
    );
  });

  test('unconfigured native platforms do not call the SDK', () async {
    expect(
      await FirebaseBootstrap.initialize(
        platform: TargetPlatform.iOS,
        isWeb: false,
        initializeSdk: () => throw StateError('must not initialize'),
      ),
      FirebaseSetupStatus.notConfigured,
    );
  });

  test(
    'initialization failure is explicit without preventing local use',
    () async {
      expect(
        await FirebaseBootstrap.initialize(
          platform: TargetPlatform.android,
          isWeb: false,
          initializeSdk: () async => throw StateError('SDK unavailable'),
        ),
        FirebaseSetupStatus.unavailable,
      );
    },
  );

  test('initialization timeout does not wait indefinitely', () async {
    final pending = Completer<FirebaseOptions>();
    expect(
      await FirebaseBootstrap.initialize(
        platform: TargetPlatform.android,
        isWeb: false,
        initializeSdk: () => pending.future,
        timeout: Duration.zero,
      ),
      FirebaseSetupStatus.unavailable,
    );
    pending.complete(configuredOptions);
  });

  testWidgets('local workspace opens before SDK setup finishes', (
    tester,
  ) async {
    final pending = Completer<FirebaseSetupStatus>();
    await tester.pumpWidget(
      HynerApp(
        firebaseSetup: pending.future,
        workspace: Future.value(createPreviewWorkspace()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Create calculator'), findsOneWidget);
    pending.complete(FirebaseSetupStatus.ready);
    await tester.pump();
    expect(find.text('Create calculator'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('setup failure leaves local pricing available', (tester) async {
    await tester.pumpWidget(
      HynerApp(
        firebaseSetup: Future.value(FirebaseSetupStatus.unavailable),
        workspace: Future.value(createPreviewWorkspace()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Create calculator'), findsOneWidget);
    expect(find.textContaining('No selling rates'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
