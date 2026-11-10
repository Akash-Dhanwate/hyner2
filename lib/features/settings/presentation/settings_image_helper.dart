import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as raster;

const maxSettingsImageBytes = 8 * 1024 * 1024;
const maxSavedSettingsImageBytes = 2 * 1024 * 1024;

/// Checks the actual image data and stores a bounded, static PNG for bills.
Future<Uint8List> prepareSettingsImage(Uint8List bytes) async {
  if (bytes.isEmpty || bytes.length > maxSettingsImageBytes) {
    throw const FormatException('Choose an image no larger than 8 MB.');
  }
  final png =
      bytes.length >= 8 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71 &&
      bytes[4] == 13 &&
      bytes[5] == 10 &&
      bytes[6] == 26 &&
      bytes[7] == 10;
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255;
  final webp =
      bytes.length >= 12 &&
      bytes[0] == 82 &&
      bytes[1] == 73 &&
      bytes[2] == 70 &&
      bytes[3] == 70 &&
      bytes[8] == 87 &&
      bytes[9] == 69 &&
      bytes[10] == 66 &&
      bytes[11] == 80;
  if (!png && !jpeg && !webp) {
    throw const FormatException('Choose a PNG, JPEG or WebP image.');
  }

  try {
    // Encoded ImageDescriptor dimensions are unavailable in Flutter web.
    // Read bounded format metadata first, then use the shared codec API.
    final metadata = raster.findDecoderForData(bytes)?.startDecode(bytes);
    if (metadata == null) {
      throw const FormatException('This image cannot be opened.');
    }
    final width = metadata.width;
    final height = metadata.height;
    if (width <= 0 ||
        height <= 0 ||
        width > 12000 ||
        height > 12000 ||
        width * height > 24000000) {
      throw const FormatException(
        'Choose an image up to 24 megapixels and 12,000 pixels per side.',
      );
    }

    // Retry smaller if a detailed image still exceeds the stored byte limit.
    for (final edge in [1024, 768, 512]) {
      final scale = math.min(1.0, edge / math.max(width, height));
      final codec = await ui.instantiateImageCodec(
        bytes,
        allowUpscaling: false,
        targetWidth: math.max(1, (width * scale).round()),
        targetHeight: math.max(1, (height * scale).round()),
      );
      ui.Image? image;
      try {
        if (codec.frameCount != 1) {
          throw const FormatException(
            'Choose a still image, not an animation.',
          );
        }
        image = (await codec.getNextFrame()).image;
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data != null && data.lengthInBytes <= maxSavedSettingsImageBytes) {
          return data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        }
      } finally {
        image?.dispose();
        codec.dispose();
      }
    }
    throw const FormatException(
      'This image could not be resized. Try another.',
    );
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
      'This image cannot be opened. Try another image.',
    );
  }
}
