import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/device_access_repository.dart';
import 'local_business_database.dart';
import 'open_pricing_database.dart';
import 'pricing_database.dart';

/// Complete, checksummed account export. Tokens and sign-in mode are excluded.
/// A durable undo journal covers commits across the two independent databases.
class FullBackupService {
  FullBackupService({
    required this.business,
    required this.pricing,
    required this.directory,
    SharedPreferencesAsync? preferences,
  }) : preferences = preferences ?? SharedPreferencesAsync();
  final LocalBusinessDatabase business;
  final PricingDatabase pricing;
  final Directory directory;
  final SharedPreferencesAsync preferences;
  static const maxBytes = 64 * 1024 * 1024;
  static bool _active = false;
  File get _journal => File('${directory.path}/hyner-restore-journal.json');
  File get _undo => File('${directory.path}/hyner-restore-undo.hyner');

  static bool preferenceBelongsTo(String key, String uid) =>
      const ['hyner.appearance', 'hyner.theme.preset'].contains(key) ||
      const [
        'displayName',
        'contactEmail',
        'phone',
        'photoUrl',
      ].any((field) => key == 'hyner.profile.$uid.$field') ||
      key == 'hyner.profile.created.$uid' ||
      key.startsWith('hyner.guide.$uid.') ||
      key == 'hyner.pdf.include_customer_mobile.$uid';

