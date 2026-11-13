import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/reports/data/report_pdf_service.dart';

import 'support/design_fixture.dart';

void main() {
  test(
    'earnings report remains exportable with additional financial summary',
    () async {
      final bytes = await ReportPdfService.build(
        designReport(),
        preparedFor: 'Sample business',
        generatedAt: DateTime.utc(2026, 11, 12),
      );
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(2000));
      if (const bool.fromEnvironment('CAPTURE_SALES_REFINEMENT')) {
        final file = File('build/sales-refinement/after/report.pdf');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
      }
    },
  );
}
