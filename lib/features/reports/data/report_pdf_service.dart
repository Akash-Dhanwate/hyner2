import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/business_report.dart';

class ReportPdfService {
  static const _ink = PdfColor.fromInt(0xff142f35);
  static const _muted = PdfColor.fromInt(0xff64777b);
  static const _line = PdfColor.fromInt(0xffdce5e6);
  static const _sales = PdfColor.fromInt(0xff087e8b);
  static const _expense = PdfColor.fromInt(0xffe58a45);
  static const _pale = PdfColor.fromInt(0xfff2f7f7);

  static Future<Uint8List> build(
    BusinessReport report, {
    required String preparedFor,
    required DateTime generatedAt,
  }) async {
    final document = pw.Document(
      title: 'Monthly Business Activity Report',
      author: 'Hyner',
      subject: 'Operational sales and purchase summary',
    );
    final rangeLabel = _rangeLabel(report.start, report.end);
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(34, 34, 34, 42),
        maxPages: 100,
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _line, width: .8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'HYNER  /  BUSINESS ACTIVITY',
                style: pw.TextStyle(
                  color: _ink,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              pw.Text(
                '${report.currency}  |  $rangeLabel',
                style: const pw.TextStyle(color: _muted, fontSize: 9),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _line, width: .8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Operational summary only - not an accounting statement or tax filing.',
                style: const pw.TextStyle(color: _muted, fontSize: 8),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(color: _muted, fontSize: 8),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Monthly Business Activity Report',
                    style: pw.TextStyle(
                      color: _ink,
                      fontSize: 23,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Prepared for $preparedFor  |  Generated ${_dateTime(generatedAt)}',
                    style: const pw.TextStyle(color: _muted, fontSize: 9),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: _pale,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  rangeLabel,
                  style: pw.TextStyle(
                    color: _ink,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          _metricCards(report),
          pw.SizedBox(height: 6),
          pw.Text(
            report.hasIncompleteCosts
                ? 'Earnings are incomplete: ${report.uncostedSalesCount} bills have no saved buying costs. Stock purchases are not deducted twice.'
                : 'Earnings: saved selling amounts less saved buying costs and recorded operating expenses. Stock purchases are not deducted twice.',
            style: const pw.TextStyle(color: _muted, fontSize: 8),
          ),
          pw.SizedBox(height: 18),
          _sectionTitle('Sales revenue and recorded expenses'),
          pw.SizedBox(height: 6),
          _chartLegend(),
          pw.SizedBox(height: 8),
          _activityChart(report),
          pw.SizedBox(height: 16),
          _sectionTitle('Monthly highlights'),
          pw.SizedBox(height: 6),
          pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(color: _ink, fontSize: 9),
              children: [
                const pw.TextSpan(text: 'Sales revenue '),
                pw.TextSpan(
                  text: formatBigMoney(report.revenueMinor, report.currency),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                const pw.TextSpan(text: ' from '),
                pw.TextSpan(
                  text: '${report.salesCount} bills',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                const pw.TextSpan(text: ', with '),
                pw.TextSpan(
                  text: formatBigMoney(
                    report.unpaidRevenueMinor,
                    report.currency,
                  ),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                const pw.TextSpan(text: ' due.'),
              ],
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Scope: recorded expenses combine purchases after returns with outgoings entered in Expenses. Any costs not entered in Hyner are excluded.',
            style: const pw.TextStyle(color: _muted, fontSize: 8),
          ),
          if (report.topProducts.isNotEmpty) ...[
            pw.NewPage(),
            pw.SizedBox(height: 8),
            pw.SizedBox(height: 13),
            _sectionTitle('Top five products by sales revenue'),
            pw.SizedBox(height: 6),
            _table(
              headers: const ['Product', 'Code', 'Units', 'Sales revenue'],
              rows: [
                for (final product in report.topProducts)
                  [
                    product.name,
                    product.sku,
                    '${product.units}',
                    formatBigMoney(product.revenueMinor, report.currency),
                  ],
              ],
              widths: const [
                pw.FlexColumnWidth(3),
                pw.FlexColumnWidth(1.2),
                pw.FlexColumnWidth(.8),
                pw.FlexColumnWidth(1.5),
              ],
            ),
          ],
          pw.SizedBox(height: 16),
          _sectionTitle('Sales register'),
          pw.SizedBox(height: 6),
          if (report.salesRecords.isEmpty)
            _emptyState('No sales were recorded for this period.')
          else
            ..._tablePages(
              headers: const [
                'Date',
                'Reference',
                'Customer',
                'Bill total',
                'Received',
                'Balance due',
              ],
              rows: [
                for (final sale in report.salesRecords)
                  [
                    _date(sale.date),
                    _shortReference(sale.reference),
                    sale.customer,
                    formatBigMoney(sale.totalMinor, report.currency),
                    formatBigMoney(sale.paidMinor, report.currency),
                    formatBigMoney(sale.remainingMinor, report.currency),
                  ],
              ],
              widths: const [
                pw.FlexColumnWidth(1.1),
                pw.FlexColumnWidth(1.2),
                pw.FlexColumnWidth(2),
                pw.FlexColumnWidth(1.2),
                pw.FlexColumnWidth(1.2),
                pw.FlexColumnWidth(1.2),
              ],
            ),
          pw.SizedBox(height: 16),
          _sectionTitle('Purchase register'),
          pw.SizedBox(height: 6),
          if (report.purchaseRecords.isEmpty)
            _emptyState('No purchases were recorded for this period.')
          else
            ..._tablePages(
              headers: const [
                'Date',
                'Reference',
                'Supplier',
                'Purchase amount',
              ],
              rows: [
                for (final purchase in report.purchaseRecords)
                  [
                    _date(purchase.date),
                    _shortReference(purchase.reference),
                    purchase.supplier,
                    formatBigMoney(purchase.amountMinor, report.currency),
                  ],
              ],
              widths: const [
                pw.FlexColumnWidth(1.1),
                pw.FlexColumnWidth(1.2),
                pw.FlexColumnWidth(2),
                pw.FlexColumnWidth(1.4),
              ],
            ),
          pw.NewPage(),
          pw.SizedBox(height: 8),
          _sectionTitle('Operating expense register'),
          pw.SizedBox(height: 6),
          if (report.expenseRecords.isEmpty)
            _emptyState('No operating expenses were recorded for this period.')
          else
            ..._tablePages(
              headers: const ['Date', 'Category', 'Description', 'Amount'],
              rows: [
                for (final expense in report.expenseRecords)
                  [
                    _date(expense.date),
                    expense.category,
                    expense.description,
                    formatBigMoney(expense.amountMinor, report.currency),
                  ],
              ],
              widths: const [
                pw.FlexColumnWidth(1.1),
                pw.FlexColumnWidth(1.2),
                pw.FlexColumnWidth(2.5),
                pw.FlexColumnWidth(1.3),
              ],
            ),
        ],
      ),
    );
    return document.save();
  }

  static pw.Widget _metricCards(BusinessReport report) {
    final cards = [
      (
        report.hasIncompleteCosts
            ? 'Known-cost earnings'
            : 'Earnings after costs',
        formatBigMoney(report.earningsAfterCostsMinor, report.currency),
      ),
      (
        'Gross profit',
        formatBigMoney(report.grossProfitMinor, report.currency),
      ),
      (
        'Operating expenses',
        formatBigMoney(report.operatingExpensesMinor, report.currency),
      ),
      ('Sales revenue', formatBigMoney(report.revenueMinor, report.currency)),
      ('Received', formatBigMoney(report.paidRevenueMinor, report.currency)),
      (
        'Balance due',
        formatBigMoney(report.unpaidRevenueMinor, report.currency),
      ),
      (
        'Total expenses',
        formatBigMoney(report.totalExpenseMinor, report.currency),
      ),
      ('Bills', '${report.salesCount}'),
      ('Units sold', '${report.soldUnits}'),
    ];
    return pw.Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        for (final card in cards)
          pw.Container(
            width: 120,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _pale,
              borderRadius: pw.BorderRadius.circular(7),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  card.$1.toUpperCase(),
                  style: pw.TextStyle(
                    color: _muted,
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  card.$2,
                  style: pw.TextStyle(
                    color: _ink,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _activityChart(BusinessReport report) {
    final points = _chartPoints(report.activity);
    if (points.isEmpty) return _emptyState('No activity to chart.');
    var maxValue = BigInt.zero;
    for (final point in points) {
      final a = point.revenueMinor.abs();
      final b = point.expenseMinor.abs();
      final candidate = a > b ? a : b;
      if (candidate > maxValue) maxValue = candidate;
    }
    if (maxValue == BigInt.zero) maxValue = BigInt.one;
    final scale = maxValue.toDouble();
    return pw.Container(
      height: 132,
      padding: const pw.EdgeInsets.fromLTRB(8, 8, 8, 2),
      decoration: pw.BoxDecoration(
        color: _pale,
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          for (final point in points)
            pw.Expanded(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _pdfBar(point.revenueMinor, scale, _sales),
                      pw.SizedBox(width: 3),
                      _pdfBar(point.expenseMinor, scale, _expense),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    point.label,
                    maxLines: 1,
                    style: const pw.TextStyle(color: _muted, fontSize: 7),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _pdfBar(BigInt value, double scale, PdfColor color) {
    final height = (value.abs().toDouble() / scale * 82).clamp(1.5, 82.0);
    return pw.Container(
      width: 24,
      height: height,
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.vertical(
          top: pw.Radius.circular(2),
        ),
      ),
    );
  }

  static List<ReportActivityPoint> _chartPoints(
    List<ReportActivityPoint> activity,
  ) {
    if (activity.length <= 8) return activity;
    final grouped = <ReportActivityPoint>[];
    for (var start = 0; start < activity.length; start += 7) {
      final points = activity.skip(start).take(7).toList();
      grouped.add(
        ReportActivityPoint(
          periodStart: points.first.periodStart,
          label: 'Week ${grouped.length + 1}',
          revenueMinor: points.fold(
            BigInt.zero,
            (sum, item) => sum + item.revenueMinor,
          ),
          expenseMinor: points.fold(
            BigInt.zero,
            (sum, item) => sum + item.expenseMinor,
          ),
        ),
      );
    }
    return grouped;
  }

  static pw.Widget _chartLegend() => pw.Row(
    children: [
      _legendSquare(_sales, 'Sales revenue'),
      pw.SizedBox(width: 20),
      _legendSquare(_expense, 'Recorded expenses'),
    ],
  );

  static pw.Widget _legendSquare(PdfColor color, String label) => pw.Row(
    children: [
      pw.Container(width: 27, height: 27, color: color),
      pw.SizedBox(width: 5),
      pw.Text(label, style: const pw.TextStyle(color: _muted, fontSize: 8)),
    ],
  );

  static pw.Widget _sectionTitle(String label) => pw.Text(
    label,
    style: pw.TextStyle(
      color: _ink,
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
    ),
  );

  static pw.Widget _emptyState(String label) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: _pale,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Text(
      label,
      style: const pw.TextStyle(color: _muted, fontSize: 9),
    ),
  );

  static pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    required List<pw.TableColumnWidth> widths,
  }) {
    final children = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _ink),
        children: [
          for (final header in headers)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 7,
              ),
              child: pw.Text(
                header,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      for (var index = 0; index < rows.length; index++)
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: index.isEven ? PdfColors.white : _pale,
          ),
          children: [
            for (final value in rows[index])
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                child: pw.Text(
                  value,
                  maxLines: 2,
                  style: const pw.TextStyle(color: _ink, fontSize: 7.5),
                ),
              ),
          ],
        ),
    ];
    return pw.Table(
      columnWidths: {for (var i = 0; i < widths.length; i++) i: widths[i]},
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: .35),
        bottom: pw.BorderSide(color: _line, width: .5),
      ),
      children: children,
    );
  }

  static Iterable<pw.Widget> _tablePages({
    required List<String> headers,
    required List<List<String>> rows,
    required List<pw.TableColumnWidth> widths,
  }) sync* {
    const rowsPerTable = 13;
    for (var start = 0; start < rows.length; start += rowsPerTable) {
      if (start > 0) yield pw.NewPage();
      yield _table(
        headers: headers,
        rows: rows.skip(start).take(rowsPerTable).toList(),
        widths: widths,
      );
    }
  }

  static String _shortReference(String reference) =>
      reference.length <= 12 ? reference : '${reference.substring(0, 12)}...';

  static String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static String _dateTime(DateTime date) =>
      '${_date(date.toLocal())} ${date.toLocal().hour.toString().padLeft(2, '0')}:${date.toLocal().minute.toString().padLeft(2, '0')}';

  static String _rangeLabel(DateTime start, DateTime endExclusive) {
    final end = endExclusive.subtract(const Duration(days: 1)).toLocal();
    final first = start.toLocal();
    return '${_date(first)} - ${_date(end)}';
  }
}
