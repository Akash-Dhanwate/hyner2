import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/storage/pricing_database.dart' show PricingDatabase;
import 'package:hyner/core/storage/local_business_database.dart';
import 'package:hyner/features/pricing/application/calculator_session.dart';
import 'package:hyner/features/pricing/application/estimate_builder.dart';
import 'package:hyner/features/pricing/application/product_setup.dart';
import 'package:hyner/features/pricing/application/simple_calculator.dart';
import 'package:hyner/features/pricing/data/device_workspace.dart';
import 'package:hyner/features/pricing/domain/exact.dart';
import 'package:hyner/features/pricing/domain/pricing_models.dart';
import 'package:hyner/features/pricing/domain/serialization.dart';
import 'package:hyner/features/pricing/domain/universal/rate_card.dart';
import 'package:hyner/features/sales/data/local_sales_repository.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/setup_fixture.dart' as f;

List<Map<String, dynamic>> varieties() => [
  {'id': 'flush-rate', 'name': 'Flush', 'amount': '150'},
  {'id': 'laminated-rate', 'name': 'Laminated', 'amount': '175'},
];

ProductSetup doorSetup() {
  final draft = quickProduct('doors', name: 'Door');
  draft.rows('rates').first['amount'] = '150';
  configureSimpleVarieties(draft, varieties());
  return draft;
}

void measuredDoor(CalculatorSession session) {
  session.changeLengthUnit('ft');
  session.change('height', 'text', '7');
  session.change('width', 'text', '3');
  session.changeQuantity('2');
}

