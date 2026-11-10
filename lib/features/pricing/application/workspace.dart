import 'dart:convert';
import 'dart:math';

import '../domain/pricing_models.dart';
import '../domain/pricing_repository.dart';
import '../domain/serialization.dart';
import '../domain/universal/rate_card.dart';

String newPricingId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

abstract interface class WorkspaceValues implements BusinessTaxPolicies {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, dynamic>? value);
  Future<void> approve(TaxPolicy policy);
}

void validateWorkspaceValue(Map<String, dynamic>? value) {
  if (value != null && utf8.encode(canonicalJson(value)).length > 1024 * 1024) {
    throw ArgumentError('This draft is too large to save');
  }
}

class QuickPriceWorkspace {
  QuickPriceWorkspace({
    required this.businessId,
    required this.repository,
    required this.values,
    this.preview = false,
    this.onClose,
  });
  final String businessId;
  final UniversalRateCardRepository repository;
  final WorkspaceValues values;
  final bool preview;
  final Future<void> Function()? onClose;
  Future<void> close() async {
    await onClose?.call();
  }

  Future<List<PricingProfileSummary>> profiles() async {
    final result = <PricingProfileSummary>[];
    String cursor = '';
    for (var page = 0; page < 20; page++) {
      final next = await repository.profiles(afterId: cursor, limit: 50);
      result.addAll(next);
      if (next.length < 50) return result;
      cursor = next.last.id;
    }
    throw StateError('Too many profiles to open at once');
  }
}

/// Serializes local UI-state writes without poisoning later retries on failure.
class DraftWriter {
  DraftWriter(this.values);
  final WorkspaceValues values;
  Future<void> _tail = Future.value();
  Future<void> write(String key, Map<String, dynamic>? value) {
    final snapshot = value == null ? null : jsonObject(canonicalJson(value));
    final next = _tail.then((_) => values.write(key, snapshot));
    _tail = next.catchError((Object _) {});
    return next;
  }

  Future<void> flush() => _tail;
}
