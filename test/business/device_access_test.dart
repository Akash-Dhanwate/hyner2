import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/auth/data/device_access_repository.dart';
import 'package:hyner/features/auth/domain/auth_repository.dart';

import 'support/fakes.dart';

void main() {
  test('device access opens without waiting for account service and persists choice', () async {
    final remote = Completer<AuthRepository>();
    String? mode;
    final auth = await DeviceAccessRepository.open(
      remote.future,
      readMode: () async => mode,
      saveMode: (value) async => mode = value,
    );
    final states = <AccountIdentity?>[];
    final subscription = auth.authStateChanges().listen(states.add);
    await Future<void>.delayed(Duration.zero);
    expect(states, [null]);
    await auth.useDevice();
    expect(auth.currentUser!.localOnly, isTrue);
    expect(auth.currentUser!.email, isEmpty);
    expect(mode, 'device');
    await Future<void>.delayed(Duration.zero);
    expect(states.last!.uid, deviceOwnerUid);
    await subscription.cancel();
    await auth.close();
    remote.complete(FakeAuth());
    await (await remote.future as FakeAuth).close();
  });

  test('remote account events cannot overwrite a device workspace', () async {
    final remote = FakeAuth(user: testIdentity);
    final auth = await DeviceAccessRepository.open(
      Future.value(remote),
      readMode: () async => 'device',
      saveMode: (_) async {},
    );
    final subscription = auth.authStateChanges().listen((_) {});
    await Future<void>.delayed(Duration.zero);
    remote.changeAccount(testIdentity);
    await Future<void>.delayed(Duration.zero);
    expect(auth.currentUser!.uid, deviceOwnerUid);
    await auth.signOut();
    remote.changeAccount(testIdentity);
    await Future<void>.delayed(Duration.zero);
    expect(auth.currentUser, isNull);
    await auth.signInWithGoogle();
    expect(auth.currentUser!.uid, testIdentity.uid);
    expect(auth.currentUser!.localOnly, isFalse);
    await subscription.cancel();
    await auth.close();
    await remote.close();
  });

  test('explicit local mode survives restart and stays separate from signed-in identity', () async {
    final remote = FakeAuth(user: testIdentity);
    final auth = await DeviceAccessRepository.open(
      Future.value(remote),
      readMode: () async => 'device',
      saveMode: (_) async {},
    );
    expect(auth.currentUser!.uid, deviceOwnerUid);
    await auth.close();
    await remote.close();
  });
}
