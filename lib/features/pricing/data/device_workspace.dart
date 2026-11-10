import 'package:drift/drift.dart';

import '../../../core/storage/pricing_database.dart' show PricingDatabase;
import '../application/workspace.dart';
import '../domain/pricing_models.dart';
import '../domain/pricing_repository.dart';
import '../domain/serialization.dart';
import 'local_universal_rate_card_repository.dart';

class DeviceWorkspaceValues implements WorkspaceValues {
  DeviceWorkspaceValues(this.db, this.businessId);
  final PricingDatabase db;
  final String businessId;
  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final row = await db
        .customSelect(
          'SELECT snapshot_json FROM pricing_workspace_values WHERE business_id = ? AND id = ? LIMIT 1',
          variables: [Variable(businessId), Variable(key)],
        )
        .getSingleOrNull();
    return row == null ? null : jsonObject(row.read<String>('snapshot_json'));
  }

  @override
  Future<void> write(String key, Map<String, dynamic>? value) async {
    validateWorkspaceValue(value);
    if (value == null) {
      await db.customStatement(
        'DELETE FROM pricing_workspace_values WHERE business_id = ? AND id = ?',
        [businessId, key],
      );
    } else {
      await db.customStatement(
        'INSERT INTO pricing_workspace_values VALUES (?,?,?) ON CONFLICT(business_id,id) DO UPDATE SET snapshot_json = excluded.snapshot_json',
        [businessId, key, canonicalJson(value)],
      );
    }
  }

  @override
  Future<void> approve(TaxPolicy policy) => db.customStatement(
    'INSERT OR IGNORE INTO pricing_local_tax_approvals VALUES (?,?,?)',
    [
      businessId,
      canonicalJson(policy.toJson()),
      DateTime.now().millisecondsSinceEpoch,
    ],
  );
  @override
  Future<bool> isApproved(String businessId, TaxPolicy policy) async {
    if (businessId != this.businessId) return false;
    return await db
            .customSelect(
              'SELECT 1 FROM pricing_local_tax_approvals WHERE business_id = ? AND policy_json = ? LIMIT 1',
              variables: [
                Variable(businessId),
                Variable(canonicalJson(policy.toJson())),
              ],
            )
            .getSingleOrNull() !=
        null;
  }
}

Future<QuickPriceWorkspace> openDeviceWorkspace(PricingDatabase db) async {
  final business = await db.transaction(() async {
    final row = await db
        .customSelect(
          'SELECT business_id FROM pricing_device_workspace WHERE singleton = 1',
        )
        .getSingleOrNull();
    if (row != null) return row.read<String>('business_id');
    final id = 'local_${newPricingId()}';
    await db.customStatement(
      'INSERT INTO pricing_device_workspace VALUES (1,?,?)',
      [id, DateTime.now().millisecondsSinceEpoch],
    );
    return id;
  });
  final values = DeviceWorkspaceValues(db, business);
  // Explicit local ownership never grants membership in a cloud business.
  final session = PricingSession(
    businessId: business,
    actorId: 'device-owner',
    permissions: PricingPermission.values.toSet(),
  );
  return QuickPriceWorkspace(
    businessId: business,
    values: values,
    repository: LocalUniversalRateCardRepository(db, session, values),
    onClose: db.close,
  );
}
