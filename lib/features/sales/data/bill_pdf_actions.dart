import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

/// Document actions consume saved business documents. They never create a sale
/// or change stock, including when the platform action is retried or canceled.
abstract final class BillPdfActions {
  static const channel = MethodChannel('hyner/bill_pdf');

  static Future<void> shareWhatsApp(
    Uint8List bytes,
    String filename, {
    String? phone,
  }) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await channel.invokeMethod<void>('shareWhatsApp', {
          'bytes': bytes,
          'filename': filename,
          'phone': ?phone,
        });
        return;
      } on MissingPluginException {
        // Other installations can still share through the system sheet.
      } on PlatformException {
        // Keep generic sharing available if a targeted intent cannot open.
      }
    }
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  static Future<void> copyPdf(Uint8List bytes, String filename) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Copy PDF is available on Android.');
    }
    await channel.invokeMethod<void>('copyPdf', {
      'bytes': bytes,
      'filename': filename,
    });
  }

  /// A null result means the user canceled the document picker.
  static Future<String?> save(Uint8List bytes, String filename) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        return await channel.invokeMethod<String>('savePdf', {
          'bytes': bytes,
          'filename': filename,
        });
      } on MissingPluginException {
        // Fall back for hosts that do not ship the native bill channel.
      }
    }
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: bytes,
    );
  }
}
