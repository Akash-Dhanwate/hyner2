import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/app/bootstrap/app_dependencies.dart';
import 'package:hyner/app/routing/app_router.dart';
import 'package:hyner/app/hyner_app.dart' as business;
import 'package:hyner/features/auth/data/device_access_repository.dart';
import 'package:hyner/features/auth/domain/auth_repository.dart';
import 'package:hyner/features/auth/presentation/session_controller.dart';
import 'package:hyner/features/pricing/data/preview_workspace.dart';
import 'package:hyner/features/pricing/presentation/workspace_quickprice_screen.dart';
import 'package:hyner/features/pricing/presentation/rate_cards_screen.dart';
import 'package:hyner/features/pricing/presentation/simple_calculator_screen.dart';
import 'package:hyner/features/profile/domain/user_profile.dart';
import 'package:hyner/main.dart';

import 'support/fakes.dart';

class _DeviceProfiles extends FakeProfiles {
  @override
  Future<UserProfile> synchronize(AccountIdentity identity) async =>
      UserProfile(
        uid: identity.uid,
        email: identity.email,
        displayName: identity.displayName,
        localOnly: identity.localOnly,
        createdAt: DateTime.utc(2026),
        lastLoginAt: DateTime.utc(2026),
      );
}

void main() {
  testWidgets(
    'account changes discard the entire pricing editor and dialog stack',
    (tester) async {
      final auth = FakeAuth(user: testIdentity);
      final profiles = FakeProfiles();
      final container = ProviderContainer(
        overrides: [
          dependenciesProvider.overrideWithValue(
            connectedTestDependencies(auth, profiles),
          ),
          pricingWorkspaceProvider(testIdentity.uid)
              .overrideWith((_) async => createPreviewWorkspace()),
          pricingWorkspaceProvider('bob')
              .overrideWith((_) async => createPreviewWorkspace()),
          pricingWorkspaceProvider(null)
              .overrideWith((_) async => createPreviewWorkspace()),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const business.HynerApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/quickprice');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Manage rates'));
      await tester.pumpAndSettle();
      expect(find.byType(SimpleCalculatorScreen), findsOneWidget);
      // First-use setup opens a dialog inside the scoped navigator.
      expect(find.byType(SimpleCalculatorScreen), findsOneWidget);
      auth.changeAccount(null);
      await tester.pumpAndSettle();
      expect(find.byType(RateCardsScreen, skipOffstage: false), findsNothing);
      expect(
        find.byType(SimpleCalculatorScreen, skipOffstage: false),
        findsNothing,
      );
      expect(find.text('Set up your calculator'), findsOneWidget);
      profiles.result = UserProfile(
        uid: 'bob',
        email: 'bob@example.test',
        createdAt: DateTime.utc(2026),
        lastLoginAt: DateTime.utc(2026),
      );
      auth.changeAccount(
        const AccountIdentity(uid: 'bob', email: 'bob@example.test'),
      );
      await tester.pumpAndSettle();
      expect(container.read(sessionProvider).profile!.uid, 'bob');
      expect(find.byType(RateCardsScreen), findsNothing);
      await tester.tap(find.byTooltip('Manage rates'));
      await tester.pumpAndSettle();
      expect(find.byType(SimpleCalculatorScreen), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(SimpleCalculatorScreen), findsNothing);
      expect(find.byType(RateCardsScreen), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(RateCardsScreen), findsNothing);
      expect(find.text('Set up your calculator'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await auth.close();
    },
  );
  testWidgets(
    'combined launcher opens device register and QuickPrice while Firebase is pending',
    (tester) async {
      final remote = Completer<AuthRepository>();
      final auth = await DeviceAccessRepository.open(
        remote.future,
        readMode: () async => 'signedOut',
        saveMode: (_) async {},
      );
      final base = testDependencies(
        FakeAuth(),
        FakeProfiles(),
        configured: false,
      );
      final dependencies = AppDependencies(
        auth: auth,
        profiles: _DeviceProfiles(),
        inventory: base.inventory,
        sales: base.sales,
        customers: base.customers,
        paymentSettings: base.paymentSettings,
        purchases: base.purchases,
        reports: base.reports,
        appearance: base.appearance,
        config: base.config,
      );
      final workspace = createPreviewWorkspace();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dependenciesProvider.overrideWithValue(dependencies),
            pricingWorkspaceProvider(null).overrideWith((_) async => workspace),
          ],
          child: const business.HynerApp(),
        ),
      );
      await tester.pumpAndSettle();
      final deviceButton = find.byKey(const Key('use-device'));
      await tester.ensureVisible(deviceButton);
      await tester.tap(deviceButton);
      await tester.pumpAndSettle();
      expect(
        find.text('Device workspace · Saved on this phone'),
        findsOneWidget,
      );
      final element = tester.element(find.text('Hello, Device.'));
      final container = ProviderScope.containerOf(element);
      expect(container.read(sessionProvider).profile!.localOnly, isTrue);
      expect(remote.isCompleted, isFalse);
      await tester.tap(find.widgetWithText(FilledButton, 'Open QuickPrice'));
      await tester.pumpAndSettle();
      expect(find.text('Set up your calculator'), findsOneWidget);
      await tester.tap(find.byTooltip('About this workspace'));
      await tester.pumpAndSettle();
      expect(find.text('Firebase setup has not completed.'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inventory').last);
      await tester.pumpAndSettle();
      expect(find.text('No products yet'), findsOneWidget);
      for (final path in ['/sales', '/purchases', '/customers', '/reports']) {
        container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: path);
      }
      await container.read(sessionProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(container.read(sessionProvider).profile, isNull);
      expect(find.byKey(const Key('use-device')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await auth.close();
      final remoteAuth = FakeAuth();
      remote.complete(remoteAuth);
      await remoteAuth.close();
    },
  );

  testWidgets(
    'startup settings failure offers retry and does not invent an account',
    (tester) async {
      final pending = Completer<AppDependencies>();
      await tester.pumpWidget(HynerLauncher(dependencies: pending.future));
      pending.completeError(StateError('settings unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(
        find.textContaining('Your data has not been reset'),
        findsOneWidget,
      );
      expect(find.text('Hello, Device.'), findsNothing);
    },
  );
}
