import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hyner/features/onboarding/data/onboarding_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hyner/core/storage/business_database_provider.dart';
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/features/onboarding/presentation/first_time_user_guide_screen.dart';

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(sqfliteFfiInit);

  test('guide completion and steps are scoped by workspace', () async {
    final preferences = OnboardingPreferences(store: _MemoryPreferences());
    expect(await preferences.isComplete('shop-a'), isFalse);
    expect(await preferences.isStepComplete('shop-a', 'business'), isFalse);
    await preferences.setStepComplete('shop-a', 'business', true);
    await preferences.setComplete('shop-a');
    expect(await preferences.isStepComplete('shop-a', 'business'), isTrue);
    expect(await preferences.isComplete('shop-a'), isTrue);
    expect(await preferences.isComplete('shop-b'), isFalse);
  });

  test('only an empty workspace is offered first-time setup', () async {
    final folder = await Directory.systemTemp.createTemp('hyner-guide-test');
    final store = LocalBusinessDatabase(
      factory: databaseFactoryFfi,
      directory: folder.path,
    );
    final preferences = OnboardingPreferences(store: _MemoryPreferences());
    final container = ProviderContainer(
      overrides: [
        businessDatabaseProvider.overrideWithValue(store),
        onboardingPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await store.close();
      await folder.delete(recursive: true);
    });
    expect(
      await container.read(firstTimeGuideProvider('synthetic-shop').future),
      isTrue,
    );
    final db = await store.databaseFor('synthetic-shop');
    await db.insert('settings', {'key': 'business.name', 'value': 'Test Shop'});
    container.invalidate(firstTimeGuideProvider('synthetic-shop'));
    expect(
      await container.read(firstTimeGuideProvider('synthetic-shop').future),
      isFalse,
    );
  });

  testWidgets('first-time prompt can be dismissed to explore directly', (
    tester,
  ) async {
    const uid = 'guide-widget-shop';
    final preferences = OnboardingPreferences(store: _MemoryPreferences());
    final container = ProviderContainer(
      overrides: [
        onboardingPreferencesProvider.overrideWithValue(preferences),
        firstTimeGuideProvider(uid).overrideWith(
          (ref) async =>
              !await ref.watch(onboardingPreferencesProvider).isComplete(uid),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: FirstTimeUserGuidePrompt(uid: uid)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Hyner'), findsOneWidget);
    await tester.tap(find.text('Explore on my own'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Hyner'), findsNothing);
  });
}

class _MemoryPreferences implements OnboardingPreferenceStore {
  final values = <String, bool>{};

  @override
  Future<bool?> getBool(String key) async => values[key];

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
}
