import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/storage/full_backup_service.dart';
import '../../../core/storage/local_business_database.dart';
import '../../../core/storage/open_pricing_database.dart';

class AccountDeletionService {
  static const endpoint = String.fromEnvironment(
    'HYNER_ACCOUNT_DELETION_ENDPOINT',
  );
  static Future<void> delete(
    String uid, {
    required Future<void> Function() closePricing,
    required bool Function() isCurrent,
  }) async {
    final url = Uri.tryParse(endpoint);
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      throw StateError(
        'Account deletion service has not been configured for this build.',
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user?.uid != uid || !isCurrent()) {
      throw StateError('Sign in to this account again before deleting.');
    }
    final token = await user!.getIdToken();
    if (token == null || !isCurrent()) {
      throw StateError('Sign in again before deleting.');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(url);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'confirm': 'DELETE_MY_ACCOUNT'}));
      final response = await request.close().timeout(
        const Duration(seconds: 120),
      );
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != 200) {
        if (response.statusCode == 401) {
          throw StateError(
            'For your security, sign out and sign in again, then retry deletion.',
          );
        }
        throw StateError(
          'Account deletion was not confirmed. Your local data has been retained.',
        );
      }
      final result = jsonDecode(body);
      if (result is! Map || result['deleted'] != true || result['uid'] != uid) {
        throw StateError(
          'The account deletion response could not be verified.',
        );
      }
    } finally {
      client.close(force: true);
    }
    final directory = await getApplicationSupportDirectory();
    await File('${directory.path}/hyner-account-deletion.json')
        .writeAsString(jsonEncode({'uid': uid}), flush: true);
    await closePricing();
    await LocalBusinessDatabase.instance.close();
    await finishLocalDeletion();
    await FirebaseAuth.instance.signOut();
  }

  /// A confirmed remote deletion is finished locally before reopening any stores.
  static Future<void> finishLocalDeletion() async {
    final support = await getApplicationSupportDirectory();
    final journal = File('${support.path}/hyner-account-deletion.json');
    if (!await journal.exists()) return;
    final uid = (jsonDecode(await journal.readAsString()) as Map)['uid'];
    if (uid is! String ||
        uid.isEmpty ||
        uid.length > 128 ||
        uid.contains('/')) {
      throw const FormatException('Invalid deletion journal.');
    }
    final key = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
    await deleteDatabase('${await getDatabasesPath()}/hyner_register_$key.db');
    final documents = await getApplicationDocumentsDirectory();
    final pricing =
        '${documents.path}/${localPricingDatabaseName(accountUid: uid)}.sqlite';
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File('$pricing$suffix');
      if (await file.exists()) await file.delete();
    }
    final images = Directory('${support.path}/profile-images');
    final preferences = SharedPreferencesAsync();
    final photo = await preferences.getString('hyner.profile.$uid.photoUrl');
    if (photo != null &&
        photo.startsWith('${images.path}/') &&
        await File(photo).exists()) {
      await File(photo).delete();
    }
    if (await images.exists()) {
      final prefix = key.length > 120 ? key.substring(0, 120) : key;
      await for (final entity in images.list(followLinks: false)) {
        if (entity is File &&
            (entity.path
                    .split('/')
                    .last
                    .startsWith('${sha256.convert(utf8.encode(uid))}-') ||
                key.length <= 120 &&
                    entity.path.split('/').last.startsWith('$prefix-'))) {
          await entity.delete();
        }
      }
    }
    final keys = (await preferences.getKeys())
        .where(
          (k) =>
              FullBackupService.preferenceBelongsTo(k, uid) &&
              k != 'hyner.appearance' &&
              k != 'hyner.theme.preset',
        )
        .toSet();
    if (keys.isNotEmpty) await preferences.clear(allowList: keys);
    await preferences.setString('hyner.workspace.mode', 'signedOut');
    await journal.delete();
  }
}
