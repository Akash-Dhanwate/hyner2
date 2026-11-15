import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> storeProfilePhoto(String uid, Uint8List bytes) async {
  if (uid.isEmpty ||
      uid.length > 128 ||
      bytes.isEmpty ||
      bytes.length > 2 * 1024 * 1024) {
    throw const FormatException('Invalid profile photo.');
  }
  final directory = Directory(
    '${(await getApplicationSupportDirectory()).path}/profile-images',
  );
  await directory.create(recursive: true);
  final encodedId = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
  final safeId = encodedId.length > 120
      ? encodedId.substring(0, 120)
      : encodedId;
  final file = File(
    '${directory.path}/$safeId-${DateTime.now().microsecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<Uint8List> readProfilePhotoFile(String path) async {
  if (!path.startsWith('/') ||
      !path.contains('/profile-images/') ||
      path.contains('/../')) {
    throw const FormatException('Invalid photo location.');
  }
  final file = File(path);
  if (await file.length() > 8 * 1024 * 1024) {
    throw const FormatException('Photo is too large.');
  }
  return file.readAsBytes();
}
