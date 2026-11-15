import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/features/pricing/application/calculator_session.dart';
import 'package:hyner/features/pricing/application/estimate_builder.dart';
import 'package:hyner/features/quotations/data/local_quotation_repository.dart';
import 'package:hyner/features/quotations/domain/quotation.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/sales/data/bill_pdf_service.dart';
import 'package:hyner/features/settings/data/local_payment_settings_repository.dart';
import 'package:hyner/features/settings/domain/payment_settings.dart';

import 'support/setup_fixture.dart' as f;

QuickPriceEstimate quotationEstimate({
  int count = 10,
  String business = 'shop',
}) {
  final session = CalculatorSession();
  var estimate = QuickPriceEstimate.empty(business);
  try {
    for (var i = 0; i < count; i++) {
      final product = f
          .setup(
            'area',
            name: i.isEven ? 'Laminated door' : 'Flush door',
            rate: i.isEven ? '155' : '150',
          )
          .compile(business, f.currency);
      session.select(product);
      session.change('height', 'text', '${6 + (i % 3)}');
      session.change('width', 'text', i.isEven ? '3' : '2.5');
      session.changeQuantity('${i % 3 + 1}');
      estimate = estimate.append(
        EstimateLine.capture(session: session, profileId: 'doors'),
      );
    }
    return estimate;
  } finally {
    session.dispose();
  }
}

