import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/open_pricing_database.dart';
import 'package:hyner/core/storage/pricing_database.dart' show PricingDatabase;
import 'package:hyner/features/pricing/data/device_workspace.dart';
import 'package:hyner/features/pricing/domain/pricing_models.dart';
import 'package:hyner/features/pricing/domain/universal/rate_card.dart';

import '../support/setup_fixture.dart' as f;

void main() {
  test(
    'device rates survive combined app and remain separate from each account',
    () async {
      final db = PricingDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final device = await openDeviceWorkspace(db);
      final aliceDb = PricingDatabase(NativeDatabase.memory());
      final bobDb = PricingDatabase(NativeDatabase.memory());
      addTearDown(aliceDb.close);
      addTearDown(bobDb.close);
      final alice = await openDeviceWorkspace(aliceDb);
      final bob = await openDeviceWorkspace(bobDb);
      expect(localPricingDatabaseName(), 'hyner_quickprice');
      expect(
        localPricingDatabaseName(accountUid: 'alice'),
        isNot(localPricingDatabaseName(accountUid: 'bob')),
      );
      expect(
        localPricingDatabaseName(accountUid: 'alice'),
        isNot(localPricingDatabaseName()),
      );
      expect(
        () => localPricingDatabaseName(accountUid: '../invalid'),
        throwsArgumentError,
      );
      for (final workspace in [device, alice, bob]) {
        await workspace.values.write('calculator', {
          'scope': workspace.businessId,
        });
      }
      final product = f.setup('area').compile(device.businessId, f.currency);
      final card = UniversalRateCardDraft(
        name: 'Device rates',
        currency: f.currency,
        categories: [PricingCategory(id: product.categoryId, name: 'Doors')],
        products: [product],
      );
      await device.repository.createProfile('doors', card);
      final reopened = await openDeviceWorkspace(db);
      expect(reopened.businessId, device.businessId);
      expect((await reopened.profiles()).single.name, 'Device rates');
      expect(await alice.profiles(), isEmpty);
      expect(await bob.profiles(), isEmpty);
      for (final workspace in [reopened, alice, bob]) {
        expect(
          (await workspace.values.read('calculator'))!['scope'],
          workspace.businessId,
        );
      }
      await device.values.approve(product.rule.tax);
      expect(
        await alice.values.isApproved(alice.businessId, product.rule.tax),
        isFalse,
      );
    },
  );
}
