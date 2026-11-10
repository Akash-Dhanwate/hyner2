import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/pricing_database.dart' show PricingDatabase;
import 'package:hyner/features/pricing/application/workspace.dart';
import 'package:hyner/features/pricing/data/device_workspace.dart';
import 'package:hyner/features/pricing/domain/pricing_models.dart';
import 'package:hyner/features/pricing/domain/serialization.dart';
import 'package:hyner/features/pricing/domain/universal/rate_card.dart';

import 'support/setup_fixture.dart' as f;

void main() {
  test('v3 upgrade preserves workspace, setup, approvals and publication across restarts', () async {
    final dir = await Directory.systemTemp.createTemp('hyner-workspace-');
    final file = File('${dir.path}/prices.sqlite');
    var db = PricingDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute(
            File('test/fixtures/pricing_schema_v3.sql').readAsStringSync(),
          );
          raw.execute(
            "INSERT INTO pricing_profiles VALUES ('old','doors','Original','draft',1,2)",
          );
          raw.execute(
            "INSERT INTO pricing_drafts VALUES ('old','doors',9,'unchanged')",
          );
        },
      ),
    );
    QuickPriceWorkspace? workspace;
    try {
      workspace = await openDeviceWorkspace(db);
      final id = workspace.businessId;
      final setup = f.setup('area');
      await workspace.values.write('setup_draft', setup.data);
      final product = setup.compile(id, f.currency);
      final card = UniversalRateCardDraft(
        name: 'Doors',
        currency: f.currency,
        categories: [PricingCategory(id: product.categoryId, name: 'Doors')],
        products: [product],
      );
      await workspace.repository.createProfile('doors', card);
      await expectLater(
        workspace.repository.publish(
          'doors',
          expectedRevision: 1,
          effectiveAt: f.now,
        ),
        throwsStateError,
      );
      await workspace.values.approve(product.rule.tax);
      final version = await workspace.repository.publish(
        'doors',
        expectedRevision: 1,
        effectiveAt: f.now,
      );
      final snapshot = canonicalJson(version.toJson());
      await workspace.close();
      workspace = null;
      db = PricingDatabase(NativeDatabase(file));
      workspace = await openDeviceWorkspace(db);
      expect(workspace.businessId, id);
      expect((await workspace.values.read('setup_draft'))!['id'], setup.id);
      expect(
        await workspace.values.isApproved('another-business', product.rule.tax),
        false,
      );
      expect(
        canonicalJson(
          (await workspace.repository.readVersion('doors', 1)).toJson(),
        ),
        snapshot,
      );
      expect(
        (await db
                .customSelect('SELECT snapshot_json FROM pricing_drafts')
                .getSingle())
            .read<String>('snapshot_json'),
        'unchanged',
      );
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        4,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      final writer = DraftWriter(workspace.values);
      await Future.wait([
        writer.write('calculator', {'quantity': '1'}),
        writer.write('calculator', {'quantity': '2'}),
      ]);
      expect((await workspace.values.read('calculator'))!['quantity'], '2');
    } finally {
      await workspace?.close();
      await dir.delete(recursive: true);
    }
  });
}
