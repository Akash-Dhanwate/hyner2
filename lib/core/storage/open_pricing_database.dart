import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'pricing_database.dart';

/// Local-only Android business storage. Web will receive an authorized cloud
/// repository; browser-local persistence must not become its source of truth.
String localPricingDatabaseName({String? accountUid}) {
  if (accountUid == null) return 'hyner_quickprice';
  if (accountUid.isEmpty ||
      accountUid.length > 128 ||
      accountUid.contains('/')) {
    throw ArgumentError('Invalid account workspace');
  }
  final key = base64Url.encode(utf8.encode(accountUid)).replaceAll('=', '');
  return 'hyner_quickprice_account_$key';
}

PricingDatabase openLocalPricingDatabase({String? accountUid}) {
  if (kIsWeb) {
    throw UnsupportedError(
      'Connect an authorized cloud pricing repository on web',
    );
  }
  return PricingDatabase(
    driftDatabase(
      name: localPricingDatabaseName(accountUid: accountUid),
      native: const DriftNativeOptions(shareAcrossIsolates: true),
    ),
  );
}
