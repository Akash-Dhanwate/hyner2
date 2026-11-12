import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/generated_backup_files.dart';

void main() {
  test('cleanup removes only expired generated inactive backups; keeps symlinks and session files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'hyner-temp-backups-',
    );
    final outside = await Directory.systemTemp.createTemp('hyner-user-export-');
    addTearDown(() async {
      await directory.delete(recursive: true);
      await outside.delete(recursive: true);
    });
    final now = DateTime(2026, 11, 10, 12), old = DateTime(2026, 10, 1);
    Future<File> make(String name, DateTime time) async {
      final file = File('${directory.path}/$name');
      await file.writeAsString('backup fixture');
      await file.setLastModified(time);
      return file;
    }

    final stale = await make('hyner-backup-2026-10-01T10-00-00.000.json', old);
    final active = await make('hyner-backup-2026-10-02T10-00-00.000.json', old);
    final fresh = await make('hyner-backup-2026-11-10T10-00-00.000.json', now);
    final session = await make(
      'hyner-backup-2026-10-03T10-00-00.000.json',
      old.add(const Duration(days: 2)),
    );
    final userExport = await make('my-business-backup.json', old);
    final target = File('${outside.path}/durable.json');
    await target.writeAsString('must survive');
    await target.setLastModified(old);
    final link = Link(
      '${directory.path}/hyner-backup-2026-10-04T10-00-00.000.json',
    );
    await link.create(target.path);
    // Simulate a session lasting over seven days: even its oldest handoff stays protected.
    final summary = await GeneratedBackupFiles.clean(
      directory,
      now: now,
      protectedSince: old.add(const Duration(days: 1)),
      activePaths: {active.absolute.path},
    );
    expect(summary.filesDeleted, 1);
    expect(summary.bytesDeleted, 14);
    expect(await stale.exists(), isFalse);
    for (final file in [active, fresh, session, userExport, target]) {
      expect(await file.exists(), isTrue);
    }
    expect(await link.exists(), isTrue);
  });
}
