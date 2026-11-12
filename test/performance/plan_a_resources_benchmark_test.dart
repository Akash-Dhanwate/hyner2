import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/features/sales/data/bill_pdf_service.dart';
import 'package:hyner/features/sales/data/local_bill_document_repository.dart';
import 'package:hyner/features/settings/domain/payment_settings.dart';
import 'package:image/image.dart' as raster;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'Plan A controlled host preparation and archive-access comparisons',
    () async {
      sqfliteFfiInit();
      const operations = 20;
      const repetitions = 5;
      final image = raster.Image(width: 512, height: 512, numChannels: 4);
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          image.setPixelRgba(x, y, x % 256, y % 256, (x * y) % 256, 255);
        }
      }
      final encoded = base64Encode(raster.encodePng(image));
      final settings = PaymentSettings(logoBase64: encoded);
      final cold = <int>[], reused = <int>[];
      for (var repetition = 0; repetition < repetitions; repetition++) {
        var timer = Stopwatch()..start();
        for (var i = 0; i < operations; i++) {
          final cache = BillBrandingCache();
          expect(cache.prepare(settings, compact: false).logo!.width, 512);
          cache.clear();
        }
        cold.add(timer.elapsedMicroseconds);
        timer = Stopwatch()..start();
        final cache = BillBrandingCache();
        for (var i = 0; i < operations; i++) {
          expect(cache.prepare(settings, compact: false).logo!.width, 512);
        }
        reused.add(timer.elapsedMicroseconds);
        cache.clear();
      }
      final folder = await Directory.systemTemp.createTemp(
        'hyner-archive-benchmark-',
      );
      final store = LocalBusinessDatabase(
        factory: databaseFactoryFfi,
        directory: folder.path,
      );
      addTearDown(() async {
        await store.close();
        await folder.delete(recursive: true);
      });
      final db = await store.databaseFor('synthetic-owner');
      await db.insert('sales', {
        'id': 'fixture',
        'currency': 'INR',
        'lines': '[]',
        'paymentStatus': 'unpaid',
        'createdAt': '2026-11-10T00:00:00.000Z',
      });
      final documents = LocalBillDocumentRepository(store);
      // Byte/codec fixture only, not a rendered-document performance claim.
      final bytes = Uint8List.fromList(
        utf8.encode('%PDF-1.7\n${List.filled(1024 * 1024, 'X').join()}\n%%EOF'),
      );
      await documents.saveDuplicate('synthetic-owner', 'fixture', bytes);
      final inflated = <int>[], metadata = <int>[];
      var decodedBytes = 0;
      for (var repetition = 0; repetition < repetitions; repetition++) {
        var timer = Stopwatch()..start();
        for (var i = 0; i < operations; i++) {
          final result = await documents.duplicate(
            'synthetic-owner',
            'fixture',
          );
          expect(result!.length, bytes.length);
          decodedBytes += result.length;
        }
        inflated.add(timer.elapsedMicroseconds);
        timer = Stopwatch()..start();
        for (var i = 0; i < operations; i++) {
          expect(
            await documents.hasDuplicate('synthetic-owner', 'fixture'),
            isTrue,
          );
        }
        metadata.add(timer.elapsedMicroseconds);
      }
      int median(List<int> values) {
        values.sort();
        return values[values.length ~/ 2];
      }

      final result = {
        'kind': 'controlled Flutter-test host microbenchmark; not Android RAM/FPS/startup',
        'operations_per_repetition': operations,
        'repetitions': repetitions,
        'branding': {
          'fresh_preparation_median_us': median(cold),
          'page_cache_median_us': median(reused),
          'preparations_per_repetition_before': operations,
          'preparations_per_repetition_after': 1,
          'fixture_png_bytes': base64Decode(encoded).length,
        },
        'archive': {
          'read_inflate_median_us': median(inflated),
          'metadata_median_us': median(metadata),
          'fixture_decoded_pdf_bytes': bytes.length,
          'decoded_bytes_all_repetitions_before': decodedBytes,
          'decoded_bytes_after': 0,
        },
        'process_pss_bytes': null,
        'battery_energy': null,
      };
      final output = File('build/optimization/resource-comparison.json');
      await output.parent.create(recursive: true);
      await output.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(result)}\n',
      );
      // Print only synthetic measurement data, never customer content.
      // ignore: avoid_print
      print(jsonEncode(result));
    },
    skip: !const bool.fromEnvironment('RUN_PLAN_A_BENCHMARKS'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
