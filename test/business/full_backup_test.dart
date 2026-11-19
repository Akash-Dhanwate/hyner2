import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/full_backup_service.dart';
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/core/storage/pricing_database.dart' show PricingDatabase;
import 'package:hyner/features/pricing/data/device_workspace.dart';
import 'package:hyner/features/pricing/domain/pricing_models.dart'
    show PricingCategory;
import 'package:hyner/features/pricing/domain/universal/rate_card.dart';

import '../support/setup_fixture.dart' as fixture;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late Directory folder;
  late LocalBusinessDatabase business;
  late PricingDatabase pricing;
  late DeviceWorkspaceValues values;
  late FullBackupService service;
  late SharedPreferencesAsync preferences;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('hyner-full-backup-');
    business = LocalBusinessDatabase(
      factory: databaseFactoryFfi,
      directory: folder.path,
    );
    pricing = PricingDatabase(NativeDatabase.memory());
    final workspace = await openDeviceWorkspace(pricing);
    values = workspace.values as DeviceWorkspaceValues;
    final previous = SharedPreferencesAsyncPlatform.instance;
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'hyner.profile.owner.displayName': 'Test Owner',
          'hyner.appearance': 'dark',
          'hyner.workspace.mode': 'account',
          'unrelated.token': 'secret',
        });
    preferences = SharedPreferencesAsync();
    service = FullBackupService(
      business: business,
      pricing: pricing,
      directory: folder,
      preferences: preferences,
    );
    await (await business.databaseFor('owner'))
        .insert('settings', {'key': 'shop', 'value': 'Before'});
    await values.write('estimate', {'customer': 'Example', 'amount': 100});
  });
  tearDown(() async {
    await pricing.close();
    await business.close();
    await folder.delete(recursive: true);
  });
  Future<String> shop() async =>
      (await (await business.databaseFor('owner')).query(
            'settings',
            where: 'key = ?',
            whereArgs: ['shop'],
          )).single['value']!
          as String;
  Future<void> change() async {
    await (await business.databaseFor('owner')).update(
      'settings',
      {'value': 'After'},
      where: 'key = ?',
      whereArgs: ['shop'],
    );
    await values.write('estimate', {'amount': 200});
    await preferences.setString('hyner.profile.owner.displayName', 'Changed');
  }

  test('complete backup restores both stores, preferences and image at a portable path', () async {
    final image = File('${folder.path}/profile-images/old.png');
    await image.parent.create();
    await image.writeAsBytes([1, 2, 3, 4]);
    await preferences.setString('hyner.profile.owner.photoUrl', image.path);
    final bytes = await service.export('owner');
    final data = FullBackupService.decode(bytes, 'owner');
    expect(
      (data['preferences'] as Map).containsKey('unrelated.token'),
      isFalse,
    );
    expect(
      (data['preferences'] as Map).containsKey('hyner.workspace.mode'),
      isFalse,
    );
    await change();
    await image.delete();
    await service.restore('owner', bytes, isCurrent: () => true);
    expect(await shop(), 'Before');
    expect((await values.read('estimate'))!['amount'], 100);
    expect(
      await preferences.getString('hyner.profile.owner.displayName'),
      'Test Owner',
    );
    final path = await preferences.getString('hyner.profile.owner.photoUrl');
    expect(await File(path!).readAsBytes(), [1, 2, 3, 4]);
    expect(await preferences.getString('unrelated.token'), 'secret');
  });

  test(
    'failure between databases restores the previous complete workspace',
    () async {
      final old = await service.export('owner');
      await change();
      await expectLater(
        service.restore(
          'owner',
          old,
          isCurrent: () => true,
          afterBusinessCommit: () => throw StateError('Interrupted'),
        ),
        throwsStateError,
      );
      expect(await shop(), 'After');
      expect((await values.read('estimate'))!['amount'], 200);
      expect(
        await preferences.getString('hyner.profile.owner.displayName'),
        'Changed',
      );
      expect(
        await File('${folder.path}/hyner-restore-journal.json').exists(),
        isFalse,
      );
    },
  );

  test(
    'durable journal recovers before normal use after process interruption',
    () async {
      final previous = await service.export('owner');
      await change();
      await File('${folder.path}/hyner-restore-undo.hyner')
          .writeAsBytes(previous, flush: true);
      await File('${folder.path}/hyner-restore-journal.json')
          .writeAsString(jsonEncode({'uid': 'owner'}), flush: true);
      await service.recover('owner');
      expect(await shop(), 'Before');
      expect((await values.read('estimate'))!['amount'], 100);
    },
  );

  test(
    'tampering and another workspace are rejected before data replacement',
    () async {
      final bytes = await service.export('owner');
      final tampered = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      tampered['data']['preferences']['hyner.profile.owner.displayName'] =
          'Injected';
      await expectLater(
        service.restore(
          'owner',
          utf8.encode(jsonEncode(tampered)),
          isCurrent: () => true,
        ),
        throwsFormatException,
      );
      await expectLater(
        service.restore('other', bytes, isCurrent: () => true),
        throwsFormatException,
      );
      expect(await shop(), 'Before');
      expect(
        await preferences.getString('hyner.profile.owner.displayName'),
        'Test Owner',
      );
    },
  );

  test('invalid calculator relationships fail preflight without replacing business data', () async {
    final bytes = await service.export('owner');
    final snapshot = await pricing.exportPortable();
    final tables = snapshot['tables'] as Map<String, dynamic>;
    tables['pricing_drafts'] = [
      {
        'business_id': 'missing',
        'profile_id': 'missing',
        'revision': 1,
        'snapshot_json': '{}',
      },
    ];
    await expectLater(
      pricing.restorePortable(snapshot, validateOnly: true),
      throwsA(anything),
    );
    expect((await values.read('estimate'))!['amount'], 100);
    await service.restore('owner', bytes, isCurrent: () => true);
    expect(await shop(), 'Before');
  });

  test('workspace switch prevents restore before any commit', () async {
    final bytes = await service.export('owner');
    await change();
    await expectLater(
      service.restore('owner', bytes, isCurrent: () => false),
      throwsStateError,
    );
    expect(await shop(), 'After');
    expect((await values.read('estimate'))!['amount'], 200);
  });
  test('published calculators survive restore and their immutability guards remain enabled', () async {
    final workspace = await openDeviceWorkspace(pricing);
    final product = fixture
        .setup('area')
        .compile(workspace.businessId, fixture.currency);
    await values.approve(product.rule.tax);
    await workspace.repository.createProfile(
      'doors',
      UniversalRateCardDraft(
        name: 'Doors',
        currency: fixture.currency,
        categories: [PricingCategory(id: product.categoryId, name: 'Doors')],
        products: [product],
      ),
    );
    await workspace.repository.publish(
      'doors',
      expectedRevision: 1,
      effectiveAt: fixture.now,
    );
    final bytes = await service.export('owner');
    await service.restore('owner', bytes, isCurrent: () => true);
    expect(
      (await workspace.repository.activeCard(
        'doors',
        at: fixture.now,
      ))!.card.products.single.name,
      product.name,
    );
    await expectLater(
      pricing.customStatement('DELETE FROM universal_pricing_versions'),
      throwsA(anything),
    );
    expect(
      (await workspace.repository.activeCard(
        'doors',
        at: fixture.now,
      ))!.version,
      1,
    );
  });
  test('coordinated capture holds business writes until calculator snapshot completes', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final snapshot = business.exportFor(
      'owner',
      captureRelatedStores: () async {
        entered.complete();
        await release.future;
        await pricing.exportPortable();
      },
    );
    await entered.future;
    var wrote = false;
    final db = await business.databaseFor('owner');
    final write = db
        .update(
          'settings',
          {'value': 'Queued write'},
          where: 'key = ?',
          whereArgs: ['shop'],
        )
        .then((_) => wrote = true);
    await Future<void>.delayed(Duration.zero);
    expect(wrote, isFalse);
    release.complete();
    final saved = await snapshot;
    await write;
    expect(
      ((saved['tables'] as Map)['settings'] as List).singleWhere(
        (row) => row['key'] == 'shop',
      )['value'],
      'Before',
    );
    expect(await shop(), 'Queued write');
  });
}
