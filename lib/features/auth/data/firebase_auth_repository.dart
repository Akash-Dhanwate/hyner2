import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._serverClientId);

  final FirebaseAuth _auth;
  final String _serverClientId;
  final GoogleSignIn _google = GoogleSignIn.instance;
  Future<void>? _initialization;

  Future<void> _initializeGoogle() =>
      _initialization ??= _google.initialize(serverClientId: _serverClientId);

  AccountIdentity _identity(User user) {
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const AppFailure(
        FailureKind.invalidData,
        'Google did not provide an email address for this account.',
      );
    }
    return AccountIdentity(
      uid: user.uid,
      email: email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  @override
  AccountIdentity? get currentUser =>
      _auth.currentUser == null ? null : _identity(_auth.currentUser!);

  @override
  Stream<AccountIdentity?> authStateChanges() => _auth.authStateChanges().map(
    (user) => user == null ? null : _identity(user),
  );

  @override
  Future<AccountIdentity> signInWithGoogle() async {
    try {
      await _initializeGoogle();
      final account = await _google.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const AppFailure(
          FailureKind.unknown,
          'Google did not return a sign-in token. Please try again.',
          reference: 'google/missing-id-token',
        );
      }
      final result = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: token),
      );
      if (result.user == null) {
        throw const AppFailure(
          FailureKind.unknown,
          'Your sign-in could not be completed. Please try again.',
          reference: 'firebase_auth/missing-user',
        );
      }
      return _identity(result.user!);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  Future<AccountIdentity> _emailResult(Future<UserCredential> request) async {
    final result = await request;
    final user = result.user;
    if (user == null) {
      throw const AppFailure(
        FailureKind.unknown,
        'Your sign-in could not be completed. Please try again.',
      );
    }
    return _identity(user);
  }

  @override
  Future<AccountIdentity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _emailResult(
        _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<AccountIdentity> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _emailResult(
        _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> linkEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const AppFailure(
          FailureKind.permission,
          'Sign in before adding a password.',
        );
      }
      await user.linkWithCredential(
        EmailAuthProvider.credential(email: email.trim(), password: password),
      );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> signOut() async {
    // End the Firebase session before cleaning up the provider session.
    try {
      await _auth.signOut();
      await _initializeGoogle();
      await _google.signOut();
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

class UnconfiguredAuthRepository implements AuthRepository {
  @override
  AccountIdentity? get currentUser => null;

  @override
  Stream<AccountIdentity?> authStateChanges() => Stream.value(null);

  @override
  Future<AccountIdentity> signInWithGoogle() async => throw const AppFailure(
    FailureKind.configuration,
    'This installation has not been connected to account services.',
  );
  @override
  Future<AccountIdentity> signInWithEmail({
    required String email,
    required String password,
  }) async => throw const AppFailure(
    FailureKind.configuration,
    'This installation has not been connected to account services.',
  );
  @override
  Future<AccountIdentity> createAccountWithEmail({
    required String email,
    required String password,
  }) async => throw const AppFailure(
    FailureKind.configuration,
    'This installation has not been connected to account services.',
  );
  @override
  Future<void> linkEmailPassword({
    required String email,
    required String password,
  }) async => throw const AppFailure(
    FailureKind.configuration,
    'This installation has not been connected to account services.',
  );
  @override
  Future<void> sendPasswordResetEmail(String email) async =>
      throw const AppFailure(
        FailureKind.configuration,
        'This installation has not been connected to account services.',
      );

  @override
  Future<void> signOut() async {}
}
