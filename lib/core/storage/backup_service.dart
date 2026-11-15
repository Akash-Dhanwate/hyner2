import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import 'local_business_database.dart';
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
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
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
    final bytes = await File(path).readAsBytes();
    validateBackupFileSize(bytes.length);
    if (isWorkspaceCurrent != null && !isWorkspaceCurrent()) return false;
    final snapshot = jsonDecode(utf8.decode(bytes));
    if (snapshot is! Map<String, dynamic>) {
      throw const FormatException('The selected file is not a valid backup.');
    }
    await LocalBusinessDatabase.instance.restoreFor(uid, snapshot);
    return true;
  }
}
