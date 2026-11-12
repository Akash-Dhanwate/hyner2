import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/features/inventory/data/local_inventory_repository.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/sales/data/bill_document_codec.dart';
import 'package:hyner/features/sales/data/local_bill_document_repository.dart';
import 'package:hyner/features/sales/data/local_sales_repository.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late LocalBusinessDatabase store;
  late LocalBillDocumentRepository documents;
  const uid = 'owner';

  Uint8List pdf(String body) =>
      Uint8List.fromList(utf8.encode('%PDF-1.7\n$body\n%%EOF'));

  Future<void> seed(String account, String id) async {
    final inventory = LocalInventoryRepository(store);
    final db = await store.databaseFor(account);
    if ((await db.query('products')).isEmpty) {
      await inventory.create(
        account,
        ProductDraft(
          sku: 'A',
          name: 'Item A',
          currency: 'INR',
          costMinor: 50,
          priceMinor: 100,
          openingStock: 10,
          reorderLevel: 1,
        ),
        'opening',
      );
    }
    await LocalSalesRepository(store).create(
      account,
      id,
      SaleDraft(
        currency: 'INR',
        customerName: 'Asha Buyer',
        customerPhone: '9876543210',
        customerAddress: 'Invoice address',
        initialPaymentMinor: 0,
        lines: [SaleLine.fromProduct(await inventory.get(account, 'A'), 1)],
      ),
    );
  }

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hyner-bill-document-');
    store = LocalBusinessDatabase(
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    documents = LocalBillDocumentRepository(store);
    await seed(uid, 'bill');
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  test(
    'metadata lookup and concurrent generation keep one immutable archive',
    () async {
      await seed(uid, 'single-flight');
      var generated = 0;
      final gate = Completer<void>();
      final first = pdf('original archived content');
      Future<Uint8List> generate() async {
        generated++;
        await gate.future;
        return first;
      }

      final jobs = [
        documents.ensureDuplicate(uid, 'single-flight', generate),
        documents.ensureDuplicate(uid, 'single-flight', generate),
      ];
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future.wait(jobs);
      expect(generated, 1);
      expect(await documents.hasDuplicate(uid, 'single-flight'), isTrue);
      expect(
        await documents.duplicate(uid, 'single-flight'),
        orderedEquals(first),
      );
      await documents.ensureDuplicate(uid, 'single-flight', () async {
        fail('Existing archive must not be regenerated');
      });
      final db = await store.databaseFor(uid);
      await db.update(
        'bill_documents',
        {
          'duplicatePdf': Uint8List.fromList([1, 2, 3]),
          'encoding': 'pdf',
        },
        where: 'saleId = ?',
        whereArgs: ['single-flight'],
      );
      expect(await documents.hasDuplicate(uid, 'single-flight'), isTrue);
      await expectLater(
        documents.duplicate(uid, 'single-flight'),
        throwsFormatException,
      );
    },
  );

  test(
    'failed archive job can retry and account jobs remain separate',
    () async {
      await seed(uid, 'retry');
      await seed('other', 'retry');
      await expectLater(
        documents.ensureDuplicate(
          uid,
          'retry',
          () async => throw StateError('retryable'),
        ),
        throwsStateError,
      );
      final first = pdf('owner archive'), second = pdf('other account');
      await Future.wait([
        documents.ensureDuplicate(uid, 'retry', () async => first),
        documents.ensureDuplicate('other', 'retry', () async => second),
      ]);
      expect(await documents.duplicate(uid, 'retry'), orderedEquals(first));
      expect(
        await documents.duplicate('other', 'retry'),
        orderedEquals(second),
      );
      expect(await documents.hasDuplicate('other', 'missing'), isFalse);
    },
  );

  test(
    'archive is durable, first-write-wins, and returns independent bytes',
    () async {
      expect(await documents.duplicate(uid, 'bill'), isNull);
      final original = pdf('original duplicate');
      await documents.saveDuplicate(uid, 'bill', original);
      final db = await store.databaseFor(uid);
      final before = (await db.query('bill_documents')).single;
      await Future.wait([
        documents.saveDuplicate(uid, 'bill', pdf('replacement one')),
        documents.saveDuplicate(uid, 'bill', pdf('replacement two')),
      ]);
      expect((await db.query('bill_documents')).single, before);
      final read = (await documents.duplicate(uid, 'bill'))!;
      expect(read, orderedEquals(original));
      read[0] = 0;
      await store.close();
      expect(await documents.duplicate(uid, 'bill'), orderedEquals(original));
    },
  );

  test('real two-line invoice stores a smaller zlib BLOB and returns the exact PDF', () async {
    // Captured from the rendered A5 Duplicate fixture, including embedded fonts.
    final bytes = await File('test/fixtures/bill_duplicate.pdf').readAsBytes();
    await documents.saveDuplicate(uid, 'bill', bytes);
    final db = await store.databaseFor(uid);
    final row = (await db.query('bill_documents')).single;
    final archived = row['duplicatePdf']! as List<int>;
    expect(row['encoding'], 'zlib');
    expect(archived.length, lessThan(bytes.length));
    expect(archived.length, lessThan(bytes.length * 0.75));
    expect(await documents.duplicate(uid, 'bill'), orderedEquals(bytes));
    final snapshot = jsonDecode(
      jsonEncode(await store.exportFor(uid)),
    ) as Map<String, dynamic>;
    final encodedRow =
        ((snapshot['tables'] as Map)['bill_documents'] as List).single as Map;
    expect(encodedRow['encoding'], 'zlib');
    expect(
      base64Decode(encodedRow['duplicatePdf']! as String),
      orderedEquals(archived),
    );
    await store.restoreFor(uid, snapshot);
    await store.close();
    expect(await documents.duplicate(uid, 'bill'), orderedEquals(bytes));
    expect(
      (await (await store.databaseFor(uid)).query('bill_documents')).single,
      row,
    );
  });

  test('incompressible PDF stays raw and legacy raw backups need no encoding field', () async {
    final tiny = Uint8List.fromList(ascii.encode('%PDF-'));
    await documents.saveDuplicate(uid, 'bill', tiny);
    final db = await store.databaseFor(uid);
    final raw = (await db.query('bill_documents')).single;
    expect(raw['encoding'], 'pdf');
    expect(raw['duplicatePdf'], orderedEquals(tiny));
    await db.delete('bill_documents');
    final legacy = pdf('legacy raw document');
    await db.insert('bill_documents', {
      'saleId': 'bill',
      'duplicatePdf': legacy,
      'createdAt': DateTime.utc(2023).toIso8601String(),
    });
    expect((await db.query('bill_documents')).single['encoding'], 'pdf');
    expect(await documents.duplicate(uid, 'bill'), orderedEquals(legacy));
    final snapshot = await store.exportFor(uid);
    final tables = Map<String, Object?>.from(snapshot['tables'] as Map);
    tables['bill_documents'] = [
      for (final row in tables['bill_documents'] as List)
        Map<String, Object?>.from(row as Map)..remove('encoding'),
    ];
    await store.restoreFor(uid, {...snapshot, 'tables': tables});
    expect(await documents.duplicate(uid, 'bill'), orderedEquals(legacy));
  });

  test('bounded Dart decoder rejects expansion bombs, checksum damage, and truncated streams', () {
    final oversized = Uint8List(BillDocumentCodec.maxPdfBytes + 1)
      ..setRange(0, 5, ascii.encode('%PDF-'));
    final bomb = const ZLibEncoderWeb().encodeBytes(oversized);
    expect(bomb.length, lessThan(10000));
    expect(
      () => BillDocumentCodec.decodePdf(bomb, encoding: 'zlib'),
      throwsFormatException,
    );
    final bytes = pdf(List.filled(100, 'invoice data').join());
    final packed = const ZLibEncoderWeb().encodeBytes(bytes);
    final damaged = Uint8List.fromList(packed)..[packed.length - 1] ^= 1;
    for (final invalid in [
      damaged,
      packed.sublist(0, packed.length - 1),
      [...packed, 0],
      const ZLibEncoderWeb().encodeBytes(ascii.encode('not a PDF')),
    ]) {
      expect(
        () => BillDocumentCodec.decodePdf(invalid, encoding: 'zlib'),
        throwsFormatException,
      );
    }
    expect(
      () => BillDocumentCodec.decodePdf(bytes, encoding: 'unknown'),
      throwsFormatException,
    );
  });

  test('concurrent first writes retain exactly one complete PDF', () async {
    final first = pdf('first');
    final second = pdf('second');
    await Future.wait([
      documents.saveDuplicate(uid, 'bill', first),
      documents.saveDuplicate(uid, 'bill', second),
    ]);
    final archived = await documents.duplicate(uid, 'bill');
    expect(archived, anyOf(orderedEquals(first), orderedEquals(second)));
    expect(
      await (await store.databaseFor(uid)).query('bill_documents'),
      hasLength(1),
    );
  });

  test('archive rejects malformed, oversized, and unsaved documents without writes', () async {
    final tooLarge = Uint8List(5 * 1024 * 1024 + 1)
      ..setRange(0, 5, ascii.encode('%PDF-'));
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList([37, 80, 68, 70]),
      Uint8List.fromList(ascii.encode('wrong header')),
      Uint8List.fromList([255, 255, 255, 255, 255]),
      tooLarge,
    ]) {
      await expectLater(
        documents.saveDuplicate(uid, 'bill', bytes),
        throwsFormatException,
      );
    }
    await expectLater(
      documents.saveDuplicate(uid, 'missing', pdf('orphan')),
      throwsStateError,
    );
    expect(
      await (await store.databaseFor(uid)).query('bill_documents'),
      isEmpty,
    );
  });

  test('archive size limit accepts exactly five MiB', () async {
    final bytes = Uint8List(5 * 1024 * 1024)
      ..setRange(0, 5, ascii.encode('%PDF-'));
    await documents.saveDuplicate(uid, 'bill', bytes);
    expect(await documents.duplicate(uid, 'bill'), orderedEquals(bytes));
    final snapshot = jsonDecode(
      jsonEncode(await store.exportFor(uid)),
    ) as Map<String, dynamic>;
    await store.restoreFor(uid, snapshot);
    expect(await documents.duplicate(uid, 'bill'), orderedEquals(bytes));
  });

  test(
    'archive enforces its sale reference and cascades on sale deletion',
    () async {
      final db = await store.databaseFor(uid);
      await expectLater(
        db.insert('bill_documents', {
          'saleId': 'missing',
          'duplicatePdf': pdf('orphan'),
          'createdAt': DateTime.utc(2026).toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
      await documents.saveDuplicate(uid, 'bill', pdf('duplicate'));
      await db.delete('sales', where: 'id = ?', whereArgs: ['bill']);
      expect(await documents.duplicate(uid, 'bill'), isNull);
      expect(await db.query('bill_documents'), isEmpty);
    },
  );

  test('JSON backup round-trip restores exact archive, customer links, and stock snapshot', () async {
    final bytes = pdf('original saved duplicate');
    await documents.saveDuplicate(uid, 'bill', bytes);
    final db = await store.databaseFor(uid);
    final archive = (await db.query('bill_documents')).single;
    final snapshot = jsonDecode(
      jsonEncode(await store.exportFor(uid)),
    ) as Map<String, dynamic>;
    expect(snapshot['schemaVersion'], 10);
    final tables = snapshot['tables'] as Map;
    expect(
      (tables['bill_documents'] as List).single['duplicatePdf'],
      base64Encode(archive['duplicatePdf']! as List<int>),
    );
    expect(
      (tables['bill_documents'] as List).single['encoding'],
      archive['encoding'],
    );
    await seed(uid, 'later_bill');
    await documents.saveDuplicate(uid, 'later_bill', pdf('later duplicate'));
    await store.restoreFor(uid, snapshot);
    await store.close();
    expect((await store.exportFor(uid))['tables'], snapshot['tables']);
    expect(await documents.duplicate(uid, 'bill'), orderedEquals(bytes));
    expect(await documents.duplicate(uid, 'later_bill'), isNull);
    expect(
      (await (await store.databaseFor(uid)).query('bill_documents')).single,
      archive,
    );
    final sales = LocalSalesRepository(store);
    final saved = await sales.get(uid, 'bill');
    expect(saved.draft.customerId, (tables['customers'] as List).single['id']);
    expect(
      (await sales.forCustomer(uid, saved.draft.customerId!)).single.id,
      'bill',
    );
  });

  test(
    'invalid archive restore rolls back all tables including existing PDFs',
    () async {
      await documents.saveDuplicate(uid, 'bill', pdf('keep existing archive'));
      final snapshot = await store.exportFor(uid);
      final before = snapshot['tables'];
      final tables = Map<String, Object?>.from(before as Map);
      final original = Map<String, Object?>.from(
        (tables['bill_documents'] as List).single as Map,
      );
      final tooLarge = Uint8List(5 * 1024 * 1024 + 1)
        ..setRange(0, 5, ascii.encode('%PDF-'));
      final bomb = const ZLibEncoderWeb().encodeBytes(tooLarge);
      final invalidRows = [
        {...original, 'duplicatePdf': '%%%invalid base64'},
        {...original, 'duplicatePdf': base64Encode(ascii.encode('not a pdf'))},
        {
          ...original,
          'duplicatePdf': base64Encode([255, 255, 255, 255, 255]),
        },
        {...original, 'duplicatePdf': base64Encode(tooLarge)},
        {...original, 'encoding': 'zlib', 'duplicatePdf': base64Encode(bomb)},
        {...original, 'encoding': 'unknown'},
        {
          ...original,
          'encoding': 'zlib',
          'duplicatePdf': base64Encode(ascii.encode('%PDF-raw')),
        },
        {...original, 'saleId': 'missing'},
      ];
      for (final row in invalidRows) {
        await expectLater(
          store.restoreFor(uid, {
            ...snapshot,
            'tables': {
              ...tables,
              'bill_documents': [row],
            },
          }),
          throwsA(anyOf(isA<FormatException>(), isA<DatabaseException>())),
        );
        expect((await store.exportFor(uid))['tables'], before);
      }
      for (final invalidTables in [
        {...tables}..remove('bill_documents'),
        {...tables, 'bill_documents': 'invalid table'},
      ]) {
        await expectLater(
          store.restoreFor(uid, {...snapshot, 'tables': invalidTables}),
          throwsFormatException,
        );
        expect((await store.exportFor(uid))['tables'], before);
      }
    },
  );

  test(
    'repository reads and backup export reject a corrupt compressed archive',
    () async {
      final db = await store.databaseFor(uid);
      await db.insert('bill_documents', {
        'saleId': 'bill',
        'duplicatePdf': Uint8List.fromList([120, 156, 0]),
        'encoding': 'zlib',
        'createdAt': DateTime.utc(2026).toIso8601String(),
      });
      await expectLater(
        documents.duplicate(uid, 'bill'),
        throwsFormatException,
      );
      await expectLater(store.exportFor(uid), throwsFormatException);
    },
  );

  test('archive and backup restore are isolated between accounts with the same bill ID', () async {
    await seed('other', 'bill');
    final ownerPdf = pdf('owner archive');
    final otherPdf = pdf('other archive');
    await documents.saveDuplicate(uid, 'bill', ownerPdf);
    expect(await documents.duplicate('other', 'bill'), isNull);
    await documents.saveDuplicate('other', 'bill', otherPdf);
    final otherBefore = (await store.exportFor('other'))['tables'];
    await expectLater(
      store.restoreFor('other', await store.exportFor(uid)),
      throwsFormatException,
    );
    expect((await store.exportFor('other'))['tables'], otherBefore);
    await store.close();
    expect(await documents.duplicate(uid, 'bill'), orderedEquals(ownerPdf));
    expect(await documents.duplicate('other', 'bill'), orderedEquals(otherPdf));
  });
}