void main() {
  test(
    'variety changes recalculate and keep dimensions, units and quantity',
    () {
      final product = doorSetup().compile('shop', f.currency);
      final unchanged = canonicalJson(product.toJson());
      final session = CalculatorSession()..select(product);
      addTearDown(session.dispose);
      measuredDoor(session);
      expect(session.availableBaseRateText, '150');
      expect(session.result!.amounts.totalMinor, BigInt.from(630000));
      session.change(simpleVarietyField, 'choice', 'Laminated');
      expect(session.availableBaseRateText, '175');
      expect(session.result!.amounts.totalMinor, BigInt.from(735000));
      session.setBaseRateOverride('155');
      expect(session.result!.amounts.totalMinor, BigInt.from(651000));
      expect(session.publicPriceText(), contains('Variety: Laminated'));
      final state = jsonObject(canonicalJson(session.toJson()));
      final restored = CalculatorSession()
        ..select(product)
        ..restore(state);
      addTearDown(restored.dispose);
      expect(restored.baseRateOverrideText, '155');
      expect(restored.result!.amounts.totalMinor, BigInt.from(651000));
      restored.change(simpleVarietyField, 'choice', 'Flush');
      expect(restored.hasBaseRateOverride, isFalse);
      expect(restored.result!.amounts.totalMinor, BigInt.from(630000));
      expect(restored.entries['height']!['text'], '7');
      expect(restored.entries['width']!['text'], '3');
      expect(restored.entries['height']!['unit'], 'ft');
      expect(restored.quantity, '2');
      expect(canonicalJson(product.toJson()), unchanged);
      restored.change(simpleVarietyField, 'choice', 'not-a-variety');
      expect(restored.result, isNull);
    },
  );

  test(
    'editing varieties preserves policies and the published source snapshot',
    () {
      final draft = doorSetup();
      draft.data['taxBehavior'] = 'exclusive';
      draft.data['taxPercent'] = '18';
      draft.data['discountPercent'] = '5';
      draft.rows('extras').add({
        'id': 'hinges',
        'name': 'Hinges',
        'type': 'perItem',
        'amount': '50',
        'optional': true,
        'selected': true,
      });
      draft
              .rows('fields')
              .firstWhere((f) => f['id'] == 'height')['billIncrement'] =
          '1';
      final original = draft.compile('shop', f.currency);
      final snapshot = canonicalJson(original.toJson());
      final next = replaceSimpleVarieties(original, 'Doors', '150', [
        ...varieties().take(1),
        {'id': 'laminated-rate', 'name': 'Laminated', 'amount': '200'},
        {'id': 'new-rate', 'name': 'Veneer', 'amount': '250'},
      ]);
      expect(simpleVarieties(next).map((v) => v['name']), [
        'Flush',
        'Laminated',
        'Veneer',
      ]);
      expect(next.rule.tax.toJson(), original.rule.tax.toJson());
      expect(next.rule.discount.toJson(), original.rule.discount.toJson());
      expect(next.rule.strategy.toJson(), original.rule.strategy.toJson());
      expect(
        next.rule.inputBilling.map((b) => b.toJson()),
        original.rule.inputBilling.map((b) => b.toJson()),
      );
      expect(
        next.rule.extras.map((b) => b.toJson()),
        original.rule.extras.map((b) => b.toJson()),
      );
      expect(canonicalJson(original.toJson()), snapshot);
      final plain = replaceSimpleVarieties(next, 'Doors', '125', []);
      expect(simpleVarieties(plain), isEmpty);
      expect(
        plain.rule.rateLookup.rates.singleWhere((r) => r.key == 'base').amount,
        Exact.parse('125'),
      );
      expect(
        plain.rule.schema.fields.any((f) => f.id == simpleVarietyField),
        isFalse,
      );
    },
  );

  test(
    'blank, duplicate, invalid and excessive variety rates cannot publish',
    () {
      for (final bad in [
        [
          {'id': 'a', 'name': '', 'amount': '150'},
        ],
        [
          {'id': 'a', 'name': 'A', 'amount': '-1'},
        ],
        [
          {'id': 'a', 'name': 'A', 'amount': '0'},
        ],
        [
          {'id': 'a', 'name': 'A', 'amount': '1e3'},
        ],
        [
          {'id': 'a', 'name': 'A', 'amount': '1000000000001'},
        ],
        [
          {'id': 'a', 'name': 'A', 'amount': '1'},
          {'id': 'b', 'name': ' a ', 'amount': '2'},
        ],
      ]) {
        expect(
          () => configureSimpleVarieties(quickProduct('doors'), bad),
          throwsA(anyOf(isA<ArgumentError>(), isA<FormatException>())),
        );
      }
    },
  );

  test(
    'existing advanced selector rates survive a simple fallback-rate edit',
    () {
      final draft = f.setup('perUnit');
      draft
          .rows('fields')
          .add(
            inputDraft('finish', 'Finish', 'number')..addAll({
              'type': 'choice',
              'choices': 'Basic,Premium',
              'default': 'Basic',
            }),
          );
      draft.rows('rates').add({
        'id': 'premium',
        'key': 'base',
        'amount': '200',
        'unit': '',
        'selectors': {'finish': 'Premium'},
      });
      final original = draft.compile('shop', f.currency);
      final updated = replaceSimpleVarieties(original, 'Fitting', '155', []);
      expect(
        updated.rule.rateLookup.rates.last.toJson(),
        original.rule.rateLookup.rates.last.toJson(),
      );
      expect(updated.rule.schema.toJson(), original.rule.schema.toJson());
      expect(
        () => replaceSimpleVarieties(original, 'Fitting', '155', varieties()),
        throwsStateError,
      );
    },
  );

  test(
    'selected variety and agreed rate round-trip into independent bill lines',
    () {
      final product = doorSetup().compile('shop', f.currency);
      final session = CalculatorSession()..select(product);
      addTearDown(session.dispose);
      measuredDoor(session);
      final flush = EstimateLine.capture(session: session, profileId: 'doors');
      session.change(simpleVarietyField, 'choice', 'Laminated');
      session.setBaseRateOverride('155.125');
      final agreed = EstimateLine.capture(session: session, profileId: 'doors');
      expect(agreed.pricing.totalMinor, 651525);
      expect(
        agreed.parameters.any(
          (p) => p.name == 'Variety' && p.value == 'Laminated',
        ),
        isTrue,
      );
      final restored = EstimateLine.fromJson(
        jsonObject(canonicalJson(agreed.toJson())),
      );
      expect(restored.pricing.snapshotJson, agreed.pricing.snapshotJson);
      session.change(simpleVarietyField, 'choice', 'Flush');
      expect(flush.pricing.totalMinor, 630000);
      expect(agreed.pricing.totalMinor, 651525);
      final estimate = QuickPriceEstimate.empty('shop')
          .append(flush)
          .append(restored);
      final lines = estimate.toCheckoutSeed('owner').lines;
      expect(lines.map((l) => l.totalMinor), [630000, 651525]);
      expect(lines[1].parameters.any((p) => p.value == 'Laminated'), isTrue);
    },
  );

  test(
    'saved varieties and negotiated bill survive database reopen unchanged',
    () async {
      sqfliteFfiInit();
      final folder = await Directory.systemTemp.createTemp('hyner-varieties-');
      final pricingFile = File('${folder.path}/pricing.sqlite');
      var workspace = await openDeviceWorkspace(
        PricingDatabase(NativeDatabase(pricingFile)),
      );
      addTearDown(() async {
        await workspace.close();
        if (await folder.exists()) await folder.delete(recursive: true);
      });
      final businessId = workspace.businessId;
      final product = doorSetup().compile(businessId, f.currency);
      await workspace.repository.createProfile(
        'doors',
        UniversalRateCardDraft(
          name: 'Doors',
          currency: f.currency,
          categories: [PricingCategory(id: product.categoryId, name: 'Doors')],
          products: [product],
        ),
      );
      await workspace.values.approve(product.rule.tax);
      await workspace.repository.publish(
        'doors',
        expectedRevision: 1,
        effectiveAt: DateTime.now().toUtc().subtract(
          const Duration(minutes: 1),
        ),
      );
      await workspace.close();
      workspace = await openDeviceWorkspace(
        PricingDatabase(NativeDatabase(pricingFile)),
      );
      final published = (await workspace.repository.activeCard(
        'doors',
        at: DateTime.now(),
      ))!;
      expect(
        simpleVarieties(published.card.products.single).map((v) => v['name']),
        ['Flush', 'Laminated'],
      );
      final session = CalculatorSession()
        ..select(published.card.products.single);
      measuredDoor(session);
      session.change(simpleVarietyField, 'choice', 'Laminated');
      session.setBaseRateOverride('155');
      final quote = EstimateLine.capture(session: session, profileId: 'doors');
      session.dispose();
      final store = LocalBusinessDatabase(
        factory: databaseFactoryFfi,
        directory: '${folder.path}/business',
      );
      addTearDown(store.close);
      final sales = LocalSalesRepository(store);
      final draft = SaleDraft(
        currency: 'INR',
        customerName: 'Synthetic customer',
        customerPhone: '9876543210',
        lines: [quote.toSaleLine()],
      );
      await sales.create('owner', 'variety-bill', draft);
      await store.close();
      final saved = await sales.get('owner', 'variety-bill');
      expect(saved.draft.totalMinor, 651000);
      expect(
        saved.draft.lines.single.pricing!.snapshotJson,
        quote.pricing.snapshotJson,
      );
      expect(
        saved.draft.lines.single.parameters.any((p) => p.value == 'Laminated'),
        isTrue,
      );
    },
  );
}
