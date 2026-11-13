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
    BillBrandingCache? brandingCache,
    bool quotation = false,
  }) async {
    final document = pw.Document(
      title: '${quotation ? 'Quotation' : 'Bill'} ${sale.id}',
      author: settings.merchantName.isEmpty ? 'Hyner' : settings.merchantName,
    );
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
          child: context.pageNumber > 1
              ? pw.Text(
                  settings.merchantName,
                  style: pw.TextStyle(color: footerColor, fontSize: 8),
                )
              : pw.SizedBox(),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber}',
            style: pw.TextStyle(color: footerColor, fontSize: 8),
          ),
        ),
        build: (context) =>
            _page(sale, settings, quotation, compact, brandingCache),
      ),
    );
    return document.save();
  }

  static List<pw.Widget> _page(
    Sale sale,
    PaymentSettings settings,
    bool quotation,
    bool compact,
    BillBrandingCache? brandingCache,
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
    final ledger = settings.billLayout == BillLayout.ledger;
    final alignment = centered
        ? pw.Alignment.center
        : ledger
        ? pw.Alignment.topLeft
        : pw.Alignment.topRight;
    final textAlign = centered
        ? pw.TextAlign.center
        : ledger
        ? pw.TextAlign.left
        : pw.TextAlign.right;
    final business = settings.merchantName.trim().isEmpty
        ? (quotation ? 'Quotation' : 'Sales bill')
        : settings.merchantName.trim();
    final branding = (brandingCache ?? BillBrandingCache()).prepare(
      settings,
      compact: compact,
    );
    final logo = branding.logo;
    final signature = branding.signature;
    return [
      pw.Container(
        alignment: alignment,
        child: pw.Column(
          crossAxisAlignment: centered
              ? pw.CrossAxisAlignment.center
              : ledger
              ? pw.CrossAxisAlignment.start
              : pw.CrossAxisAlignment.end,
          children: [
            pw.Row(
              mainAxisSize: pw.MainAxisSize.max,
              mainAxisAlignment: centered
                  ? pw.MainAxisAlignment.center
                  : ledger
                  ? pw.MainAxisAlignment.start
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
      if (centered || ledger)
        pw.Divider(color: billColor, thickness: ledger ? 2 : .7),
      if (quotation) ...[
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 10),
          decoration: pw.BoxDecoration(
            color: _pale,
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Text(
            'QUOTATION',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: billColor,
              fontSize: compact ? 17 : 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: compact ? 8 : 14),
      ],
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
                'Customer name',
                style: pw.TextStyle(
                  color: customerColor,
                  fontSize: quotation ? 10 : 9,
                  fontWeight: quotation
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
              pw.Text(
                sale.draft.customerName!,
                style: pw.TextStyle(
                  color: customerColor,
                  fontSize: quotation ? (compact ? 13 : 16) : 10,
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
      if (sale.draft.customerId != null || quotation) ...[
        pw.SizedBox(height: compact ? 3 : 6),
        pw.Text(
          'Customer ID: ${customerReference(sale.draft.customerName ?? '', sale.draft.customerPhone ?? '', sale.draft.customerId ?? sale.id)}',
          style: pw.TextStyle(color: customerColor, fontSize: 8),
        ),
      ],
      pw.SizedBox(height: 8),
      pw.Text(
        saleDate(sale.createdAt),
        style: pw.TextStyle(
          color: billColor,
          fontSize: compact ? 11 : 13,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        'Reference: ${sale.id}',
        style: pw.TextStyle(color: billColor, fontSize: 8),
      ),
      pw.SizedBox(height: compact ? 10 : 18),
      pw.Table(
        border: ledger
            ? pw.TableBorder.all(color: _line, width: .5)
            : const pw.TableBorder(bottom: pw.BorderSide(color: _line)),
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
            background: centered || ledger ? _pale : null,
          ),
          for (final line in sale.draft.lines)
            ..._itemRows(
              line,
              sale.draft.currency,
              compact: compact,
              color: itemColor,
            ),
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
                  if (!quotation)
                    _totalRow(
                      'Paid',
                      sale.paidMinor,
                      sale.draft.currency,
                      color: totalColor,
                    ),
                  if (!quotation)
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
              '${quotation ? 'Quotation only - not a bill or payment receipt.  ' : 'Payment status: ${sale.paymentStatus.name.toUpperCase()}  ·  '}${settings.footerText.trim().isEmpty ? 'Thank you for your business.' : settings.footerText.trim()}',
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

  static Iterable<pw.TableRow> _itemRows(
    SaleLine line,
    String currency, {
    required bool compact,
    required PdfColor color,
  }) sync* {
    // Ordinary measurements stay with the product. Very long specification
    // lists use continuation rows so the PDF paginator can safely split them.
    final inline =
        line.parameters.length <= 5 &&
        line.parameters.every(
          (parameter) => '${parameter.name}: ${parameter.value}'.length <= 100,
        );
    yield _itemRow(
      line,
      currency,
      compact: compact,
      color: color,
      includeSpecifications: inline,
    );
    if (!inline) {
      for (final parameter in line.parameters) {
        yield _row(
          [_parameterText('${parameter.name}: ${parameter.value}'), '', '', ''],
          compact: compact,
          color: color,
          specification: true,
        );
      }
      if (line.pricing?.unitPriceRounded == true) {
        yield _row(
          ['Approximate unit price; line amount is final.', '', '', ''],
          compact: compact,
          color: color,
          specification: true,
        );
      }
    }
  }

  static pw.TableRow _itemRow(
    SaleLine line,
    String currency, {
    required bool compact,
    required PdfColor color,
    required bool includeSpecifications,
  }) => pw.TableRow(
    children: [
      pw.Padding(
        padding: pw.EdgeInsets.symmetric(
          vertical: compact ? 4 : 8,
          horizontal: 4,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              line.name,
              style: pw.TextStyle(
                color: color,
                fontSize: compact ? 8 : 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (includeSpecifications && line.parameters.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                line.parameters
                    .map(
                      (parameter) => _parameterText(
                        '${parameter.name}: ${parameter.value}',
                      ),
                    )
                    .join('  ·  '),
                style: pw.TextStyle(color: color, fontSize: compact ? 7 : 8),
              ),
            ],
            if (includeSpecifications && line.pricing?.unitPriceRounded == true)
              pw.Text(
                'Approximate unit price; line amount is final.',
                style: pw.TextStyle(color: color, fontSize: compact ? 7 : 8),
              ),
          ],
        ),
      ),
      for (final value in [
        '${line.quantity}',
        '${line.pricing?.unitPriceRounded == true ? '~ ' : ''}${formatMoney(line.unitPriceMinor, currency)}',
        formatMoney(line.totalMinor, currency),
      ])
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(
            vertical: compact ? 4 : 8,
            horizontal: 4,
          ),
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              color: color,
              fontSize: compact ? 8 : 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
    ],
  );

  // Decode optional images before layout so a damaged legacy image cannot
  // abort invoice creation. Bound resolution and strip image metadata; the
  // archive uses a smaller image while preserving all financial content.
  static image.Image? _prepareImage(String encoded, bool compact) {
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
      return bitmap;
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
    PdfColor? background,
  }) => pw.TableRow(
    decoration: background == null ? null : pw.BoxDecoration(color: background),
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
            style: pw.TextStyle(color: color, fontSize: large ? 12 : 9),
          ),
        ),
        pw.SizedBox(
          width: 110,
          child: pw.Text(
            formatMoney(amount, currency),
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              color: color,
              fontSize: large ? 17 : 10,
              fontWeight: large ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Page-owned cache: at most two size variants for the current logo/signature.
/// Only raster pixels are retained. PDF ImageProviders retain a PdfDocument,
/// so each document gets fresh providers instead of caching whole PDF graphs.
class BillBrandingCache {
  String? _logo, _signature;
  final _variants = <bool, PreparedBillBranding>{};

  PreparedBillBranding prepare(
    PaymentSettings settings, {
    required bool compact,
  }) {
    if (_logo != settings.logoBase64 ||
        _signature != settings.signatureBase64) {
      clear();
      _logo = settings.logoBase64;
      _signature = settings.signatureBase64;
    }
    return _variants.putIfAbsent(
      compact,
      () => PreparedBillBranding._(
        BillPdfService._prepareImage(settings.logoBase64, compact),
        BillPdfService._prepareImage(settings.signatureBase64, compact),
      ),
    );
  }

  void clear() {
    _logo = null;
    _signature = null;
    _variants.clear();
  }
}

class PreparedBillBranding {
  PreparedBillBranding._(this._logo, this._signature);
  final image.Image? _logo, _signature;
  pw.ImageProvider? get logo {
    final bitmap = _logo;
    return bitmap == null ? null : pw.ImageImage(bitmap);
  }

  pw.ImageProvider? get signature {
    final bitmap = _signature;
    return bitmap == null ? null : pw.ImageImage(bitmap);
  }
}
