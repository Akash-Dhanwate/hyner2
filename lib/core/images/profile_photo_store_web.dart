import 'dart:typed_data';

Future<String> storeProfilePhoto(String uid, Uint8List bytes) async =>
    throw UnsupportedError(
      'Save a cropped profile photo using the Android or iOS app.',
    );
Future<Uint8List> readProfilePhotoFile(String path) async =>
    throw UnsupportedError('Choose a photo from this device.');
