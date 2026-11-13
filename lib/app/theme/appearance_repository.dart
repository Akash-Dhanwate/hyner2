import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_preset.dart';

abstract interface class AppearanceRepository {
  Future<ThemeMode> read();
  Future<void> write(ThemeMode mode);
  Future<ThemePreset> readPreset();
  Future<void> writePreset(ThemePreset preset);
}

class LocalAppearanceRepository implements AppearanceRepository {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  static const _key = 'hyner.appearance';
  static const _presetKey = 'hyner.theme.preset';

  @override
  Future<ThemeMode> read() async {
    final value = await _preferences.getString(_key);
    return ThemeMode.values.where((mode) => mode.name == value).firstOrNull ??
        ThemeMode.system;
  }

  @override
  Future<void> write(ThemeMode mode) => _preferences.setString(_key, mode.name);

  @override
  Future<ThemePreset> readPreset() async {
    final value = await _preferences.getString(_presetKey);
    return ThemePreset.values.where((p) => p.name == value).firstOrNull ??
        ThemePreset.sageGreen;
  }

  @override
  Future<void> writePreset(ThemePreset preset) =>
      _preferences.setString(_presetKey, preset.name);
}
