import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/backup_service.dart';

void main() {
  test('backup file size validation accepts bounded files only', () {
    BackupService.validateBackupFileSize(1);
    BackupService.validateBackupFileSize(BackupService.maxBackupFileBytes);
    expect(
      () => BackupService.validateBackupFileSize(0),
      throwsFormatException,
    );
    expect(
      () => BackupService.validateBackupFileSize(
        BackupService.maxBackupFileBytes + 1,
      ),
      throwsFormatException,
    );
  });
}
