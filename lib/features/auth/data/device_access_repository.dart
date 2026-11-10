import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/auth_repository.dart';

const deviceOwnerUid = 'device-local-owner';
const deviceIdentity = AccountIdentity(
  uid: deviceOwnerUid,
  email: '',
  displayName: 'Device owner',
  localOnly: true,
);

/// A deliberate local workspace selection never claims a Firebase identity.
/// Remote startup and network failures cannot prevent opening device records.
class DeviceAccessRepository implements AuthRepository, DeviceAccess {
  DeviceAccessRepository._(this._remoteReady, this._saveMode, this._mode) {
    _attachRemote();
  }

  static Future<DeviceAccessRepository> open(
    Future<AuthRepository> remote, {
    Future<String?> Function()? readMode,
    Future<void> Function(String)? saveMode,
  }) async {
    final preferences = readMode == null || saveMode == null
        ? SharedPreferencesAsync()
        : null;
    final mode =
        await (readMode ??
            () => preferences!.getString('hyner.workspace.mode'))();
    return DeviceAccessRepository._(
      remote,
      saveMode ??
          (value) => preferences!.setString('hyner.workspace.mode', value),
      mode == 'device' || mode == 'signedOut' ? mode! : 'account',
    );
  }

  final Future<AuthRepository> _remoteReady;
  final Future<void> Function(String) _saveMode;
  final _changes = StreamController<AccountIdentity?>.broadcast(sync: true);
  String _mode;
  AuthRepository? _remote;
  StreamSubscription<AccountIdentity?>? _subscription;
  bool _closed = false;

  Future<void> _attachRemote() async {
    try {
      final remote = await _remoteReady;
      if (_closed) return;
      _remote = remote;
      _subscription = remote.authStateChanges().listen(
        (identity) {
          if (!_closed && _mode == 'account') _changes.add(identity);
        },
        onError: (Object error, StackTrace stack) {
          if (!_closed && _mode == 'account') _changes.addError(error, stack);
        },
      );
    } catch (error, stack) {
      if (!_closed && _mode == 'account') _changes.addError(error, stack);
    }
  }

  @override
  AccountIdentity? get currentUser => _mode == 'device'
      ? deviceIdentity
      : _mode == 'account'
      ? _remote?.currentUser
      : null;

  @override
  Stream<AccountIdentity?> authStateChanges() => Stream.multi((controller) {
    final subscription = _changes.stream.listen(
      controller.addSync,
      onError: controller.addErrorSync,
    );
    controller.addSync(currentUser);
    controller.onCancel = subscription.cancel;
  });

  @override
  Future<void> useDevice() async {
    await _saveMode('device');
    _mode = 'device';
    _changes.add(deviceIdentity);
  }

  Future<AccountIdentity> _signIn(
    Future<AccountIdentity> Function(AuthRepository) request,
  ) async {
    final remote = await _remoteReady;
    final result = await request(remote);
    await _saveMode('account');
    _mode = 'account';
    _changes.add(result);
    return result;
  }

  @override
  Future<AccountIdentity> signInWithGoogle() =>
      _signIn((remote) => remote.signInWithGoogle());
  @override
  Future<AccountIdentity> signInWithEmail({
    required String email,
    required String password,
  }) => _signIn(
    (remote) => remote.signInWithEmail(email: email, password: password),
  );
  @override
  Future<AccountIdentity> createAccountWithEmail({
    required String email,
    required String password,
  }) => _signIn(
    (remote) => remote.createAccountWithEmail(email: email, password: password),
  );
  @override
  Future<void> sendPasswordResetEmail(String email) async =>
      (await _remoteReady).sendPasswordResetEmail(email);
  @override
  Future<void> linkEmailPassword({
    required String email,
    required String password,
  }) async {
    if (_mode != 'account') {
      throw const AppFailure(
        FailureKind.permission,
        'Sign in to an account before adding a password.',
      );
    }
    await (await _remoteReady).linkEmailPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signOut() async {
    final previous = _mode;
    await _saveMode('signedOut');
    _mode = 'signedOut';
    _changes.add(null);
    if (previous == 'account') await (await _remoteReady).signOut();
  }

  Future<void> close() async {
    _closed = true;
    await _subscription?.cancel();
    await _changes.close();
  }
}
