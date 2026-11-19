import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import 'local_business_database.dart';
import 'full_backup_service.dart';
import 'pricing_database.dart';
import 'generated_backup_files.dart';

class BackupService {
  BackupService._();

  static const maxBackupFileBytes = 64 * 1024 * 1024;

  static void validateBackupFileSize(int bytes) {
    if (bytes < 1 || bytes > maxBackupFileBytes) {
      throw const FormatException(
        'Choose a non-empty backup no larger than 64 MiB.',
      );
    }
  }

  static Future<bool> exportComplete(
    String uid,
    PricingDatabase pricing,
  ) async {
    final service = FullBackupService(
      business: LocalBusinessDatabase.instance,
      pricing: pricing,
      directory: await getApplicationSupportDirectory(),
    );
    final bytes = await service.export(uid);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save complete Hyner backup',
      fileName: 'hyner-$stamp.hyner',
      type: FileType.custom,
      allowedExtensions: ['hyner'],
      bytes: bytes,
    );
    if (path == null) return false;
    if (!Platform.isAndroid && !Platform.isIOS) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return true;
  }

  static Future<void> exportAndShare(String uid) async {
    final snapshot = await LocalBusinessDatabase.instance.exportFor(uid);
    final directory = await getTemporaryDirectory();
    await GeneratedBackupFiles.cleanOccasionally(directory);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${directory.path}/hyner-backup-$stamp.json');
    GeneratedBackupFiles.protect(file);
    try {
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(snapshot),
        flush: true,
      );
      await SharePlus.instance.share(
        ShareParams(
          text: 'Hyner local business backup',
          files: [XFile(file.path, mimeType: 'application/json')],
        ),
      );
    } finally {
      GeneratedBackupFiles.release(file);
    }
  }

  static Future<bool> pickAndRestore(
    String uid, {
    bool Function()? isWorkspaceCurrent,
    PricingDatabase? pricing,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'hyner'],
      withData: false,
    );
    if (result == null) return false;
    final file = result.files.single;
    validateBackupFileSize(file.size);
    final path = file.path;
    if (path == null) {
      throw const FormatException(
        'The selected backup file could not be read.',
      );
    }
    validateBackupFileSize(await File(path).length());
    final bytes = await File(path).readAsBytes();
    validateBackupFileSize(bytes.length);
    if (isWorkspaceCurrent != null && !isWorkspaceCurrent()) return false;
    final snapshot = jsonDecode(utf8.decode(bytes));
    if (snapshot is! Map<String, dynamic>) {
      throw const FormatException('The selected file is not a valid backup.');
    }
    if (snapshot['format'] == 'hyner-full-backup') {
      if (pricing == null) {
        throw const FormatException(
          'Open the calculator workspace before restoring a complete backup.',
        );
      }
      await FullBackupService(
        business: LocalBusinessDatabase.instance,
        pricing: pricing,
        directory: await getApplicationSupportDirectory(),
      ).restore(uid, bytes, isCurrent: isWorkspaceCurrent ?? () => true);
    } else {
      await LocalBusinessDatabase.instance.restoreFor(uid, snapshot);
    }
    return true;
  }
}