  Future<Uint8List> export(String uid, {bool allowMissingImage = false}) async {
    final preferences = Map<String, Object?>.from(
      await this.preferences.getAll(),
    )..removeWhere((key, value) => !preferenceBelongsTo(key, uid));
    final files = <String, String>{};
    final photo = preferences['hyner.profile.$uid.photoUrl'];
    if (photo is String &&
        photo.startsWith('/') &&
        photo.contains('/profile-images/')) {
      final file = File(photo);
      if (await file.exists()) {
        if (await file.length() > 8 * 1024 * 1024) {
          throw const FormatException('Profile image is too large to back up.');
        }
        final bytes = await file.readAsBytes();
        final name = '${sha256.convert(bytes)}.png';
        files[name] = base64Encode(bytes);
        preferences['hyner.profile.$uid.photoUrl'] = 'backup-image:$name';
      } else if (allowMissingImage) {
        preferences['hyner.profile.$uid.photoUrl'] = '';
      } else {
        throw const FormatException(
          'The saved profile image is missing. Replace or remove it before creating a full backup.',
        );
      }
    }
    Map<String, dynamic>? pricingSnapshot;
    final businessSnapshot = await business.exportFor(
      uid,
      captureRelatedStores: () async {
        pricingSnapshot = await pricing.exportPortable();
      },
    );
    final payload = {
      'uid': uid,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'business': businessSnapshot,
      'pricing': pricingSnapshot,
      'preferences': preferences,
      'files': files,
    };
    final encoded = jsonEncode(payload);
    final result = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'hyner-full-backup',
          'version': 1,
          'sha256': sha256.convert(utf8.encode(encoded)).toString(),
          'data': payload,
        }),
      ),
    );
    if (result.length > maxBytes) {
      throw const FormatException(
        'The complete backup exceeds the supported 64 MiB limit.',
      );
    }
    return result;
  }

  static Map<String, dynamic> decode(List<int> bytes, String uid) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException(
        'Choose a non-empty backup no larger than 64 MiB.',
      );
    }
    final envelope = jsonDecode(utf8.decode(bytes));
    if (envelope is! Map ||
        envelope['format'] != 'hyner-full-backup' ||
        envelope['version'] != 1 ||
        envelope['data'] is! Map<String, dynamic>) {
      throw const FormatException('Unsupported complete backup.');
    }
    final data = envelope['data'] as Map<String, dynamic>;
    if (sha256.convert(utf8.encode(jsonEncode(data))).toString() !=
        envelope['sha256']) {
      throw const FormatException('The backup checksum does not match.');
    }
    if (data['uid'] != uid) {
      throw const FormatException(
        'This backup belongs to a different workspace.',
      );
    }
    if (data['business'] is! Map<String, dynamic> ||
        data['pricing'] is! Map<String, dynamic> ||
        data['preferences'] is! Map<String, dynamic> ||
        data['files'] is! Map<String, dynamic>) {
      throw const FormatException('Incomplete backup contents.');
    }
    for (final entry in (data['preferences'] as Map<String, dynamic>).entries) {
      final value = entry.value;
      final boolean =
          entry.key.startsWith('hyner.guide.$uid.') ||
          entry.key == 'hyner.pdf.include_customer_mobile.$uid';
      if (!preferenceBelongsTo(entry.key, uid) ||
          (boolean ? value is! bool : value is! String)) {
        throw const FormatException('Invalid backup preference type.');
      }
      if (entry.key == 'hyner.appearance' &&
          !const ['system', 'light', 'dark'].contains(value)) {
        throw const FormatException('Invalid appearance preference.');
      }
      if (entry.key == 'hyner.theme.preset' &&
          !const [
            'slateBlue',
            'sageGreen',
            'warmCopper',
            'mutedViolet',
          ].contains(value)) {
        throw const FormatException('Invalid theme preference.');
      }
    }

    final files = data['files'] as Map<String, dynamic>;
    var imageBytes = 0;
    for (final entry in files.entries) {
      if (!RegExp(r'^[a-f0-9]{64}\.png$').hasMatch(entry.key) ||
          entry.value is! String ||
          (entry.value as String).length > 12 * 1024 * 1024) {
        throw const FormatException('Invalid backup image.');
      }
      final content = base64Decode(entry.value as String);
      imageBytes += content.length;
      if (content.length > 8 * 1024 * 1024 ||
          imageBytes > 16 * 1024 * 1024 ||
          '${sha256.convert(content)}.png' != entry.key) {
        throw const FormatException('Invalid backup image checksum.');
      }
    }
    final photo = (data['preferences'] as Map)['hyner.profile.$uid.photoUrl'];
    if (photo is String &&
        photo.startsWith('backup-image:') &&
        !files.containsKey(photo.substring(13))) {
      throw const FormatException('A required profile image is missing.');
    }
    if (photo is String && photo.startsWith('/')) {
      throw const FormatException(
        'The backup contains an unsupported external photo path.',
      );
    }
    return data;
  }

  Future<void> _apply(
    String uid,
    Map<String, dynamic> data, {
    bool validateOnly = false,
  }) async {
    await business.restoreFor(
      uid,
      data['business'] as Map<String, dynamic>,
      validateOnly: validateOnly,
      beforeCommit: () async {
        await pricing.restorePortable(
          data['pricing'] as Map<String, dynamic>,
          validateOnly: validateOnly,
        );
        if (!validateOnly) await _applyPreferences(uid, data);
      },
    );
  }

  Future<void> _applyPreferences(String uid, Map<String, dynamic> data) async {
    final saved = Map<String, dynamic>.from(data['preferences'] as Map);
    for (final entry in (data['files'] as Map<String, dynamic>).entries) {
      final target = File(
        '${directory.path}/profile-images/${sha256.convert(utf8.encode(uid))}-${entry.key}',
      );
      await target.parent.create(recursive: true);
      await target.writeAsBytes(
        base64Decode(entry.value as String),
        flush: true,
      );
    }
    final photoKey = 'hyner.profile.$uid.photoUrl';
    final photo = saved[photoKey];
    if (photo is String && photo.startsWith('backup-image:')) {
      saved[photoKey] =
          '${directory.path}/profile-images/${sha256.convert(utf8.encode(uid))}-${photo.substring(13)}';
    }
    final keys = (await preferences.getKeys())
        .where((key) => preferenceBelongsTo(key, uid))
        .toSet();
    if (keys.isNotEmpty) await preferences.clear(allowList: keys);
    for (final entry in saved.entries) {
      final value = entry.value;
      if (value is String) {
        await preferences.setString(entry.key, value);
      } else if (value is bool) {
        await preferences.setBool(entry.key, value);
      } else if (value is int) {
        await preferences.setInt(entry.key, value);
      } else if (value is double) {
        await preferences.setDouble(entry.key, value);
      } else if (value is List) {
        await preferences.setStringList(entry.key, value.cast<String>());
      }
    }
  }

  Future<void> restore(
    String uid,
    List<int> bytes, {
    required bool Function() isCurrent,
    Future<void> Function()? afterBusinessCommit,
  }) async {
    if (_active) throw StateError('Another backup operation is in progress.');
    _active = true;
    try {
      final data = decode(bytes, uid);
      await _apply(uid, data, validateOnly: true);
      if (!isCurrent()) {
        throw StateError('Workspace changed. Reopen backup settings.');
      }
      if (await _journal.exists()) {
        throw StateError(
          'An earlier restore must be recovered before continuing.',
        );
      }
      final previous = await export(uid, allowMissingImage: true);
      await directory.create(recursive: true);
      await _undo.writeAsBytes(previous, flush: true);
      // The journal is written only after the complete undo snapshot is durable.
      final pending = File('${_journal.path}.pending');
      await pending.writeAsString(jsonEncode({'uid': uid}), flush: true);
      await pending.rename(_journal.path);
      try {
        if (!isCurrent()) throw StateError('Workspace changed.');
        if (afterBusinessCommit != null) {
          // Failure injection exercises cross-database recovery in tests.
          await business.restoreFor(
            uid,
            data['business'] as Map<String, dynamic>,
          );
          await afterBusinessCommit();
        }
        await _apply(uid, data);
        await _journal.delete();
      } catch (_) {
        await _apply(uid, decode(previous, uid));
        await _journal.delete();
        rethrow;
      }
      // An orphan undo file is harmless; it is never interpreted without a journal.
      if (await _undo.exists()) await _undo.delete();
    } finally {
      _active = false;
    }
  }

  Future<void> recover(String uid) async {
    if (!await _journal.exists()) return;
    final state = jsonDecode(await _journal.readAsString());
    if (state is! Map || state['uid'] != uid) {
      throw const FormatException('The restore journal is invalid.');
    }
    if (!await _undo.exists() || await _undo.length() > maxBytes) {
      throw const FormatException(
        'Restore recovery is unavailable. Original data has not been reset.',
      );
    }
    await _apply(uid, decode(await _undo.readAsBytes(), uid));
    await _journal.delete();
    await _undo.delete();
  }

  /// Run before any providers open the workspace after process termination.
  static Future<void> recoverOnStartup() async {
    final directory = await getApplicationSupportDirectory();
    final journal = File('${directory.path}/hyner-restore-journal.json');
    if (!await journal.exists()) return;
    final state = jsonDecode(await journal.readAsString());
    final uid = (state as Map)['uid'];
    if (uid is! String ||
        uid.isEmpty ||
        uid.contains('/') ||
        uid.length > 128) {
      throw const FormatException('Invalid restore workspace.');
    }
    final pricing = openLocalPricingDatabase(
      accountUid: uid == deviceOwnerUid ? null : uid,
    );
    try {
      await FullBackupService(
        business: LocalBusinessDatabase.instance,
        pricing: pricing,
        directory: directory,
      ).recover(uid);
    } finally {
      await pricing.close();
    }
  }
}
