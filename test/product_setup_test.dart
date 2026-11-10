import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/pricing/application/product_setup.dart';
import 'package:hyner/features/pricing/application/calculator_session.dart';
import 'package:hyner/features/pricing/domain/exact.dart';
import 'package:hyner/features/pricing/domain/universal/universal_pricing.dart';

import 'support/setup_fixture.dart';

void main() {
  test('a fresh setup never invents a selling rate or tax treatment', () {
    final fresh = ProductSetup.create();
    expect(fresh.rows('rates').first['amount'], '');
    expect(fresh.data['taxBehavior'], '');
    expect(() => fresh.compile('shop', currency), throwsArgumentError);
  });
  for (final example in [
    (kind: 'perUnit', values: <String, InputValue>{}, expected: 15000),
    (
      kind: 'area',
      values: <String, InputValue>{
        'height': n('7', 'ft'),
        'width': n('3', 'ft'),
      },
      expected: 315000,
    ),
    (
      kind: 'linear',
      values: <String, InputValue>{'length': n('2', 'm')},
      expected: 30000,
    ),
    (
      kind: 'weight',
      values: <String, InputValue>{'weight': n('2500', 'g')},
      expected: 37500,
    ),
    (
      kind: 'volume',
      values: <String, InputValue>{
        'height': n('2', 'm'),
        'width': n('3', 'm'),
        'depth': n('1', 'm'),
      },
      expected: 90000,
    ),
    (
      kind: 'formula',
      values: <String, InputValue>{
        'height': n('84', 'in'),
        'width': n('36', 'in'),
      },
      expected: 315000,
    ),
  ]) {
    test(
      'merchant setup compiles ${example.kind} with exact selling totals',
      () {
        final product = setup(example.kind).compile('shop', currency);
        final result = UniversalPricingEngine().calculate(
          product.rule,
          UniversalPricingRequest(inputs: example.values, quantity: 1),
          at: now,
        );
        expect(result.amounts.totalMinor, BigInt.from(example.expected));
      },
    );
  }
  test('package setup uses explicit coverage and bills whole boxes', () {
    final draft = setup('packaging', rate: '600');
    draft.data['coverage'] = '12';
    final product = draft.compile('shop', currency);
    final result = UniversalPricingEngine().calculate(
      product.rule,
      UniversalPricingRequest(inputs: {'area': n('25', 'ft2')}, quantity: 1),
      at: now,
    );
    expect(result.base.single.billable, Exact.integer(3));
    expect(result.amounts.totalMinor, BigInt.from(180000));
    draft.data['coverage'] = '0';
    expect(() => draft.compile('shop', currency), throwsArgumentError);
  });
  test('tier setup prices all units at the approved threshold rate', () {
    final draft = setup('quantityTier');
    draft.rows('tiers').first['amount'] = '100';
    draft.rows('tiers').add({'id': 'bulk', 'minimum': '10', 'amount': '80'});
    final product = draft.compile('shop', currency);
    final result = UniversalPricingEngine().calculate(
      product.rule,
      UniversalPricingRequest(inputs: {}, quantity: 10),
      at: now,
    );
    expect(result.amounts.totalMinor, BigInt.from(80000));
  });
  test(
    'size bands reject unsupported dimensions instead of guessing a price',
    () {
      final draft = setup('sizeSlab');
      draft.rows('bands').first.addAll({
        'amount': '2000',
        'ranges': {
          'height': {'min': '6', 'max': '8'},
          'width': {'min': '2', 'max': '4'},
        },
      });
      final product = draft.compile('shop', currency);
      final result = UniversalPricingEngine().calculate(
        product.rule,
        UniversalPricingRequest(
          inputs: {'height': n('7', 'ft'), 'width': n('3', 'ft')},
          quantity: 1,
        ),
        at: now,
      );
      expect(result.amounts.totalMinor, BigInt.from(200000));
      expect(
        () => UniversalPricingEngine().calculate(
          product.rule,
          UniversalPricingRequest(
            inputs: {'height': n('8', 'ft'), 'width': n('3', 'ft')},
            quantity: 1,
          ),
          at: now,
        ),
        throwsStateError,
      );
    },
  );
  test('kit components and once-per-order delivery retain distinct scopes', () {
    final draft = setup('component');
    draft.rows('components').first.addAll({
      'name': 'Hardware kit',
      'amount': '100',
    });
    draft
        .rows('extras')
        .add(
          ProductSetup.componentDraft()
            ..addAll({'name': 'Delivery', 'amount': '50', 'type': 'perOrder'}),
        );
    final product = draft.compile('shop', currency);
    final result = UniversalPricingEngine().calculate(
      product.rule,
      UniversalPricingRequest(inputs: {}, quantity: 2),
      at: now,
    );
    expect(result.amounts.totalMinor, BigInt.from(25000));
  });
  test(
    'optional accessories become inputs and are priced only when selected',
    () {
      final draft = setup('perUnit', rate: '100');
      draft
          .rows('extras')
          .add(
            ProductSetup.componentDraft()..addAll({
              'id': 'lock',
              'name': 'Lock',
              'amount': '25',
              'optional': true,
            }),
          );
      final calculator = CalculatorSession(clock: () => now)
        ..select(draft.compile('shop', currency));
      expect(calculator.result!.amounts.totalMinor, BigInt.from(10000));
      calculator.change('include_lock', 'checked', true);
      expect(calculator.result!.amounts.totalMinor, BigInt.from(12500));
      calculator.dispose();
    },
  );
  test('tax, discount and measure policy are explicit and deterministic', () {
    final draft = setup('area', rate: '100');
    draft.data.addAll({
      'minimum': '24',
      'discountPercent': '10',
      'taxBehavior': 'exclusive',
      'taxPercent': '18',
    });
    final product = draft.compile('shop', currency);
    final result = UniversalPricingEngine().calculate(
      product.rule,
      UniversalPricingRequest(
        inputs: {'height': n('7', 'ft'), 'width': n('3', 'ft')},
        quantity: 2,
      ),
      at: now,
    );
    expect(result.base.single.billable, Exact.integer(24));
    expect(result.amounts.totalMinor, BigInt.from(509760));
    expect(result.warnings, contains('Minimum: 24 ft2'));
    draft.data['taxBehavior'] = 'inclusive';
    final included = UniversalPricingEngine().calculate(
      draft.compile('shop', currency).rule,
      UniversalPricingRequest(
        inputs: {'height': n('7', 'ft'), 'width': n('3', 'ft')},
        quantity: 2,
      ),
      at: now,
    );
    expect(included.amounts.totalMinor, BigInt.from(432000));
  });
  test(
    'custom variables compile without a new screen and division by zero fails',
    () {
      final draft = setup('formula', rate: '100');
      draft.rows('fields').add(inputDraft('extra_area', 'Extra area', 'ft2'));
      draft.rows('rates').add({
        'id': 'extra',
        'key': 'extra',
        'amount': '50',
        'unit': 'ft2',
        'selectors': <String, dynamic>{},
      });
      draft.data['formula'] = opDraft(
        'add',
        draft.data['formula'] as Map<String, dynamic>,
        opDraft('multiply', refDraft('extra_area'), refDraft('rate:extra')),
      );
      final result = UniversalPricingEngine().calculate(
        draft.compile('shop', currency).rule,
        UniversalPricingRequest(
          inputs: {
            'height': n('7', 'ft'),
            'width': n('3', 'ft'),
            'extra_area': n('2', 'ft2'),
          },
          quantity: 1,
        ),
        at: now,
      );
      expect(result.amounts.totalMinor, BigInt.from(220000));
      draft.data['formula'] = opDraft(
        'divide',
        literalDraft('1', 'money'),
        literalDraft('0'),
      );
      expect(() => draft.compile('shop', currency), throwsArgumentError);
    },
  );
}
