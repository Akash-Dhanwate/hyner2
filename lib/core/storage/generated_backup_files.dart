import 'dart:io';

/// Best-effort hygiene for generated backup handoffs, never a business archive.
abstract final class GeneratedBackupFiles {
  static const retention = Duration(days: 7);
  static final _clock = Stopwatch()..start();
  static final _sessionStarted = DateTime.now();
  static final _active = <String>{};
  static Duration? _lastCleanup;
  static final _name = RegExp(
    r'^hyner-backup-\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d{3}(?:\d{3})?(?:Z)?\.json$',
  );

  static void protect(File file) => _active.add(file.absolute.path);
  static void release(File file) => _active.remove(file.absolute.path);

  static Future<void> cleanOccasionally(Directory directory) async {
    if (_lastCleanup != null &&
        _clock.elapsed - _lastCleanup! < const Duration(days: 1)) {
      return;
    }
    _lastCleanup = _clock.elapsed;
    try {
      await clean(
        directory,
        now: DateTime.now(),
        protectedSince: _sessionStarted,
        activePaths: _active,
      );
    } catch (_) {
      // A cleanup failure must not prevent exporting or sharing a backup.
    }
  }

  /// Streams entries, limits per-pass I/O, and skips links, active and session files.
  static Future<({int filesDeleted, int bytesDeleted})> clean(
    Directory directory, {
    required DateTime now,
    required DateTime protectedSince,
    Set<String> activePaths = const {},
    int maxEntries = 1000,
  }) async {
    var inspected = 0, filesDeleted = 0, bytesDeleted = 0;
    final cutoff = now.subtract(retention);
    await for (final entry in directory.list(followLinks: false)) {
      if (inspected++ >= maxEntries) break;
      if (entry is! File ||
          !_name.hasMatch(entry.uri.pathSegments.last) ||
          activePaths.contains(entry.absolute.path)) {
        continue;
      }
      try {
        final stat = await entry.stat();
        if (stat.type != FileSystemEntityType.file ||
            !stat.modified.isBefore(cutoff) ||
            !stat.modified.isBefore(protectedSince)) {
          continue;
        }
        await entry.delete();
        filesDeleted++;
        bytesDeleted += stat.size;
      } on FileSystemException {
        // Another cleanup/provider can move or remove a temporary file first.
      }
    }
    return (filesDeleted: filesDeleted, bytesDeleted: bytesDeleted);
  }
}
