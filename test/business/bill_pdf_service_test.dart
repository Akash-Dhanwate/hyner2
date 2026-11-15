import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/sales/data/bill_pdf_service.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/settings/domain/payment_settings.dart';

import 'support/quickprice_sales_fixture.dart';

void main() {
  final sale = Sale(
    id: 'BILL-2026-001',
    createdAt: DateTime.utc(2026, 11, 9, 10),
    paidMinor: 5005,
    paymentStatus: PaymentStatus.partial,
    draft: SaleDraft(
      currency: 'INR',
      customerId: 'ASHA-CUSTOMER-9876543210-ABC123',
      customerName: 'Asha Customer',
      customerPhone: '9876543210',
      customerAddress: '42 Market Road, Pune',
      lines: [
        SaleLine(
          sku: 'MEASURED-1',
          name: 'Custom measured panel',
          unitPriceMinor: 12555,
          unitCostMinor: 9999,
          quantity: 2,
          parameters: const [
            ProductParameter(name: 'Height', value: '84 in'),
            ProductParameter(name: 'Width', value: '36 in'),
            ProductParameter(name: 'Material', value: 'WPC'),
            ProductParameter(name: 'Finish', value: 'Polished'),
          ],
        ),
        SaleLine(
          sku: 'PIPE',
          name: 'Steel pipe',
          unitPriceMinor: 2525,
          quantity: 1,
          parameters: const [
            ProductParameter(name: 'Length', value: '2.5 m'),
            ProductParameter(name: 'Diameter', value: '20 mm'),
          ],
        ),
      ],
    ),
  );
  // A tiny embedded fixture keeps logo/signature testing entirely offline.
  const pixel =
      'iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAYAAACinX6EAAAAeklEQVR4nO3QoQ3EMADAwKzxk3SX3589flLSbhAWXaoaGFqyPD7H95rx+59Tnu4PHaD9BugA7TdAB2i/ATpA+2P3wNV+A3SA9hugA7TfAB2g/QbsHrjab4AO0H4DdID2G6ADtN+A3QNX+w3QAdpvgA7QfgN0gPZfP+AGMSEJS8b9bscAAAAASUVORK5CYII=';
  const settings = PaymentSettings(
    merchantName: 'Hyner Hardware',
    businessPhone: '9000000000',
    businessAddress: 'Main Road, Pune',
    billLayout: BillLayout.centered,
    logoBase64: pixel,
    signatureBase64: pixel,
  );

  test(
    'branding pixels are reused by variant without retaining PDF providers',
    () async {
      final cache = BillBrandingCache();
      final first = cache.prepare(settings, compact: false);
      expect(identical(first, cache.prepare(settings, compact: false)), isTrue);
      expect(first.logo, isNotNull);
      expect(
        identical(first.logo, first.logo),
        isFalse,
      ); // Fresh provider cannot retain the preceding document.
      expect(identical(first, cache.prepare(settings, compact: true)), isFalse);
      final bytes = await BillPdfService.build(
        sale: sale,
        settings: settings,
        brandingCache: cache,
      );
      final again = await BillPdfService.build(
        sale: sale,
        settings: settings,
        brandingCache: cache,
      );
      expect(_content(bytes), _content(again));
      final replaced = cache.prepare(
        const PaymentSettings(logoBase64: 'broken'),
        compact: false,
      );
      expect(replaced.logo, isNull);
      expect(replaced.signature, isNull);
      expect(
        identical(first, cache.prepare(settings, compact: false)),
        isFalse,
      );
      final beforeClear = cache.prepare(settings, compact: false);
      cache.clear();
      expect(
        identical(beforeClear, cache.prepare(settings, compact: false)),
        isFalse,
      );
    },
  );

  for (final copy in BillCopy.values) {
    test(
      '$copy contains only its intended document and exact selling amounts',
      () async {
        final bytes = await BillPdfService.build(
          sale: sale,
          settings: settings,
          copy: copy,
        );
        expect(_pages(bytes), 1);
        final text = _content(bytes);
        expect(text, isNot(contains('Original')));
        expect(text, isNot(contains('Duplicate')));
        expect(
          text,
          isNot(contains(copy == BillCopy.original ? 'Duplicate' : 'Original')),
        );
        expect(text, isNot(contains('Customer Copy')));
        expect(text, isNot(contains('Seller Copy')));
        expect('Asha Customer'.allMatches(text), hasLength(1));
        expect(text, contains('Mobile: 9876543210'));
        expect(text, contains('42 Market Road, Pune'));
        expect(text, contains('ASHA-CUSTOMER-9876543210-ABC123'));
        for (final specification in [
          'Height: 84 in',
          'Width: 36 in',
          'Material: WPC',
          'Length: 2.5 m',
          'Diameter: 20 mm',
        ]) {
          expect(text, contains(specification));
        }
        for (final amount in [
          'INR 125.55',
          'INR 251.10',
          'INR 25.25',
          'INR 276.35',
          'INR 50.05',
          'INR 226.30',
        ]) {
          expect(text, contains(amount));
        }
        expect(text, isNot(contains('99.99'))); // purchase cost remains private
        expect(text, contains('Authorized signature'));
        expect(
          RegExp(r'/Subtype\s*/Image').hasMatch(latin1.decode(bytes)),
          isTrue,
        );
        if (const bool.fromEnvironment('CAPTURE_BILL_PDF')) {
          final folder = Directory('build/verification/ux-0.5.0')
            ..createSync(recursive: true);
          File('${folder.path}/bill-${copy.name}.pdf').writeAsBytesSync(bytes);
        }
      },
    );
  }

  test('shared bill uses independent section colours', () async {
    final bytes = await BillPdfService.build(
      sale: sale,
      settings: const PaymentSettings(
        merchantName: 'Hyner Hardware',
        businessPhone: '9000000000',
        businessAddress: 'Main Road, Pune',
        fontColors: {
          BillTextSection.businessName: 0xc62828,
          BillTextSection.customer: 0x1565c0,
          BillTextSection.items: 0x000000,
          BillTextSection.totals: 0x2e7d32,
        },
      ),
    );
    final content = _content(bytes);
    expect(content, contains('Hyner Hardware'));
    expect(content, contains('INR 276.35'));
    expect(_streams(bytes), contains('0.77647 0.15686 0.15686 rg'));
    expect(_streams(bytes), contains('0.08235 0.39608 0.75294 rg'));
    expect(_streams(bytes), contains('0 0 0 rg'));
    if (const bool.fromEnvironment('CAPTURE_BILL_PDF')) {
      final folder = Directory('build/verification/ux-0.6.0')
        ..createSync(recursive: true);
      File('${folder.path}/bill-colours.pdf').writeAsBytesSync(bytes);
    }
  });

  test(
    'default PDF omits copy badges and missing branding has a usable title',
    () async {
      final bytes = await BillPdfService.build(
        sale: sale,
        settings: const PaymentSettings(),
      );
      final text = _content(bytes);
      expect(text, isNot(contains('Original')));
      expect(text, isNot(contains('Duplicate')));
      expect(text, contains('Sales bill'));
      expect(text, isNot(contains('not configured')));
    },
  );

  test(
    'corrupt legacy logo and signature cannot stop bill generation',
    () async {
      final bytes = await BillPdfService.build(
        sale: sale,
        settings: const PaymentSettings(
          logoBase64: 'broken!',
          signatureBase64: 'broken!',
        ),
      );
      expect(_content(bytes), contains('INR 276.35'));
    },
  );

  for (final copy in BillCopy.values) {
    test(
      '$copy paginates a single item with maximum-length specifications',
      () async {
        final detailed = Sale(
          id: 'detailed',
          createdAt: DateTime.utc(2026, 11, 9),
          draft: SaleDraft(
            currency: 'INR',
            lines: [
              SaleLine(
                sku: 'PANEL',
                name: 'Custom panel',
                quantity: 1,
                unitPriceMinor: 25025,
                parameters: List.generate(
                  20,
                  (i) => ProductParameter(
                    name: 'Specification $i',
                    value: List.filled(12, 'Measured').join(' '),
                  ),
                ),
              ),
            ],
          ),
        );
        final bytes = await BillPdfService.build(
          sale: detailed,
          settings: settings,
          copy: copy,
        );
        expect(_pages(bytes), greaterThan(1));
        final text = _content(bytes);
        for (var i = 0; i < 20; i++) {
          expect(text, contains('Specification $i:'));
        }
        expect(text, contains('INR 250.25'));
      },
    );
  }

  for (final copy in BillCopy.values) {
    test(
      '$copy preserves QuickPrice tax, discount and nondivisible unit totals',
      () async {
        final original = measuredSaleLine(0);
        final quoted = SaleLine(
          sku: original.sku,
          name: 'Custom quoted panel',
          unitPriceMinor: original.unitPriceMinor,
          quantity: original.quantity,
          pricing: original.pricing,
          parameters: const [
            ProductParameter(name: 'Width', value: '1 ft'),
            ProductParameter(name: 'Height', value: '1 ft'),
            ProductParameter(name: 'Tax', value: '18% exclusive (₹0.52)'),
          ],
        );
        final priced = Sale(
          id: 'quoted-bill',
          createdAt: DateTime.utc(2026, 11, 9),
          draft: customSaleDraft([quoted]),
          paymentStatus: PaymentStatus.unpaid,
        );
        final bytes = await BillPdfService.build(
          sale: priced,
          settings: settings,
          copy: copy,
        );
        final text = _content(bytes);
        expect(text, contains('INR 3.40'));
        expect(text, contains('INR 2.88'));
        expect(text, contains('INR 0.52'));
        expect(text, contains('INR 0.16'));
        expect(text, contains('~ INR 1.13'));
        expect(text, contains('Approximate unit price; line amount is final.'));
        expect(text, contains('18% exclusive'));
        expect(text, isNot(contains('unitCostMinor')));
        expect(priced.draft.totalMinor, 340);
      },
    );
  }

  for (final layout in BillLayout.values) {
    for (final copy in BillCopy.values) {
      test(
        '100-line $layout $copy invoice retains every specification',
        () async {
          final longSale = Sale(
            id: 'long-invoice',
            createdAt: DateTime.utc(2026, 11, 9),
            draft: SaleDraft(
              currency: 'INR',
              customerId: 'customer1',
              customerName: 'Asha Customer',
              lines: List.generate(
                100,
                (index) => SaleLine(
                  sku: 'ITEM-$index',
                  name: 'Invoice item ${index.toString().padLeft(3, '0')}',
                  unitPriceMinor: 12555,
                  quantity: 2,
                  parameters: const [
                    ProductParameter(name: 'Finish', value: 'Polished'),
                  ],
                ),
              ),
            ),
          );
          final bytes = await BillPdfService.build(
            sale: longSale,
            copy: copy,
            settings: PaymentSettings(
              merchantName: 'Hyner Hardware and Building Materials Supplies - Main Market Business Branch',
              billLayout: layout,
              headerFontSize: 32,
              footerText: 'Long invoice complete',
            ),
          );
          expect(_pages(bytes), greaterThan(1));
          final text = _content(bytes);
          for (var index = 0; index < 100; index++) {
            expect(
              'Invoice item ${index.toString().padLeft(3, '0')}'.allMatches(
                text,
              ),
              hasLength(1),
            );
          }
          expect('Finish: Polished'.allMatches(text), hasLength(100));
          expect('Long invoice complete'.allMatches(text), hasLength(1));
          expect(text, contains('INR 25110.00'));
          expect(
            text,
            isNot(
              contains(copy == BillCopy.original ? 'Duplicate' : 'Original'),
            ),
          );
        },
      );
    }
  }
}

int _pages(Uint8List bytes) =>
    RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;

// PDF content streams are compressed. Inflate them to verify that the final
// product and final footer are present in the document, not just the page count.
String _streams(Uint8List bytes) {
  final source = latin1.decode(bytes);
  final decoded = <String>[];
  for (final match in RegExp(
    r'stream\r?\n(.*?)\r?\nendstream',
    dotAll: true,
  ).allMatches(source)) {
    final stream = latin1.encode(match[1]!);
    try {
      decoded.add(latin1.decode(zlib.decode(stream)));
    } on FormatException {
      decoded.add(latin1.decode(stream));
    }
  }
  return decoded.join('\n');
}

String _content(Uint8List bytes) {
  return RegExp(r'\((?:\\.|[^\\)])*\)')
      .allMatches(_streams(bytes))
      .map((match) => match[0]!.substring(1, match[0]!.length - 1))
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}
