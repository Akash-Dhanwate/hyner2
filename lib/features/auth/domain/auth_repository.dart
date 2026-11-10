class AccountIdentity {
  const AccountIdentity({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.localOnly = false,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool localOnly;
}

/// Explicit device access is separate from Firebase authentication.
abstract interface class DeviceAccess {
  Future<void> useDevice();
}

abstract interface class AuthRepository {
  AccountIdentity? get currentUser;
  Stream<AccountIdentity?> authStateChanges();
  Future<AccountIdentity> signInWithGoogle();
  Future<AccountIdentity> signInWithEmail({
    required String email,
    required String password,
  });
  Future<AccountIdentity> createAccountWithEmail({
    required String email,
    required String password,
  });
  Future<void> linkEmailPassword({
    required String email,
    required String password,
  });
  Future<void> sendPasswordResetEmail(String email);
  Future<void> signOut();
}
