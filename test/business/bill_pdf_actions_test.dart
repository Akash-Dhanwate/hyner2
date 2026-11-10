import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/sales/data/bill_pdf_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const printing = MethodChannel('net.nfet.printing');
  final bytes = Uint8List.fromList('%PDF-test'.codeUnits);
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(BillPdfActions.channel, null);
    messenger.setMockMethodCallHandler(printing, null);
  });
  test(
    'WhatsApp receives the saved PDF through the native targeted channel',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(BillPdfActions.channel, (call) async {
        calls.add(call);
        return null;
      });
      await BillPdfActions.shareWhatsApp(bytes, 'bill.pdf');
      expect(calls.single.method, 'shareWhatsApp');
      expect(calls.single.arguments['filename'], 'bill.pdf');
      expect(calls.single.arguments['bytes'], orderedEquals(bytes));
    },
  );
  test(
    'unavailable targeted share falls back to generic PDF sharing',
    () async {
      messenger.setMockMethodCallHandler(BillPdfActions.channel, (_) async {
        throw PlatformException(code: 'unavailable');
      });
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(printing, (call) async {
        calls.add(call);
        return 1;
      });
      await BillPdfActions.shareWhatsApp(bytes, 'bill.pdf');
      expect(calls.single.method, 'sharePdf');
      expect(calls.single.arguments['name'], 'bill.pdf');
    },
  );
  test(
    'save returns the document URI and treats cancellation as cancellation',
    () async {
      messenger.setMockMethodCallHandler(BillPdfActions.channel, (call) async {
        expect(call.method, 'savePdf');
        expect(call.arguments['bytes'], orderedEquals(bytes));
        return 'content://documents/bill.pdf';
      });
      expect(
        await BillPdfActions.save(bytes, 'bill.pdf'),
        'content://documents/bill.pdf',
      );
      messenger.setMockMethodCallHandler(
        BillPdfActions.channel,
        (_) async => null,
      );
      expect(await BillPdfActions.save(bytes, 'bill.pdf'), isNull);
    },
  );
}