String pdfText(Uint8List bytes) {
  final decoded = <String>[];
  for (final m in RegExp(
    r'stream\r?\n(.*?)\r?\nendstream',
    dotAll: true,
  ).allMatches(latin1.decode(bytes))) {
    final raw = latin1.encode(m[1]!);
    try {
      decoded.add(latin1.decode(zlib.decode(raw)));
    } on FormatException {
      decoded.add(latin1.decode(raw));
    }
  }
  return RegExp(r'\((?:\\.|[^\\)])*\)')
      .allMatches(decoded.join('\n'))
      .map((m) => m[0]!.substring(1, m[0]!.length - 1))
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory folder;
  late LocalBusinessDatabase store;
  late LocalQuotationRepository repository;
  late Quotation quote;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('hyner-quotations-');
    store = LocalBusinessDatabase(
      factory: databaseFactoryFfi,
      directory: folder.path,
    );
    repository = LocalQuotationRepository(store);
    final estimate = quotationEstimate();
    quote = Quotation(
      id: 'Q-SAMPLE',
      createdAt: DateTime.utc(2026, 11, 12, 10, 30),
      draft: SaleDraft(
        currency: 'INR',
        customerName: 'Sudip Buyer',
        customerPhone: '9876543210',
        customerAddress: 'Main market',
        initialPaymentMinor: 0,
        lines: estimate.toCheckoutSeed('owner').lines,
      ),
    );
  });
  tearDown(() async {
    await store.close();
    await folder.delete(recursive: true);
  });
  test('ten quoted items round-trip exactly without sales, stock, payments or customer writes; backup restores them', () async {
    await repository.save('owner', quote);
    await repository.save('owner', quote);
    expect(await repository.list('owner'), hasLength(1));
    final loaded = await repository.get('owner', quote.id);
    expect(loaded.draft.matches(quote.draft), isTrue);
    expect(loaded.draft.lines, hasLength(10));
    expect(loaded.draft.lines.every((line) => !line.stockTracked), isTrue);
    final db = await store.databaseFor('owner');
    for (final table in [
      'sales',
      'movements',
      'customers',
      'products',
      'bill_documents',
    ]) {
      expect(await db.query(table), isEmpty);
    }
    expect(await repository.list('another-owner'), isEmpty);
    await expectLater(
      repository.get('another-owner', quote.id),
      throwsA(anything),
    );
    final backup = await store.exportFor('owner');
    await store.restoreFor('owner', backup);
    expect(
      (await repository.get('owner', quote.id)).draft.matches(quote.draft),
      isTrue,
    );
  });
  test('history pages load compact metadata with stable cursors while full item snapshots remain available', () async {
    for (var i = 0; i < 65; i++) {
      await repository.save(
        'owner',
        Quotation(
          id: 'Q-${i.toString().padLeft(3, '0')}',
          createdAt: quote.createdAt,
          draft: quote.draft,
        ),
      );
    }
    final ids = <String>[];
    String? beforeTime, beforeId;
    while (true) {
      final page = await repository.list(
        'owner',
        beforeTime: beforeTime,
        beforeId: beforeId,
      );
      if (page.isEmpty) break;
      expect(page.length, lessThanOrEqualTo(30));
      expect(
        page.every(
          (row) =>
              row['description'] == 'Items from QuickPrice' &&
              row['hasSnapshot'] == 1,
        ),
        isTrue,
      );
      ids.addAll(page.map((row) => row['id']! as String));
      beforeTime = page.last['createdAt']! as String;
      beforeId = page.last['id']! as String;
    }
    expect(ids, hasLength(65));
    expect(ids.toSet(), hasLength(65));
    expect(
      (await repository.get('owner', ids.last)).draft.lines,
      hasLength(10),
    );
  });

  test(
    'same reference cannot replace a saved offer or accept corrupted totals',
    () async {
      await repository.save('owner', quote);
      final changed = Quotation(
        id: quote.id,
        createdAt: quote.createdAt,
        draft: SaleDraft(
          currency: 'INR',
          lines: quote.draft.lines,
          customerName: 'Another customer',
          customerPhone: '9876543211',
          initialPaymentMinor: 0,
        ),
      );
      await expectLater(repository.save('owner', changed), throwsA(anything));
      final row = quote.toRow();
      row['totalMinor'] = quote.draft.totalMinor + 1;
      expect(() => Quotation.fromRow(row), throwsA(anything));
      expect(
        (await repository.get('owner', quote.id)).draft.customerName,
        'Sudip Buyer',
      );
    },
  );
  test('legacy quotation descriptions remain readable as legacy records', () {
    expect(
      Quotation.fromRow({'description': 'Previous quotation description'}),
      isNull,
    );
    expect(Quotation.fromRow({'description': '{legacy text}'}), isNull);
  });
  test('third style persists, old style names remain compatible, and unrelated settings survive', () async {
    final settings = LocalPaymentSettingsRepository(store);
    final db = await store.databaseFor('owner');
    await db.insert('settings', {
      'key': 'bill-contact-edit/old/audit',
      'value': 'preserve',
    });
    for (final layout in BillLayout.values) {
      await settings.save(
        'owner',
        PaymentSettings(merchantName: 'Sample business', billLayout: layout),
      );
      expect((await settings.read('owner')).billLayout, layout);
    }
    expect(
      (await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['bill-contact-edit/old/audit'],
      )).single['value'],
      'preserve',
    );
  });
  for (final layout in BillLayout.values) {
    for (final quotation in [true, false]) {
      test(
        '${layout.name} ${quotation ? 'quotation' : 'bill'} preserves every quoted amount and removes copy badges',
        () async {
          final bytes = await BillPdfService.build(
            sale: quote.document,
            settings: PaymentSettings(
              merchantName: 'Hyner Hardware',
              businessPhone: '9000000000',
              businessAddress: 'Market road',
              billLayout: layout,
            ),
            quotation: quotation,
          );
          final text = pdfText(bytes);
          expect(text, contains('Hyner Hardware'));
          expect(text, contains('Sudip Buyer'));
          expect(text, contains('9876543210'));
          expect(text, contains('Main market'));
          expect(
            text,
            contains(
              'INR ${quote.draft.totalMinor ~/ 100}.${(quote.draft.totalMinor % 100).toString().padLeft(2, '0')}',
            ),
          );
          expect(text, isNot(contains('Original')));
          expect(text, isNot(contains('Duplicate')));
          expect(text, isNot(contains('unitCostMinor')));
          expect(text, isNot(contains('calculatorState')));
          expect(text, isNot(contains('BILL')));
          expect(text.contains('QUOTATION'), quotation);
          expect(text.contains('Balance due'), !quotation);
          expect(text.contains('Payment status:'), !quotation);
          for (final line in quote.draft.lines) {
            expect(text, contains(line.name));
          }
          expect(
            text.indexOf('Sudip Buyer'),
            lessThan(text.indexOf('12/11/2026')),
          );
          if (const bool.fromEnvironment('CAPTURE_QUOTATION_PDFS')) {
            final file = File(
              'build/quotation-release/pdf/${quotation ? 'quotation' : 'bill'}-${layout.name}.pdf',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes);
          }
        },
      );
    }
  }
}
