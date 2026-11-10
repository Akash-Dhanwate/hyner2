import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/pricing/application/calculator_session.dart';
import 'package:hyner/features/pricing/application/product_setup.dart';
import 'package:hyner/features/pricing/domain/exact.dart';
import 'package:hyner/features/pricing/domain/serialization.dart';

import 'support/setup_fixture.dart';

void main() {
  late CalculatorSession session;
  setUp(() => session = CalculatorSession(clock: () => now));
  tearDown(() => session.dispose());
  void dimensions() {
    session.change('height', 'text', '7');
    session.change('width', 'text', '3');
  }

  test('switching categories preserves measurements and quantity, uses each rate, and never changes rules', () {
    final basic = setup('area', name: 'Basic').compile('shop', currency);
    final premium = setup(
      'area',
      name: 'Premium',
      rate: '200',
    ).compile('shop', currency);
    final original = canonicalJson(basic.rule.toJson());
    session.select(basic);
    dimensions();
    session.changeQuantity('2');
    expect(session.result!.amounts.totalMinor, BigInt.from(630000));
    session.select(premium);
    expect(session.entries['height']!['text'], '7');
    expect(session.quantity, '2');
    expect(session.result!.amounts.totalMinor, BigInt.from(840000));
    session.select(basic);
    expect(session.result!.amounts.totalMinor, BigInt.from(630000));
    expect(canonicalJson(basic.rule.toJson()), original);
  });
  test('a new required thickness retains dimensions but removes the invalid final price', () {
    session.select(setup('area').compile('shop', currency));
    dimensions();
    final glass = setup('area');
    glass.rows('fields').add(inputDraft('thickness', 'Thickness', 'mm'));
    session.select(glass.compile('shop', currency));
    expect(session.entries['height']!['text'], '7');
    expect(session.entries['width']!['text'], '3');
    expect(session.result, isNull);
    expect(session.error, 'Enter Thickness');
    session.change('thickness', 'text', '12');
    expect(session.result, isNotNull);
  });
  test('out-of-range measurements stay visible on category switch', () {
    session.select(setup('area').compile('shop', currency));
    dimensions();
    final small = setup('area');
    small.rows('fields').first['maximum'] = '6';
    session.select(small.compile('shop', currency));
    expect(session.entries['height']!['text'], '7');
    expect(session.result, isNull);
    expect(session.error, contains('Height'));
  });
  test('quantity and dimensions reject zero, negative and malformed input without stale totals', () {
    session.select(setup('area').compile('shop', currency));
    dimensions();
    for (final invalid in ['0', '-1', '1.5', '', '1000001']) {
      session.changeQuantity(invalid);
      expect(session.result, isNull);
    }
    session.stepQuantity(-1);
    expect(session.quantity, '1000000');
    session.changeQuantity('1');
    session.stepQuantity(-1);
    expect(session.quantity, '1');
    for (final invalid in ['0', '-1', 'bad', '']) {
      session.change('height', 'text', invalid);
      expect(session.result, isNull);
    }
  });
  test('feet plus inches and inches are calculated exactly', () {
    session.select(setup('area').compile('shop', currency));
    dimensions();
    session.change('height', 'unit', 'ft_in');
    session.change('height', 'inches', '0');
    expect(session.result!.amounts.totalMinor, BigInt.from(315000));
    session.change('height', 'inches', '12');
    expect(session.result, isNull);
    // Correct the invalid edit before converting; units never reinterpret it.
    session.change('height', 'inches', '0');
    session.change('height', 'unit', 'in');
    expect(session.entries['height']!['text'], '84');
    session.change('height', 'text', '84');
    session.change('width', 'unit', 'in');
    session.change('width', 'text', '36');
    expect(session.result!.amounts.totalMinor, BigInt.from(315000));
  });
  test('restored calculator inputs and quantity reproduce the same total', () {
    final product = setup('area').compile('shop', currency);
    session.select(product);
    dimensions();
    session.changeQuantity('3');
    final state = jsonObject(canonicalJson(session.toJson()));
    final other = CalculatorSession(clock: () => now)
      ..select(product)
      ..restore(state);
    expect(
      other.result!.amounts.totalMinor,
      session.result!.amounts.totalMinor,
    );
    expect(other.entries['width']!['text'], '3');
    other.dispose();
  });
  test(
    'defaults stay schema-defined and common selector offers five lengths',
    () {
      session.select(setup('area').compile('shop', currency));
      expect(session.useSameUnit, isTrue);
      expect(session.commonLengthUnit, 'ft');
      expect(session.availableLengthUnits, ['in', 'ft', 'mm', 'cm', 'm']);
      final door = setup('area');
      for (final field in door.rows('fields')) {
        field['unit'] = 'in';
      }
      final fresh = CalculatorSession(clock: () => now)
        ..select(door.compile('shop', currency));
      addTearDown(fresh.dispose);
      expect(fresh.commonLengthUnit, 'in');
      expect(fresh.entries['height']!['unit'], 'in');
    },
  );

  test(
    'linked changes convert every dimension exactly without changing price',
    () {
      final draft = setup('area');
      draft.rows('fields').add(inputDraft('thickness', 'Thickness', 'mm'));
      final product = draft.compile('shop', currency);
      final original = canonicalJson(product.rule.toJson());
      session.select(product);
      dimensions();
      session.change('thickness', 'text', '25.4');
      final total = session.result!.amounts.totalMinor;
      for (final unit in ['in', 'mm', 'cm', 'm', 'ft']) {
        session.change('height', 'unit', unit);
        for (final id in ['height', 'width', 'thickness']) {
          expect(session.entries[id]!['unit'], unit);
        }
        expect(session.result!.amounts.totalMinor, total);
        expect(
          session.result!.inputs.numbers['height']!.value,
          Exact.parse('2.1336'),
        );
      }
      expect(session.entries['height']!['text'], '7');
      expect(canonicalJson(product.rule.toJson()), original);
    },
  );

  test('separate units and mixed feet/inches preserve the physical size', () {
    session.select(setup('area').compile('shop', currency));
    dimensions();
    session.setUseSameUnit(false);
    session.change('height', 'unit', 'in');
    expect(session.entries['height']!['text'], '84');
    expect(session.entries['width']!['text'], '3');
    expect(session.entries['width']!['unit'], 'ft');
    session.change('height', 'text', '85.5');
    final total = session.result!.amounts.totalMinor;
    session.change('height', 'unit', 'ft_in');
    expect(session.entries['height']!['text'], '7');
    expect(session.entries['height']!['inches'], '1.5');
    expect(session.result!.amounts.totalMinor, total);
    session.change('height', 'unit', 'cm');
    expect(session.entries['height']!['text'], '217.17');
    expect(session.result!.amounts.totalMinor, total);
    session.setUseSameUnit(true);
    expect(session.entries['width']!['unit'], session.commonLengthUnit);
    expect(session.result!.amounts.totalMinor, total);
  });

  test(
    'repeating conversions retain source across restore and clear on edit',
    () {
      final product = setup(
        'area',
        rate: '1000000000',
      ).compile('shop', currency);
      session.select(product);
      session.changeLengthUnit('mm');
      session.change('height', 'text', '1');
      session.change('width', 'text', '1000');
      final total = session.result!.amounts.totalMinor;
      session.changeLengthUnit('ft');
      expect(session.entries['height']!['text'], '0.003281');
      expect(session.isRounded('height'), isTrue);
      expect(session.result!.amounts.totalMinor, total);
      expect(session.publicPriceText(), contains('Height: ≈ '));
      final other = CalculatorSession(clock: () => now)
        ..select(product)
        ..restore(jsonObject(canonicalJson(session.toJson())));
      addTearDown(other.dispose);
      expect(other.result!.amounts.totalMinor, total);
      expect(other.isRounded('height'), isTrue);
      other.changeLengthUnit('mm');
      expect(other.entries['height']!['text'], '1');
      expect(other.isRounded('height'), isFalse);
      expect(other.result!.amounts.totalMinor, total);
      session.change('height', 'text', session.entries['height']!['text']);
      expect(session.entries['height']!.containsKey('source'), isFalse);
      expect(session.isRounded('height'), isFalse);
      expect(session.result!.amounts.totalMinor, isNot(total));
    },
  );

  test('editing mixed inches clears the exact source too', () {
    session.select(setup('area').compile('shop', currency));
    dimensions();
    session.setUseSameUnit(false);
    session.change('height', 'unit', 'mm');
    session.change('height', 'text', '1');
    session.change('height', 'unit', 'ft_in');
    expect(session.isRounded('height'), isTrue);
    session.change('height', 'inches', '1');
    expect(session.entries['height']!.containsKey('source'), isFalse);
    expect(
      session.result!.inputs.numbers['height']!.value,
      Exact.parse('0.0254'),
    );
  });

  test('linked choice and exact values survive product switches', () {
    final basic = setup('area').compile('shop', currency);
    final premium = setup('area', rate: '200').compile('shop', currency);
    session.select(basic);
    dimensions();
    session.changeLengthUnit('cm');
    session.setUseSameUnit(false);
    session.change('width', 'unit', 'mm');
    session.select(premium);
    expect(session.useSameUnit, isFalse);
    expect(session.entries['height']!['text'], '213.36');
    expect(session.entries['width']!['text'], '914.4');
    expect(session.result!.amounts.totalMinor, BigInt.from(420000));
    session.setUseSameUnit(true);
    session.select(basic);
    expect(session.useSameUnit, isTrue);
    expect(session.entries['width']!['unit'], 'cm');
    expect(session.result!.amounts.totalMinor, BigInt.from(315000));
  });

  test('restricted compatible unit on next product keeps an exact source', () {
    session.select(setup('area').compile('shop', currency));
    dimensions();
    final next = setup('area');
    for (final field in next.rows('fields')) {
      field['unit'] = 'm';
      field['permitted'] = ['m'];
      field['precision'] = '3';
    }
    final product = next.compile('shop', currency);
    final original = canonicalJson(product.rule.toJson());
    session.select(product);
    expect(session.entries['height']!['text'], '2.134');
    expect(session.isRounded('height'), isTrue);
    expect(session.result!.amounts.totalMinor, BigInt.from(315000));
    expect(canonicalJson(product.rule.toJson()), original);
    final other = CalculatorSession(clock: () => now)
      ..select(product)
      ..restore(jsonObject(canonicalJson(session.toJson())));
    addTearDown(other.dispose);
    expect(other.result!.amounts.totalMinor, BigInt.from(315000));
  });

  test(
    'invalid unit changes never reinterpret an invalid or over-precise edit',
    () {
      session.select(setup('area').compile('shop', currency));
      dimensions();
      session.setUseSameUnit(false);
      for (final text in ['bad', '1.0000001']) {
        session.change('height', 'text', text);
        session.change('height', 'unit', 'in');
        expect(session.entries['height']!['unit'], 'ft');
        expect(session.entries['height']!['text'], text);
        expect(session.result, isNull);
      }
      expect(() => session.change('height', 'unit', 'kg'), throwsArgumentError);
    },
  );

  test(
    'hidden compatible lengths convert but mass and commercial fields do not',
    () {
      final draft = setup('area');
      draft.rows('fields').addAll([
        inputDraft('include', 'Include depth', 'number')
          ..addAll({'type': 'boolean', 'default': 'false'}),
        inputDraft('depth', 'Depth', 'mm')..addAll({
          'default': '25.4',
          'visibleField': 'include',
          'visibleValue': 'true',
        }),
        inputDraft('weight', 'Weight', 'kg')..['default'] = '1',
      ]);
      session.select(draft.compile('shop', currency));
      dimensions();
      session.changeLengthUnit('in');
      expect(session.entries['depth']!['unit'], 'in');
      expect(session.entries['depth']!['text'], '1');
      expect(session.entries['weight']!['unit'], 'kg');
      session.change('include', 'checked', true);
      expect(session.result, isNotNull);
      expect(
        session.result!.inputs.numbers['depth']!.value,
        Exact.parse('0.0254'),
      );
    },
  );

  test(
    'override uses exact arithmetic, warns, persists and resets stored rate',
    () {
      final product = setup('area').compile('shop', currency);
      final original = canonicalJson(product.rule.toJson());
      session.select(product);
      dimensions();
      expect(session.availableBaseRateText, '150');
      expect(session.availableBaseRateUnit, 'ft2');
      expect(session.hasBaseRateOverride, isFalse);
      session.setBaseRateOverride('100.125');
      expect(session.baseRateOverrideText, '100.125');
      expect(session.result!.amounts.totalMinor, BigInt.from(210263));
      expect(
        session.result!.warnings,
        contains(contains('Base rate overridden')),
      );
      expect(session.publicPriceText(), contains('Stored rates are unchanged'));
      expect(canonicalJson(product.rule.toJson()), original);
      final other = CalculatorSession(clock: () => now)
        ..select(product)
        ..restore(jsonObject(canonicalJson(session.toJson())));
      addTearDown(other.dispose);
      expect(other.baseRateOverrideText, '100.125');
      expect(other.result!.amounts.totalMinor, BigInt.from(210263));
      other.resetBaseRateOverride();
      expect(other.baseRateOverrideText, isNull);
      expect(other.result!.amounts.totalMinor, BigInt.from(315000));
      expect(
        other.result!.warnings,
        isNot(contains(contains('Base rate overridden'))),
      );
    },
  );

  test(
    'override is product-scoped and invalid edits cannot leave a stale total',
    () {
      final basic = setup('area').compile('shop', currency);
      final premium = setup('area', rate: '200').compile('shop', currency);
      session.select(basic);
      dimensions();
      for (final text in ['', '-1', '1e3', '1000000000001']) {
        session.setBaseRateOverride(text);
        expect(session.result, isNull);
        expect(session.error, isNotNull);
        expect(session.baseRateOverrideText, text);
      }
      session.setBaseRateOverride('100');
      session.select(basic);
      expect(session.baseRateOverrideText, '100');
      final saved = jsonObject(canonicalJson(session.toJson()));
      session.select(premium);
      expect(session.hasBaseRateOverride, isFalse);
      session.restore(saved);
      expect(session.hasBaseRateOverride, isFalse);
      expect(session.result!.amounts.totalMinor, BigInt.from(420000));
      session.select(basic);
      expect(session.hasBaseRateOverride, isFalse);
    },
  );

  test('selector-based base rates do not expose an override', () {
    final draft = setup('perUnit');
    draft
        .rows('fields')
        .add(
          inputDraft('finish', 'Finish', 'number')..addAll({
            'type': 'choice',
            'choices': 'Basic,Premium',
            'default': 'Basic',
          }),
        );
    draft.rows('rates').first['selectors'] = {'finish': 'Basic'};
    session.select(draft.compile('shop', currency));
    expect(session.availableBaseRateText, isNull);
    expect(session.availableBaseRateUnit, isNull);
    expect(() => session.setBaseRateOverride('10'), throwsStateError);
  });

  test(
    'restore bounds and checks source projection rather than trusting flags',
    () {
      final product = setup('area').compile('shop', currency);
      session.select(product);
      dimensions();
      session.changeLengthUnit('mm');
      final saved = jsonObject(canonicalJson(session.toJson()));
      final height = (saved['entries'] as Map)['height'] as Map;
      (height['source'] as Map)['text'] = '999';
      final width = (saved['entries'] as Map)['width'] as Map;
      width['inches'] = '0' * 257;
      final other = CalculatorSession(clock: () => now)..select(product);
      addTearDown(other.dispose);
      other.restore(saved);
      expect(other.entries['height']!['text'], '');
      expect(other.entries['width']!['text'], '');
      expect(other.result, isNull);
      other.restore({...saved, 'entries': [], 'quantity': '2'});
      expect(other.quantity, '1');
      final noProduct = CalculatorSession(clock: () => now);
      addTearDown(noProduct.dispose);
      expect(() => noProduct.restore(saved), returnsNormally);
    },
  );

  test(
    'share payload excludes private alternate rates and internal rule data',
    () {
      final draft = setup('perUnit', rate: '100');
      final variant = inputDraft('variant', 'Finish', 'number')
        ..addAll({
          'type': 'choice',
          'choices': 'Basic,Premium',
          'default': 'Basic',
        });
      draft.rows('fields').add(variant);
      draft.rows('rates').add({
        'id': 'private-rate',
        'key': 'base',
        'amount': '9999',
        'unit': '',
        'selectors': {'variant': 'Premium'},
      });
      session.select(draft.compile('shop', currency));
      final text = session.publicPriceText();
      expect(text, contains('₹100.00'));
      expect(text, isNot(contains('9999')));
      expect(text, isNot(contains('private-rate')));
      expect(text, isNot(contains('rateLookup')));
      expect(text, isNot(contains('businessId')));
    },
  );
  test(
    'money and measurement display do not use floating-point conversions',
    () {
      expect(
        moneyText(BigInt.parse('1234567890123456789'), currency),
        '₹12,345,678,901,234,567.89',
      );
      expect(decimalText(Exact.parse('0.1')), '0.1');
      expect(decimalText(Exact.parse('1/3'), approximate: true), '≈ 0.333333');
    },
  );
}
