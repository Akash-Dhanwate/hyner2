import 'dart:typed_data';
import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:image/image.dart' as image;
import 'package:pdf/widgets.dart' as pw;

import '../../inventory/domain/product.dart';
import '../../settings/domain/payment_settings.dart';
import '../domain/sale.dart';
import '../../customers/domain/customer.dart';

enum BillCopy { original, duplicate }

class BillPdfService {
  static const _ink = PdfColor.fromInt(0xff19212b);
  static const _line = PdfColor.fromInt(0xffd9e0e7);
  static const _pale = PdfColor.fromInt(0xfff4f6f8);

  static Future<Uint8List> build({
    required Sale sale,
    required PaymentSettings settings,
    BillCopy copy = BillCopy.original,
  }) async {
    final document = pw.Document(
      title: 'Bill ${sale.id}',
      author: settings.merchantName.isEmpty ? 'Hyner' : settings.merchantName,
    );
    final label = copy == BillCopy.original ? 'Original' : 'Duplicate';
    final compact = copy == BillCopy.duplicate;
    final footerColor = PdfColor.fromInt(
      0xff000000 | settings.fontColor(BillTextSection.footer),
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: compact ? PdfPageFormat.a5 : PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(compact ? 22 : 36),
        maxPages: sale.draft.lines.fold<int>(
          20,
          (count, line) => count + 1 + line.parameters.length,
        ),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Text(
            '$label | Bill ${sale.id}',
            style: pw.TextStyle(color: footerColor, fontSize: 8),
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '$label | Page ${context.pageNumber}',
            style: pw.TextStyle(color: footerColor, fontSize: 8),
          ),
        ),
        build: (context) => _page(sale, settings, label, compact),
      ),
    );
    return document.save();
  }

  static List<pw.Widget> _page(
    Sale sale,
    PaymentSettings settings,
    String copy,
    bool compact,
  ) {
    PdfColor color(BillTextSection section) =>
        PdfColor.fromInt(0xff000000 | settings.fontColor(section));
    final nameColor = color(BillTextSection.businessName);
    final businessColor = color(BillTextSection.businessDetails);
    final billColor = color(BillTextSection.billDetails);
    final customerColor = color(BillTextSection.customer);
    final itemColor = color(BillTextSection.items);
    final totalColor = color(BillTextSection.totals);
    final footerColor = color(BillTextSection.footer);
    final centered = settings.billLayout == BillLayout.centered;
    final alignment = centered ? pw.Alignment.center : pw.Alignment.topRight;
    final textAlign = centered ? pw.TextAlign.center : pw.TextAlign.right;
    final business = settings.merchantName.trim().isEmpty
        ? 'Sales bill'
        : settings.merchantName.trim();
    final logo = _safeImage(settings.logoBase64, compact);
    final signature = _safeImage(settings.signatureBase64, compact);
    return [
      pw.Container(
        alignment: alignment,
        child: pw.Column(
          crossAxisAlignment: centered
              ? pw.CrossAxisAlignment.center
              : pw.CrossAxisAlignment.end,
          children: [
            pw.Row(
              mainAxisSize: pw.MainAxisSize.max,
              mainAxisAlignment: centered
                  ? pw.MainAxisAlignment.center
                  : pw.MainAxisAlignment.end,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null) ...[
                  pw.Image(
                    logo,
                    width: compact ? 30 : 42,
                    height: compact ? 30 : 42,
                  ),
                  pw.SizedBox(width: 10),
                ],
                pw.Flexible(
                  child: pw.Text(
                    business,
                    textAlign: textAlign,
                    style: pw.TextStyle(
                      color: nameColor,
                      fontSize: compact
                          ? 15
                          : settings.headerFontSize.clamp(14, 32),
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (settings.businessAddress.trim().isNotEmpty)
              pw.Text(
                settings.businessAddress.trim(),
                textAlign: textAlign,
                style: pw.TextStyle(color: businessColor, fontSize: 9),
              ),
            if (settings.businessPhone.trim().isNotEmpty)
              pw.Text(
                settings.businessPhone.trim(),
                textAlign: textAlign,
                style: pw.TextStyle(color: businessColor, fontSize: 9),
              ),
            if (settings.taxId.trim().isNotEmpty)
              pw.Text(
                'Tax ID: ${settings.taxId.trim()}',
                textAlign: textAlign,
                style: pw.TextStyle(color: businessColor, fontSize: 9),
              ),
          ],
        ),
      ),
      pw.SizedBox(height: compact ? 12 : 22),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BILL',
                  style: pw.TextStyle(
                    color: billColor,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: compact ? 2 : 4),
                pw.Text(
                  sale.id,
                  style: pw.TextStyle(color: billColor, fontSize: 10),
                ),
                pw.Text(
                  saleDate(sale.createdAt),
                  style: pw.TextStyle(color: billColor, fontSize: 9),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _pale,
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Text(
              copy,
              style: pw.TextStyle(
                color: billColor,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: compact ? 9 : 16),
      if (sale.draft.customerName != null)
        pw.Container(
          padding: pw.EdgeInsets.all(compact ? 6 : 10),
          decoration: pw.BoxDecoration(
            color: _pale,
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Customer',
                style: pw.TextStyle(color: customerColor, fontSize: 9),
              ),
              pw.Text(
                sale.draft.customerName!,
                style: pw.TextStyle(
                  color: customerColor,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (sale.draft.customerPhone?.trim().isNotEmpty == true)
                pw.Text(
                  'Mobile: ${sale.draft.customerPhone!}',
                  style: pw.TextStyle(color: customerColor, fontSize: 9),
                ),
              if (sale.draft.customerAddress?.trim().isNotEmpty == true)
                pw.Text(
                  sale.draft.customerAddress!,
                  style: pw.TextStyle(color: customerColor, fontSize: 9),
                ),
            ],
          ),
        ),
      if (sale.draft.customerId != null) ...[
        pw.SizedBox(height: compact ? 3 : 6),
        pw.Text(
          'Customer ID: ${customerReference(sale.draft.customerName ?? '', sale.draft.customerPhone ?? '', sale.draft.customerId!)}',
          style: pw.TextStyle(color: customerColor, fontSize: 8),
        ),
      ],
      pw.SizedBox(height: compact ? 10 : 18),
      pw.Table(
        border: const pw.TableBorder(bottom: pw.BorderSide(color: _line)),
        columnWidths: const {
          0: pw.FlexColumnWidth(4),
          1: pw.FlexColumnWidth(1),
          2: pw.FlexColumnWidth(2),
          3: pw.FlexColumnWidth(2),
        },
        children: [
          _row(
            ['Product / specifications', 'Qty', 'Unit price', 'Amount'],
            header: true,
            compact: compact,
            color: itemColor,
          ),
          for (final line in sale.draft.lines) ...[
            _row(
              [
                line.name,
                '${line.quantity}',
                '${line.pricing?.unitPriceRounded == true ? '~ ' : ''}${formatMoney(line.unitPriceMinor, sale.draft.currency)}',
                formatMoney(line.totalMinor, sale.draft.currency),
              ],
              compact: compact,
              color: itemColor,
            ),
            // Separate table rows can paginate even when one item has many
            // long specifications. A single oversized cell cannot split.
            for (final parameter in line.parameters)
              _row(
                [
                  _parameterText('${parameter.name}: ${parameter.value}'),
                  '',
                  '',
                  '',
                ],
                compact: compact,
                color: itemColor,
                specification: true,
              ),
            if (line.pricing?.unitPriceRounded == true)
              _row(
                ['Approximate unit price; line amount is final.', '', '', ''],
                compact: compact,
                color: itemColor,
                specification: true,
              ),
          ],
        ],
      ),
      pw.Inseparable(
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.SizedBox(height: compact ? 6 : 18),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (sale.draft.taxMinor > 0) ...[
                    _totalRow(
                      'Excl. tax',
                      sale.draft.netMinor,
                      sale.draft.currency,
                      color: totalColor,
                    ),
                    _totalRow(
                      'Tax',
                      sale.draft.taxMinor,
                      sale.draft.currency,
                      color: totalColor,
                    ),
                  ],
                  if (sale.draft.discountMinor > 0)
                    _totalRow(
                      'Discount included',
                      sale.draft.discountMinor,
                      sale.draft.currency,
                      color: totalColor,
                    ),
                  _totalRow(
                    'Total',
                    sale.draft.totalMinor,
                    sale.draft.currency,
                    color: totalColor,
                    large: true,
                  ),
                  _totalRow(
                    'Paid',
                    sale.paidMinor,
                    sale.draft.currency,
                    color: totalColor,
                  ),
                  _totalRow(
                    'Balance due',
                    sale.remainingMinor,
                    sale.draft.currency,
                    color: totalColor,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: compact ? (signature == null ? 2 : 8) : 24),
            if (signature != null)
              pw.Align(
                alignment: centered
                    ? pw.Alignment.center
                    : pw.Alignment.centerRight,
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Image(
                      signature,
                      width: compact ? 80 : 110,
                      height: compact ? 26 : 42,
                    ),
                    pw.Text(
                      'Authorized signature',
                      style: pw.TextStyle(color: footerColor, fontSize: 8),
                    ),
                  ],
                ),
              ),
            if (signature != null) pw.SizedBox(height: compact ? 4 : 8),
            if (!compact) pw.Divider(color: _line),
            if (!compact) pw.SizedBox(height: 8),
            pw.Text(
              'Payment status: ${sale.paymentStatus.name.toUpperCase()}  ·  ${settings.footerText.trim().isEmpty ? 'Thank you for your business.' : settings.footerText.trim()}',
              textAlign: centered ? pw.TextAlign.center : pw.TextAlign.left,
              style: pw.TextStyle(
                color: footerColor,
                fontSize: compact ? 7 : 9,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // Currency codes and ASCII approximation marks keep generated measurement
  // summaries legible with the built-in PDF font, including tax/discount specs.
  static String _parameterText(String text) =>
      text.replaceAll('₹', 'INR ').replaceAll('≈', '~');

  // Decode optional images before layout so a damaged legacy image cannot
  // abort invoice creation. Bound resolution and strip image metadata; the
  // archive uses a smaller image while preserving all financial content.
  static pw.ImageProvider? _safeImage(String encoded, bool compact) {
    if (encoded.isEmpty || encoded.length > 3 * 1024 * 1024) return null;
    try {
      final bytes = base64Decode(encoded);
      final decoder = image.findDecoderForData(bytes);
      final info = decoder?.startDecode(bytes);
      if (info == null || info.width * info.height > 20000000) return null;
      var bitmap = image.decodeImage(bytes);
      if (bitmap == null) return null;
      bitmap = image.bakeOrientation(bitmap);
      final edge = compact ? 256 : 512;
      if (bitmap.width > edge || bitmap.height > edge) {
        bitmap = image.copyResize(
          bitmap,
          width: bitmap.width >= bitmap.height ? edge : null,
          height: bitmap.height > bitmap.width ? edge : null,
        );
      }
      bitmap.exif = image.ExifData();
      return pw.ImageImage(bitmap);
    } catch (_) {
      return null;
    }
  }

  static pw.TableRow _row(
    List<String> values, {
    bool header = false,
    bool compact = false,
    bool specification = false,
    PdfColor color = _ink,
  }) => pw.TableRow(
    repeat: header,
    children: [
      for (final value in values)
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(
            vertical: specification ? 2 : (compact ? 4 : 8),
            horizontal: 4,
          ),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              color: color,
              fontSize: compact ? 8 : (header ? 8 : 9),
              fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
    ],
  );

  static pw.Widget _totalRow(
    String label,
    int amount,
    String currency, {
    bool large = false,
    PdfColor color = _ink,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(
            label,
            style: pw.TextStyle(color: color, fontSize: large ? 10 : 9),
          ),
        ),
        pw.SizedBox(
          width: 110,
          child: pw.Text(
            formatMoney(amount, currency),
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              color: color,
              fontSize: large ? 13 : 9,
              fontWeight: large ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    ),
  );
}
