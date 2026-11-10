import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import 'local_business_database.dart';

class BackupService {
  BackupService._();

  static Future<void> exportAndShare(String uid) async {
    final snapshot = await LocalBusinessDatabase.instance.exportFor(uid);
    final directory = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${directory.path}/hyner-backup-$stamp.json');
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
  }

  static Future<bool> pickAndRestore(String uid) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return false;
    final snapshot = jsonDecode(utf8.decode(result.files.single.bytes!));
    if (snapshot is! Map<String, dynamic>) {
      throw const FormatException('The selected file is not a valid backup.');
    }
    await LocalBusinessDatabase.instance.restoreFor(uid, snapshot);
    return true;
  }
}
