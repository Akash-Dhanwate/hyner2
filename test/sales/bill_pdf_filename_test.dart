import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/sales/data/bill_pdf_filename.dart';
import 'package:hyner/features/quotations/domain/quotation.dart';
import 'package:hyner/features/sales/domain/sale.dart';

void main() {
  test('uses customer name and normalized mobile for ordinary bills', () {
    expect(
      billPdfFilename(
        customerName: 'Rahul Patil',
        customerPhone: '+91 98765-43210',
        saleId: 'internal-bill-id-1042',
      ),
      'Rahul Patil_919876543210.pdf',
    );
  });

  test('sanitizes path and reserved characters while preserving Unicode', () {
    expect(
      billPdfFilename(
        customerName: 'शर्मा/जी:*?',
        customerPhone: '9876543210',
        saleId: 'bill-123456',
      ),
      'शर्मा_जी_9876543210.pdf',
    );
  });

  test('uses a short bill fallback when name or mobile is unavailable', () {
    expect(
      billPdfFilename(
        customerName: '',
        customerPhone: '9876543210',
        saleId: 'internal-bill-id-1042',
      ),
      'Bill_9876543210_1042.pdf',
    );
    expect(
      billPdfFilename(
        customerName: 'Amit Hardware',
        customerPhone: null,
        saleId: 'bill-123456',
        includeMobile: false,
      ),
      'Amit Hardware_123456.pdf',
    );
  });

  test('separates duplicate copies and caps lengthy customer names', () {
    expect(
      billPdfFilename(
        customerName: 'Amit',
        customerPhone: '9123456780',
        saleId: 'sale-1',
        duplicate: true,
      ),
      'Amit_9123456780_Duplicate.pdf',
    );
    final filename = billPdfFilename(
      customerName: List.filled(20, 'Very long customer').join(' '),
      customerPhone: '9123456780',
      saleId: 'sale-1',
    );
    expect(filename.endsWith('.pdf'), isTrue);
    expect(filename.length, lessThan(100));
  });

  test('quotation export uses its own readable, phone-free convention', () {
    final quote = Quotation(
      id: 'quotation-123456',
      createdAt: DateTime.utc(2026, 1, 1),
      draft: SaleDraft(
        currency: 'INR',
        lines: [
          SaleLine(sku: 'DOOR', name: 'Door', unitPriceMinor: 100, quantity: 1),
        ],
        customerName: 'Asha/Patil',
        customerPhone: '9876543210',
        initialPaymentMinor: 0,
      ),
    );
    expect(quotationPdfFilename(quote), 'Quotation_Asha_Patil_123456.pdf');
  });
}
