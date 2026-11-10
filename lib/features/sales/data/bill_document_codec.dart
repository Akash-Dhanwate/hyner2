import 'dart:typed_data';

import 'package:archive/archive.dart';

/// The on-device envelope is independent of the PDF returned for sharing.
class BillDocumentCodec {
  static const maxPdfBytes = 5 * 1024 * 1024;

  static ({String encoding, Uint8List bytes}) encodePdf(List<int> pdf) {
    _validatePdf(pdf);
    final compressed = const ZLibEncoderWeb().encodeBytes(pdf, level: 9);
    return compressed.length < pdf.length
        ? (encoding: 'zlib', bytes: compressed)
        : (encoding: 'pdf', bytes: Uint8List.fromList(pdf));
  }

  static Uint8List decodePdf(List<int> bytes, {Object? encoding}) {
    if (bytes.length > maxPdfBytes) {
      throw const FormatException('Invalid archived PDF.');
    }
    final Uint8List pdf;
    if (encoding == null || encoding == 'pdf') {
      pdf = Uint8List.fromList(bytes);
    } else if (encoding == 'zlib') {
      try {
        pdf = _inflate(bytes);
      } on ArchiveException {
        throw const FormatException('Invalid compressed PDF.');
      } on RangeError {
        throw const FormatException('Invalid compressed PDF.');
      }
    } else {
      throw const FormatException('Unsupported archived PDF encoding.');
    }
    _validatePdf(pdf);
    return pdf;
  }

  static void _validatePdf(List<int> pdf) {
    const header = [37, 80, 68, 70, 45]; // %PDF-
    if (pdf.length < header.length || pdf.length > maxPdfBytes) {
      throw const FormatException('Invalid archived PDF.');
    }
    for (var i = 0; i < header.length; i++) {
      if (pdf[i] != header[i]) {
        throw const FormatException('Invalid archived PDF.');
      }
    }
  }

  static Uint8List _inflate(List<int> bytes) {
    if (bytes.length < 8) {
      throw const FormatException('Invalid compressed PDF.');
    }
    final input = InputMemoryStream(bytes, byteOrder: ByteOrder.bigEndian);
    final cmf = input.readByte();
    final flags = input.readByte();
    if ((cmf & 15) != 8 ||
        (cmf >> 4) > 7 ||
        (cmf * 256 + flags) % 31 != 0 ||
        (flags & 32) != 0) {
      throw const FormatException('Invalid compressed PDF.');
    }
    // The high-level web decoder inflates into an unbounded temporary buffer.
    // Feed archive's Dart inflater a bounded output for every literal and run.
    final output = _BoundedPdfOutput();
    final inflater = Inflate.lazy(input, output: output);
    while (inflater.inflateBlock()) {}
    if (input.length != 4 ||
        input.readUint32() != getAdler32(output.getBytes())) {
      throw const FormatException('Invalid compressed PDF.');
    }
    return Uint8List.fromList(output.getBytes());
  }
}

class _BoundedPdfOutput extends OutputMemoryStream {
  void _check(int count) {
    if (length + count > BillDocumentCodec.maxPdfBytes) {
      throw const FormatException('Archived PDF exceeds five MiB.');
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    _check(count);
    super.writeBackReference(distance, count);
  }
}
