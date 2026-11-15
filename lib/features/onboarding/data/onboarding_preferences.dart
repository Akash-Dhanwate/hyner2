import 'package:shared_preferences/shared_preferences.dart';

abstract interface class OnboardingPreferenceStore {
  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
}

/// Stores only guide progress. Business data remains in the existing register.
class OnboardingPreferences {
  OnboardingPreferences({OnboardingPreferenceStore? store})
    : _store = store ?? _SharedPreferencesOnboardingStore();

  final OnboardingPreferenceStore _store;

  String _key(String uid, String suffix) => 'hyner.guide.$uid.$suffix';

  Future<bool> isComplete(String uid) async =>
      await _store.getBool(_key(uid, 'complete')) ?? false;

  Future<void> setComplete(String uid) =>
      _store.setBool(_key(uid, 'complete'), true);

  Future<bool> isStepComplete(String uid, String step) async =>
      await _store.getBool(_key(uid, step)) ?? false;

  Future<void> setStepComplete(String uid, String step, bool complete) async {
    await _store.setBool(_key(uid, step), complete);
  }
}

class _SharedPreferencesOnboardingStore implements OnboardingPreferenceStore {
  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get _store =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<bool?> getBool(String key) => _store.getBool(key);

  @override
  Future<void> setBool(String key, bool value) => _store.setBool(key, value);
}
