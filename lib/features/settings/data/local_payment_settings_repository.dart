import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/local_business_database.dart';
import '../domain/payment_settings.dart';

class LocalPaymentSettingsRepository implements PaymentSettingsRepository {
  LocalPaymentSettingsRepository(this._store);
  final LocalBusinessDatabase _store;

  @override
  Future<PaymentSettings> read(String uid) async {
    final db = await _store.databaseFor(uid);
    final rows = await db.query(
      'settings',
      where: 'key IN (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      whereArgs: [
        'upiId',
        'merchantName',
        'businessPhone',
        'businessAddress',
        'taxId',
        'billLayout',
        'logoBase64',
        'signatureBase64',
        'headerFontSize',
        'footerText',
        'billFontColors',
      ],
    );
    final values = {for (final row in rows) row['key']: row['value'] as String};
    return PaymentSettings(
      upiId: values['upiId'] ?? '',
      merchantName: values['merchantName'] ?? '',
      businessPhone: values['businessPhone'] ?? '',
      businessAddress: values['businessAddress'] ?? '',
      taxId: values['taxId'] ?? '',
      billLayout: values['billLayout'] == BillLayout.centered.name
          ? BillLayout.centered
          : BillLayout.right,
      logoBase64: values['logoBase64'] ?? '',
      signatureBase64: values['signatureBase64'] ?? '',
      headerFontSize: double.tryParse(values['headerFontSize'] ?? '') ?? 20,
      footerText: values['footerText'] ?? 'Thank you for your business.',
      fontColors: _readColors(values['billFontColors']),
    );
  }

  @override
  Future<void> save(String uid, PaymentSettings settings) async {
    final upiId = settings.upiId.trim();
    final name = settings.merchantName.trim();
    final phone = settings.businessPhone.trim();
    final address = settings.businessAddress.trim();
    final taxId = settings.taxId.trim();
    final footerText = settings.footerText.trim();
    if (upiId.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9._-]{2,100}@[A-Za-z0-9.-]{2,64}$')
            .hasMatch(upiId)) {
      throw const FormatException(
        'Enter a valid UPI ID, for example shop@bank.',
      );
    }
    if (name.length > 80) {
      throw const FormatException(
        'Business name must be 80 characters or less.',
      );
    }
    if (phone.length > 40 ||
        address.length > 240 ||
        taxId.length > 40 ||
        footerText.length > 160) {
      throw const FormatException('Business details are too long.');
    }
    if (settings.headerFontSize < 14 || settings.headerFontSize > 32) {
      throw const FormatException('Bill title size must be between 14 and 32.');
    }
    if (settings.fontColors.values.any(
      (color) => color < 0 || color > 0xffffff,
    )) {
      throw const FormatException('Use a six-digit RGB font colour.');
    }
    final db = await _store.databaseFor(uid);
    await db.transaction((tx) async {
      for (final entry in {
        'upiId': upiId,
        'merchantName': name,
        'businessPhone': phone,
        'businessAddress': address,
        'taxId': taxId,
        'billLayout': settings.billLayout.name,
        'logoBase64': settings.logoBase64,
        'signatureBase64': settings.signatureBase64,
        'headerFontSize': '${settings.headerFontSize}',
        'footerText': footerText,
        'billFontColors': jsonEncode({
          for (final entry in settings.fontColors.entries)
            entry.key.name: entry.value,
        }),
      }.entries) {
        await tx.insert('settings', {
          'key': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}

Map<BillTextSection, int> _readColors(String? raw) {
  try {
    final decoded = jsonDecode(raw ?? '{}');
    if (decoded is! Map) return const {};
    return {
      for (final section in BillTextSection.values)
        if (decoded[section.name] is int &&
            decoded[section.name] >= 0 &&
            decoded[section.name] <= 0xffffff)
          section: decoded[section.name] as int,
    };
  } catch (_) {
    return const {};
  }
}
