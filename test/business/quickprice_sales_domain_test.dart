import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/errors/app_failure.dart';
import 'package:hyner/features/inventory/domain/product.dart';
import 'package:hyner/features/pricing/domain/pricing_models.dart'
    show TaxBehavior;
import 'package:hyner/features/pricing/domain/universal/universal_pricing.dart';
import 'package:hyner/features/sales/domain/sale.dart';
import 'package:hyner/features/sales/domain/sale_price_snapshot.dart';
import 'package:hyner/features/sales/data/sale_codec.dart';

import '../support/universal_fixture.dart' as u;
import 'support/quickprice_sales_fixture.dart';

void main() {
  test('six repeated names/varieties and sizes keep distinct quote lines', () {
    final lines = sixMeasuredLines();
    final draft = customSaleDraft(lines)..validate();
    expect(lines.map((line) => line.sku).toSet(), hasLength(6));
    expect(lines.map((line) => line.name).toSet(), hasLength(1));
    expect(
      lines.every((line) => !line.stockTracked && line.unitCostMinor == 0),
      isTrue,
    );
    expect(
      draft.totalMinor,
      lines.fold<int>(0, (amount, line) => amount + line.pricing!.totalMinor),
    );
    expect(
      lines.map((line) => line.pricing!.snapshotJson).toSet(),
      hasLength(6),
    );
    expect(
      () => customSaleDraft([lines.first, lines.first]).validate(),
      throwsA(isA<AppFailure>()),
    );
  });

  test(
    'final total preserves fractional taxes, order extras and discounts',
    () {
      final snapshot = SalePriceSnapshot.fromResult(measuredQuote());
      expect(snapshot.totalMinor, 340);
      expect(snapshot.netMinor, 288);
      expect(snapshot.taxMinor, 52);
      expect(snapshot.discountMinor, 16);
      expect(snapshot.unitPriceMinor, 113);
      expect(snapshot.unitPriceRounded, isTrue);
      expect(measuredSaleLine(0).totalMinor, 340);
      expect(snapshot.unitPriceMinor * snapshot.quantity, 339);
      expect(snapshot.currency, 'INR');
      expect(snapshot.businessId, 'business');
      expect(snapshot.toJson(), snapshot.result.toJson());
      for (final behavior in TaxBehavior.values) {
        final result = measuredQuote(taxBehavior: behavior);
        final saved = SalePriceSnapshot.fromResult(result);
        expect(saved.totalMinor, result.amounts.totalMinor.toInt());
        expect(saved.netMinor + saved.taxMinor, saved.totalMinor);
        saved.validate();
      }
    },
  );

  test(
    'unit display rounds an exact half paisa up independent of quote rounding',
    () {
      final result = u.price(
        u.rule(
          strategy: u.piece('base'),
          rates: [u.rate('base', '0.005', 'piece')],
        ),
        quantity: 2,
      );
      final saved = SalePriceSnapshot.fromResult(result);
      expect(saved.totalMinor, 1);
      expect(saved.unitPriceMinor, 1);
      expect(saved.unitPriceRounded, isTrue);
    },
  );

  test('replay rejects changed financial amounts and derived output', () {
    final snapshot = SalePriceSnapshot.fromResult(measuredQuote());
    for (final key in (snapshot.toJson()['amounts'] as Map).keys) {
      final forged = snapshot.toJson();
      (forged['amounts'] as Map)[key] = '999';
      expect(
        () => SalePriceSnapshot.fromJson(forged),
        throwsA(isA<AppFailure>()),
        reason: '$key',
      );
    }
    for (final key in [
      'normalizedInputs',
      'billableInputs',
      'resolvedInputs',
    ]) {
      expect(
        () => SalePriceSnapshot.fromJson({
          ...snapshot.toJson(),
          key: <String, dynamic>{},
        }),
        throwsA(isA<AppFailure>()),
        reason: key,
      );
    }
    for (final key in ['base', 'extras']) {
      expect(
        () => SalePriceSnapshot.fromJson({...snapshot.toJson(), key: []}),
        throwsA(isA<AppFailure>()),
        reason: key,
      );
    }
    for (final key in ['unitBaseAmount', 'orderBaseAmount', 'extraAmount']) {
      expect(
        () => SalePriceSnapshot.fromJson({...snapshot.toJson(), key: '999'}),
        throwsA(isA<AppFailure>()),
        reason: key,
      );
    }
    for (final change in [
      {'snapshotVersion': 2},
      {'engineVersion': 'future'},
      {'calculatedAt': DateTime.utc(2020).toIso8601String()},
      {'unknownOutput': true},
      {
        'warnings': ['Forged warning'],
      },
    ]) {
      expect(
        () => SalePriceSnapshot.fromJson({...snapshot.toJson(), ...change}),
        throwsA(isA<AppFailure>()),
      );
    }
  });

  test('saved calculation time replays expired rules and preserves only session warning', () {
    final result = u.price(
      u.rule(
        strategy: u.piece('base'),
        rates: [u.rate('base', '1', 'piece')],
        expiresAt: u.at.add(const Duration(seconds: 1)),
      ),
    );
    final json = result.toJson();
    json['warnings'] = [
      ...result.warnings,
      SalePriceSnapshot.sessionExtraOverrideWarning,
    ];
    final saved = SalePriceSnapshot.fromJson(json);
    saved.validate();
    expect(saved.result.calculatedAt, u.at);
    expect(saved.toJson(), json);
    expect(
      saved.result.warnings.last,
      SalePriceSnapshot.sessionExtraOverrideWarning,
    );
    expect(
      () => SalePriceSnapshot.fromJson({
        ...json,
        'warnings': [
          SalePriceSnapshot.sessionExtraOverrideWarning,
          SalePriceSnapshot.sessionExtraOverrideWarning,
        ],
      }),
      throwsA(isA<AppFailure>()),
    );
  });

  test('snapshots detach JSON and compare canonical contents for retries', () {
    final json = measuredQuote().toJson();
    final a = SalePriceSnapshot.fromJson(json);
    (json['amounts'] as Map)['totalMinor'] = '1';
    final detached = a.toJson();
    (detached['request'] as Map)['quantity'] = 999;
    expect(a.totalMinor, 340);
    a.validate();
    final reversed = Map<String, dynamic>.fromEntries(
      a.toJson().entries.toList().reversed,
    );
    final b = SalePriceSnapshot.fromJson(reversed);
    expect(a.snapshotJson, b.snapshotJson);
    final first = customSaleDraft([measuredSaleLine(0, result: a.result)]);
    expect(
      first.matches(customSaleDraft([measuredSaleLine(0, result: b.result)])),
      isTrue,
    );
    // Same total, unit and quantity; changing measured inputs must still differ.
    final changed = measuredQuote(width: '2', height: '0.5');
    expect(changed.amounts.totalMinor.toInt(), a.totalMinor);
    expect(
      first.matches(customSaleDraft([measuredSaleLine(0, result: changed)])),
      isFalse,
    );
  });

  test(
    'line quantity, display unit, cost and draft currency must match quote',
    () {
      final snapshot = SalePriceSnapshot.fromResult(measuredQuote());
      for (final line in [
        SaleLine(
          sku: 'QP_A',
          name: 'Custom',
          unitPriceMinor: 113,
          quantity: 2,
          pricing: snapshot,
        ),
        SaleLine(
          sku: 'QP_A',
          name: 'Custom',
          unitPriceMinor: 114,
          quantity: 3,
          pricing: snapshot,
        ),
        SaleLine(
          sku: 'QP_A',
          name: 'Custom',
          unitPriceMinor: 113,
          quantity: 3,
          unitCostMinor: 1,
          pricing: snapshot,
        ),
      ]) {
        expect(line.validate, throwsA(isA<AppFailure>()));
      }
      expect(
        () =>
            SaleDraft(currency: 'USD', lines: [measuredSaleLine(0)]).validate(),
        throwsA(isA<AppFailure>()),
      );
      expect(
        SaleLine(
          sku: 'A',
          name: 'Stock',
          unitPriceMinor: 1,
          quantity: 3,
        ).stockTracked,
        isTrue,
      );
      expect(measuredSaleLine(0).toMap()['pricing'], snapshot.toJson());
    },
  );

  test(
    'supported currencies require two minor digits and bill money limits',
    () {
      final original = measuredQuote();
      for (final code in [...inventoryCurrencies, 'JPY']) {
        for (final digits in [0, 2, 3]) {
          final json = original.rule.toJson();
          json['currency'] = {'code': code, 'minorDigits': digits};
          final result = u.price(
            UniversalPricingRule.fromJson(json),
            inputs: original.request.inputs,
            quantity: 3,
          );
          if (inventoryCurrencies.contains(code) && digits == 2) {
            expect(SalePriceSnapshot.fromResult(result).currency, code);
          } else {
            expect(
              () => SalePriceSnapshot.fromResult(result),
              throwsA(isA<AppFailure>()),
            );
          }
        }
      }
      final oversized = u.price(
        u.rule(
          strategy: u.piece('base'),
          rates: [u.rate('base', '10000000000', 'piece')],
        ),
      );
      expect(
        () => SalePriceSnapshot.fromResult(oversized),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => customSaleDraft([
          for (var i = 0; i < 2; i++)
            measuredSaleLine(
              i,
              result: u.price(
                u.rule(
                  strategy: u.piece('base'),
                  rates: [u.rate('base', '6000000000', 'piece')],
                ),
              ),
            ),
        ]).validate(),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  test('money ceiling applies to exact total even when rounded unit product exceeds it', () {
    final result = u.price(
      u.rule(
        strategy: u.piece('base'),
        rates: [u.rate('base', '4999999999.995', 'piece')],
      ),
      quantity: 2,
    );
    final line = measuredSaleLine(0, result: result);
    customSaleDraft([line]).validate();
    expect(line.totalMinor, maxMoneyMinor);
    expect(line.unitPriceMinor * line.quantity, maxMoneyMinor + 1);
  });

  test(
    'sale map codec retains custom snapshot and verifies exact line total',
    () {
      final line = measuredSaleLine(0);
      final draft = SaleDraft(currency: 'INR', lines: [line]);
      final data = <String, dynamic>{
        'actorUid': 'owner',
        'currency': 'INR',
        'items': draft.items,
        'totalMinor': draft.totalMinor,
        'createdAt': Timestamp.fromDate(u.at),
      };
      final saved = SaleCodec.decode('custom', 'owner', data);
      expect(
        saved.draft.lines.single.pricing!.snapshotJson,
        line.pricing!.snapshotJson,
      );
      expect(saved.draft.totalMinor, 340);
      expect(saved.draft.lines.single.stockTracked, isFalse);
      expect(
        () => SaleCodec.decode('custom', 'owner', {
          ...data,
          'items': {
            line.sku: {...line.toMap(), 'totalMinor': 339},
          },
        }),
        throwsA(isA<AppFailure>()),
      );
    },
  );
}
