import 'dart:convert';

/// Stable ordering for replayable snapshots; exact numbers are strings.
String canonicalJson(Object? value) => jsonEncode(_canonical(value));
Object? _canonical(Object? value) {
  if (value is Map<String, dynamic>) {
    final keys = value.keys.toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  if (value == null || value is String || value is bool) {
    return value;
  }
  // JavaScript cannot distinguish 1 from 1.0. Normalize safe whole metadata
  // numbers consistently on both platforms; financial values remain strings.
  if (value is num &&
      value.isFinite &&
      value.abs() <= 9007199254740991 &&
      value == value.truncate()) {
    return value.toInt();
  }
  throw ArgumentError('Use JSON primitives; decimals must be strings');
}

Map<String, dynamic> jsonObject(String value) =>
    jsonDecode(value) as Map<String, dynamic>;
