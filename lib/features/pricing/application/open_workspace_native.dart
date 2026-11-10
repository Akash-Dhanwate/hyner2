import '../../../core/storage/open_pricing_database.dart';
import '../data/device_workspace.dart';
import 'workspace.dart';

Future<QuickPriceWorkspace> openQuickPriceWorkspace({
  String? accountUid,
}) async {
  final db = openLocalPricingDatabase(accountUid: accountUid);
  try {
    return await openDeviceWorkspace(db);
  } catch (_) {
    await db.close();
    rethrow;
  }
}
