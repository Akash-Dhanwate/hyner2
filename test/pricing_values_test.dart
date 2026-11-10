import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/features/pricing/domain/door_template.dart';
import 'package:hyner/features/pricing/domain/exact.dart';
import 'package:hyner/features/pricing/domain/measurements.dart';
import 'package:hyner/features/pricing/domain/pricing_models.dart';
import 'package:hyner/features/pricing/domain/serialization.dart';

void main() {
  group('Exact', () {
    test('reduces fractions, normalizes signs, and canonicalizes zero', () {
      final half = Exact(BigInt.from(-6), BigInt.from(-12));
      expect(half.numerator, BigInt.one);
      expect(half.denominator, BigInt.two);
      expect(half, Exact.parse('0.5000'));
      expect(half.hashCode, Exact.parse('2/4').hashCode);
      expect({half, Exact.parse('1/2')}, hasLength(1));
      expect(Exact(BigInt.from(6), BigInt.from(-12)), Exact.parse('-0.5'));
      expect(Exact(BigInt.zero, BigInt.from(-99)).toString(), '0');
      expect(Exact.parse('-0.000'), Exact.zero);
      expect(Exact.parse('12/3').isInteger, isTrue);
      expect(half.isInteger, isFalse);
      expect(half.toString(), '1/2');
    });

    test('decimal and fractional arithmetic never loses precision', () {
      expect(Exact.parse('0.1') + Exact.parse('0.2'), Exact.parse('0.3'));
      expect(Exact.parse('0.3') - Exact.parse('0.2'), Exact.parse('0.1'));
      expect(Exact.parse('1/3') + Exact.parse('1/6'), Exact.parse('1/2'));
      expect(Exact.parse('-2/3') * Exact.parse('9/4'), Exact.parse('-1.5'));
      expect(Exact.parse('7/3') / Exact.parse('-14/9'), Exact.parse('-1.5'));
      expect(Exact.parse('1/3') * Exact.integer(3), Exact.one);
      expect(Exact.parse('00012.3400'), Exact.parse('617/50'));
    });

    test('orders signed fractions and finds the maximum exactly', () {
      final values = [
        '1/3',
        '-1/3',
        '0',
        '2/3',
        '-2/3',
      ].map(Exact.parse).toList()..sort();
      expect(values.map((value) => value.toString()), [
        '-2/3',
        '-1/3',
        '0',
        '1/3',
        '2/3',
      ]);
      expect(Exact.parse('1/3') < Exact.parse('0.34'), isTrue);
      expect(Exact.parse('1/3') > Exact.parse('0.33'), isTrue);
      expect(Exact.parse('1/2') <= Exact.parse('0.5'), isTrue);
      expect(Exact.parse('1/2') >= Exact.parse('0.5'), isTrue);
      expect(Exact.parse('1/2').compareTo(Exact.parse('0.5')), 0);
      expect(Exact.parse('-1/3').max(Exact.parse('-1/2')), Exact.parse('-1/3'));
    });

    test('preserves integers and fractions far beyond machine precision', () {
      final huge = BigInt.parse(
        '123456789012345678901234567890123456789012345678901',
      );
      final value = Exact(huge);
      final next = Exact(huge + BigInt.one);
      expect(next > value, isTrue);
      expect(next - value, Exact.one);
      expect((value * next) / next, value);
      expect(Exact.parse('$huge'), value);
      expect(Exact.parse('${huge * BigInt.from(3)}/3'), value);
      expect(
        Exact.parse(Exact(huge, BigInt.from(7)).toString()),
        Exact(huge, BigInt.from(7)),
      );
      final tiny = Exact(BigInt.one, BigInt.from(10).pow(100));
      expect(value + tiny > value, isTrue);
      expect((value + tiny) - value, tiny);
    });

    test('rejects division by zero through every entry point', () {
      expect(() => Exact(BigInt.one, BigInt.zero), throwsFormatException);
      expect(() => Exact.parse('1/0'), throwsFormatException);
      expect(() => Exact.parse('0/0'), throwsFormatException);
      expect(() => Exact.one / Exact.zero, throwsFormatException);
    });

    test('rejects ambiguous, nonfinite, and nondecimal input', () {
      for (final input in [
        '',
        ' ',
        ' 1',
        '1 ',
        '+1',
        '.5',
        '1.',
        '1e3',
        '0x10',
        '1,000',
        'NaN',
        'Infinity',
        '--1',
        '1/-2',
        '1/2/3',
        '1.2.3',
      ]) {
        expect(() => Exact.parse(input), throwsFormatException, reason: input);
      }
    });

    test('enforces the input length boundary without truncation', () {
      final longest = List.filled(256, '9').join();
      expect(Exact.parse(longest).numerator, BigInt.parse(longest));
      expect(() => Exact.parse('${longest}9'), throwsFormatException);
    });

    for (final (input, increment, expected) in [
      ('0', '0.25', '0'),
      ('1', '0.25', '1'),
      ('1.001', '0.25', '1.25'),
      ('1.25', '0.25', '1.25'),
      ('1.251', '0.25', '1.5'),
      ('-1.251', '0.25', '-1.25'),
      ('-1.25', '0.25', '-1.25'),
      ('-1.001', '0.25', '-1'),
      ('-0.1', '0.25', '0'),
      ('2/3', '1/4', '3/4'),
    ]) {
      test('ceilTo($input, $increment) is $expected', () {
        expect(
          Exact.parse(input).ceilTo(Exact.parse(increment)),
          Exact.parse(expected),
        );
      });
    }

    test('ceilTo rejects zero and negative increments', () {
      expect(() => Exact.one.ceilTo(Exact.zero), throwsArgumentError);
      expect(() => Exact.one.ceilTo(Exact.parse('-0.1')), throwsArgumentError);
    });

    // Expected columns are half-up, half-even, and truncation toward zero.
    for (final (input, halfUp, halfEven, down) in [
      ('0', 0, 0, 0),
      ('2', 2, 2, 2),
      ('-2', -2, -2, -2),
      ('0.49999999999999999999', 0, 0, 0),
      ('0.5', 1, 0, 0),
      ('0.50000000000000000001', 1, 1, 0),
      ('1.5', 2, 2, 1),
      ('2.5', 3, 2, 2),
      ('3.5', 4, 4, 3),
      ('2.9', 3, 3, 2),
      ('-0.49999999999999999999', 0, 0, 0),
      ('-0.5', -1, 0, 0),
      ('-0.50000000000000000001', -1, -1, 0),
      ('-1.5', -2, -2, -1),
      ('-2.5', -3, -2, -2),
      ('-3.5', -4, -4, -3),
      ('-2.9', -3, -3, -2),
    ]) {
      test('rounding modes handle $input', () {
        final value = Exact.parse(input);
        expect(value.roundInteger(MoneyRounding.halfUp), BigInt.from(halfUp));
        expect(
          value.roundInteger(MoneyRounding.halfEven),
          BigInt.from(halfEven),
        );
        expect(value.roundInteger(MoneyRounding.down), BigInt.from(down));
      });
    }

    test('rounding large BigInt ties retains parity and sign', () {
      final even = BigInt.from(10).pow(100);
      for (final whole in [even, even + BigInt.one]) {
        for (final sign in [BigInt.one, -BigInt.one]) {
          final tie = Exact(
            sign * (whole * BigInt.two + BigInt.one),
            BigInt.two,
          );
          expect(
            tie.roundInteger(MoneyRounding.halfUp),
            sign * (whole + BigInt.one),
          );
          expect(
            tie.roundInteger(MoneyRounding.halfEven),
            sign * (whole.isEven ? whole : whole + BigInt.one),
          );
          expect(tie.roundInteger(MoneyRounding.down), sign * whole);
        }
      }
    });
  });

  group('Currency', () {
    test('scales all supported minor-digit counts before rounding', () {
      final expected = ['12', '123', '1235', '12346', '123456'];
      for (var digits = 0; digits <= 4; digits++) {
        final currency = Currency('INR', digits);
        expect(
          currency.minor(Exact.parse('12.3456'), MoneyRounding.halfUp),
          BigInt.parse(expected[digits]),
          reason: '$digits minor digits',
        );
        final restored = Currency.fromJson(
          jsonObject(canonicalJson(currency.toJson())),
        );
        expect(restored.code, 'INR');
        expect(restored.minorDigits, digits);
      }
    });

    test('rounds monetary ties only after converting to minor units', () {
      final currency = Currency('INR', 2);
      expect(
        currency.minor(Exact.parse('1.005'), MoneyRounding.halfUp),
        BigInt.from(101),
      );
      expect(
        currency.minor(Exact.parse('1.005'), MoneyRounding.halfEven),
        BigInt.from(100),
      );
      expect(
        currency.minor(Exact.parse('-1.005'), MoneyRounding.halfUp),
        BigInt.from(-101),
      );
      expect(
        currency.minor(Exact.parse('-1.009'), MoneyRounding.down),
        BigInt.from(-100),
      );
      expect(
        currency.minor(
          Exact.parse('0.335') * Exact.integer(3),
          MoneyRounding.halfUp,
        ),
        BigInt.from(101),
      );
      final large = BigInt.from(10).pow(80);
      expect(
        currency.minor(
          Exact(large) + Exact.parse('0.005'),
          MoneyRounding.halfUp,
        ),
        large * BigInt.from(100) + BigInt.one,
      );
    });

    test('rejects invalid currency codes and precision', () {
      for (final code in ['', 'inr', 'InR', 'IN', 'INRR', ' INR', 'I1R']) {
        expect(() => Currency(code, 2), throwsArgumentError, reason: code);
      }
      expect(() => Currency('INR', -1), throwsArgumentError);
      expect(() => Currency('INR', 5), throwsArgumentError);
    });
  });

  group('Measurements', () {
    const oneUnitInMetres = {
      LengthUnit.feet: '0.3048',
      LengthUnit.feetInches: '0.3048',
      LengthUnit.inches: '0.0254',
      LengthUnit.millimetres: '0.001',
      LengthUnit.centimetres: '0.01',
      LengthUnit.metres: '1',
    };
    for (final unit in LengthUnit.values) {
      test(
        '${unit.name} uses the exact metric conversion in both directions',
        () {
          final metres = Exact.parse(oneUnitInMetres[unit]!);
          expect(unit.metresPerUnit, metres);
          expect(unit.toMetres(Exact.one), metres);
          expect(unit.fromMetres(metres), Exact.one);
          expect(unit.toMetres(Exact.zero), Exact.zero);
          final dimensions = Dimensions.entered({Axis.height: Exact.one}, unit);
          expect(dimensions.require(Axis.height), metres);
          expect(dimensions.enteredUnit, unit);
          expect(
            unit.fromMetres(unit.toMetres(Exact.parse('7/3'))),
            Exact.parse('7/3'),
          );
        },
      );
    }

    test('every pair of units agrees on the same one-foot length', () {
      final oneFoot = {
        LengthUnit.feet: Exact.one,
        LengthUnit.feetInches: Exact.one,
        LengthUnit.inches: Exact.integer(12),
        LengthUnit.millimetres: Exact.parse('304.8'),
        LengthUnit.centimetres: Exact.parse('30.48'),
        LengthUnit.metres: Exact.parse('0.3048'),
      };
      for (final source in LengthUnit.values) {
        for (final target in LengthUnit.values) {
          expect(
            target.fromMetres(source.toMetres(oneFoot[source]!)),
            oneFoot[target],
            reason: '${source.name} -> ${target.name}',
          );
        }
      }
    });

    test('feet and inches are mixed units, including fractional inches', () {
      final sevenSix = Dimensions.feetAndInches(
        feet: 7,
        inches: Exact.integer(6),
      );
      expect(sevenSix, Exact.parse('2.286'));
      expect(LengthUnit.feet.fromMetres(sevenSix), Exact.parse('7.5'));
      expect(sevenSix, isNot(LengthUnit.feet.toMetres(Exact.parse('7.6'))));
      expect(
        Dimensions.feetAndInches(feet: 0, inches: Exact.parse('1/2')),
        Exact.parse('0.0127'),
      );
      expect(
        Dimensions.feetAndInches(feet: 1, inches: Exact.zero),
        Exact.parse('0.3048'),
      );
      expect(Dimensions.feetAndInches(feet: 0, inches: Exact.zero), Exact.zero);
      expect(
        Dimensions.feetAndInches(feet: 0, inches: Exact.parse('11.999')),
        Exact.parse('0.3047746'),
      );
    });

    test('rejects negative feet or inches and inches at or above twelve', () {
      expect(
        () => Dimensions.feetAndInches(feet: -1, inches: Exact.zero),
        throwsArgumentError,
      );
      for (final inches in ['-0.01', '12', '12.001', '24']) {
        expect(
          () => Dimensions.feetAndInches(feet: 1, inches: Exact.parse(inches)),
          throwsArgumentError,
          reason: inches,
        );
      }
    });

    test(
      'area and volume use canonical lengths without intermediate rounding',
      () {
        final dimensions = Dimensions.entered({
          Axis.height: Exact.parse('7.5'),
          Axis.width: Exact.integer(3),
          Axis.depth: Exact.parse('0.25'),
        }, LengthUnit.feet);
        expect(dimensions.squareFeet, Exact.parse('22.5'));
        expect(dimensions.squareMetres, Exact.parse('2.0903184'));
        expect(dimensions.cubicMetres, Exact.parse('0.15928226208'));
      },
    );

    test(
      'missing axes are accepted until the corresponding measure is needed',
      () {
        final heightOnly = Dimensions({Axis.height: Exact.integer(2)});
        expect(heightOnly.require(Axis.height), Exact.integer(2));
        expect(() => heightOnly.require(Axis.width), throwsArgumentError);
        expect(() => heightOnly.squareMetres, throwsArgumentError);
        expect(() => heightOnly.squareFeet, throwsArgumentError);
        final rectangle = Dimensions({
          Axis.height: Exact.integer(2),
          Axis.width: Exact.integer(3),
        });
        expect(rectangle.squareMetres, Exact.integer(6));
        expect(() => rectangle.cubicMetres, throwsArgumentError);
        expect(() => Dimensions({}).require(Axis.height), throwsArgumentError);
      },
    );

    test(
      'validates every axis and checks limits after conversion to metres',
      () {
        for (final axis in Axis.values) {
          for (final value in ['0', '-0.001', '1000000.0001']) {
            expect(
              () => Dimensions({axis: Exact.parse(value)}),
              throwsArgumentError,
              reason: '${axis.name}: $value',
            );
          }
        }
        expect(
          Dimensions({Axis.height: Exact.parse('0.000001')})
              .require(Axis.height),
          Exact.parse('0.000001'),
        );
        expect(
          Dimensions.entered({
            Axis.height: Exact.parse('1000000000'),
          }, LengthUnit.millimetres).require(Axis.height),
          Exact.integer(1000000),
        );
        expect(
          () => Dimensions.entered({
            Axis.height: Exact.parse('1000000000.1'),
          }, LengthUnit.millimetres),
          throwsArgumentError,
        );
      },
    );

    test('copies input maps and exposes an immutable map', () {
      final input = {
        Axis.height: Exact.integer(2),
        Axis.width: Exact.integer(3),
      };
      final dimensions = Dimensions(input);
      input[Axis.height] = Exact.integer(99);
      input.remove(Axis.width);
      expect(dimensions.squareMetres, Exact.integer(6));
      expect(
        () => dimensions.metres[Axis.height] = Exact.one,
        throwsUnsupportedError,
      );
      expect(() => dimensions.metres.clear(), throwsUnsupportedError);
      final enteredInput = {Axis.height: Exact.integer(12)};
      final entered = Dimensions.entered(enteredInput, LengthUnit.inches);
      enteredInput.clear();
      expect(entered.require(Axis.height), Exact.parse('0.3048'));
    });
  });

  group('Policy and model validation', () {
    test(
      'dimension ranges allow equal bounds but require positive ordered bounds',
      () {
        final range = DimensionRange(Exact.one, Exact.one);
        expect(range.minimum, range.maximum);
        expect(
          () => DimensionRange(Exact.zero, Exact.one),
          throwsArgumentError,
        );
        expect(
          () => DimensionRange(Exact.parse('-1'), Exact.one),
          throwsArgumentError,
        );
        expect(
          () => DimensionRange(Exact.integer(2), Exact.one),
          throwsArgumentError,
        );
      },
    );

    test(
      'billing defaults do not introduce charges or rounding increments',
      () {
        final policy = BillingPolicy();
        expect(policy.minimumMeasure, Exact.zero);
        expect(policy.minimumPrice, Exact.zero);
        expect(policy.minimumQuantity, 1);
        expect(policy.measureIncrement, isNull);
        expect(policy.dimensionIncrementMetres, isNull);
        expect(policy.stockedSizes, isEmpty);
        expect(policy.ranges, isEmpty);
      },
    );

    test('billing rejects negative minimums and nonpositive increments or quantity', () {
      for (final create in <BillingPolicy Function()>[
        () => BillingPolicy(minimumMeasure: Exact.parse('-0.01')),
        () => BillingPolicy(minimumPrice: Exact.parse('-0.01')),
        () => BillingPolicy(minimumQuantity: 0),
        () => BillingPolicy(measureIncrement: Exact.zero),
        () => BillingPolicy(measureIncrement: Exact.parse('-1')),
        () => BillingPolicy(dimensionIncrementMetres: Exact.zero),
        () => BillingPolicy(dimensionIncrementMetres: Exact.parse('-1')),
      ]) {
        expect(create, throwsArgumentError);
      }
      final size = Dimensions({Axis.height: Exact.one});
      expect(
        BillingPolicy(stockedSizes: List.filled(200, size)).stockedSizes,
        hasLength(200),
      );
      expect(
        () => BillingPolicy(stockedSizes: List.filled(201, size)),
        throwsArgumentError,
      );
    });

    test(
      'billing copies stocked sizes and ranges, including nested dimensions',
      () {
        final axes = {Axis.height: Exact.integer(2)};
        final size = Dimensions(axes);
        final sizes = [size];
        final range = DimensionRange(Exact.one, Exact.integer(3));
        final ranges = {Axis.height: range};
        final policy = BillingPolicy(stockedSizes: sizes, ranges: ranges);
        axes.clear();
        sizes.clear();
        ranges.clear();
        expect(
          policy.stockedSizes.single.require(Axis.height),
          Exact.integer(2),
        );
        expect(policy.ranges[Axis.height], same(range));
        expect(() => policy.stockedSizes.add(size), throwsUnsupportedError);
        expect(() => policy.ranges.clear(), throwsUnsupportedError);
        expect(
          () => policy.stockedSizes.single.metres.clear(),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'tax requires a reference and valid rates with zero for exemptions',
      () {
        for (final behavior in TaxBehavior.values) {
          expect(
            TaxPolicy(
              reference: 'configured-tax',
              behavior: behavior,
              percent: Exact.zero,
            ).percent,
            Exact.zero,
          );
        }
        expect(
          TaxPolicy(
            reference: 'configured-tax',
            behavior: TaxBehavior.inclusive,
            percent: Exact.integer(100),
          ).percent,
          Exact.integer(100),
        );
        for (final create in <TaxPolicy Function()>[
          () => TaxPolicy(
            reference: '  ',
            behavior: TaxBehavior.exclusive,
            percent: Exact.zero,
          ),
          () => TaxPolicy(
            reference: 'tax',
            behavior: TaxBehavior.exclusive,
            percent: Exact.parse('-0.01'),
          ),
          () => TaxPolicy(
            reference: 'tax',
            behavior: TaxBehavior.inclusive,
            percent: Exact.parse('100.01'),
          ),
          () => TaxPolicy(
            reference: 'tax',
            behavior: TaxBehavior.exempt,
            percent: Exact.one,
          ),
        ]) {
          expect(create, throwsArgumentError);
        }
      },
    );

    test(
      'discount validates quantity, fixed amount, and percentage boundaries',
      () {
        final empty = DiscountPolicy();
        expect(empty.minimumQuantity, 1);
        expect(empty.fixedPerLine, Exact.zero);
        expect(empty.percent, Exact.zero);
        expect(
          DiscountPolicy(percent: Exact.integer(100)).percent,
          Exact.integer(100),
        );
        for (final create in <DiscountPolicy Function()>[
          () => DiscountPolicy(minimumQuantity: 0),
          () => DiscountPolicy(fixedPerLine: Exact.parse('-0.01')),
          () => DiscountPolicy(percent: Exact.parse('-0.01')),
          () => DiscountPolicy(percent: Exact.parse('100.01')),
        ]) {
          expect(create, throwsArgumentError);
        }
      },
    );

    test(
      'add-on percentages are bounded, while flat charges can exceed 100',
      () {
        for (final method in AddonMethod.values) {
          final addon = _addon(method: method, rate: Exact.integer(100));
          expect(addon.rate, Exact.integer(100));
          expect(
            () => _addon(method: method, rate: Exact.parse('-0.01')),
            throwsArgumentError,
          );
          if (method != AddonMethod.percentage) {
            expect(
              _addon(method: method, rate: Exact.integer(101)).rate,
              Exact.integer(101),
            );
          }
        }
        expect(
          () => _addon(
            method: AddonMethod.percentage,
            rate: Exact.parse('100.01'),
          ),
          throwsArgumentError,
        );
      },
    );

    test('IDs and names enforce their syntax and length boundaries', () {
      expect(() => validateId('a-Z_09'), returnsNormally);
      expect(() => validateId(List.filled(100, 'a').join()), returnsNormally);
      expect(() => validateName(List.filled(120, 'a').join()), returnsNormally);
      for (final id in [
        '',
        'has space',
        'path/id',
        'a.b',
        List.filled(101, 'a').join(),
      ]) {
        expect(() => validateId(id), throwsArgumentError, reason: id);
      }
      for (final name in ['', ' \t\n', List.filled(121, 'a').join()]) {
        expect(() => validateName(name), throwsArgumentError);
      }
      expect(
        () => PricingCategory(id: 'bad/id', name: 'Door'),
        throwsArgumentError,
      );
      expect(
        () => PricingCategory(id: 'door', name: 'Door', parentId: 'bad/id'),
        throwsArgumentError,
      );
      expect(
        () => PricingVariant(id: 'oak', categoryId: '', name: 'Oak'),
        throwsArgumentError,
      );
      expect(
        () => PricingAddon(
          id: 'hinges',
          name: ' ',
          method: AddonMethod.perItem,
          rate: Exact.one,
        ),
        throwsArgumentError,
      );
      expect(() => _rule(variantId: 'bad/id'), throwsArgumentError);
      expect(
        () => RateCardDraft(name: ' ', currency: Currency('INR', 2)),
        throwsArgumentError,
      );
    });

    test('variant attributes enforce count and individual length limits', () {
      final boundary = {
        List.filled(80, 'k').join(): List.filled(200, 'v').join(),
        for (var index = 1; index < 20; index++) 'key$index': 'value',
      };
      expect(_variant(attributes: boundary).attributes, hasLength(20));
      expect(
        () => _variant(attributes: {...boundary, 'extra': 'value'}),
        throwsArgumentError,
      );
      expect(
        () => _variant(attributes: {List.filled(81, 'k').join(): 'value'}),
        throwsArgumentError,
      );
      expect(
        () => _variant(attributes: {'key': List.filled(201, 'v').join()}),
        throwsArgumentError,
      );
    });

    test(
      'variants and rules defensively copy attributes and add-on references',
      () {
        final attributes = {'finish': 'oak'};
        final variant = _variant(attributes: attributes);
        attributes['finish'] = 'painted';
        expect(variant.attributes['finish'], 'oak');
        expect(
          () => variant.attributes['finish'] = 'painted',
          throwsUnsupportedError,
        );
        final addonIds = ['hinges'];
        final rule = _rule(addonIds: addonIds);
        addonIds.clear();
        expect(rule.addonIds, ['hinges']);
        expect(() => rule.addonIds.add('delivery'), throwsUnsupportedError);
      },
    );

    test('rules accept zero and the upper rate boundary without rounding', () {
      expect(_rule(rate: Exact.zero).rate, Exact.zero);
      expect(
        _rule(rate: Exact.parse('1000000000000')).rate,
        Exact.parse('1000000000000'),
      );
      expect(() => _rule(rate: Exact.parse('-0.0001')), throwsArgumentError);
      expect(
        () => _rule(rate: Exact.parse('1000000000000.0001')),
        throwsArgumentError,
      );
    });

    test('only the seven foundational pricing methods are publishable', () {
      const supported = {
        PricingMethod.piece,
        PricingMethod.squareFoot,
        PricingMethod.squareMetre,
        PricingMethod.runningFoot,
        PricingMethod.metre,
        PricingMethod.cubicMetre,
        PricingMethod.kilogram,
      };
      for (final method in PricingMethod.values) {
        final rule = _rule(method: method);
        expect(rule.supported, supported.contains(method), reason: method.name);
        expect(
          _draft(rules: [rule]).validateForPublish,
          supported.contains(method) ? returnsNormally : throwsStateError,
          reason: method.name,
        );
      }
    });
  });

  group('Rate-card hierarchy and references', () {
    test(
      'accepts an out-of-order hierarchy and distinct category/variant targets',
      () {
        final draft = _draft(
          categories: [
            _category('door', parentId: 'doors'),
            _category('doors'),
          ],
          variants: [
            _variant(),
            _variant(id: 'painted'),
          ],
          addons: [_addon()],
          rules: [
            _rule(id: 'default', addonIds: ['hinges']),
            _rule(id: 'oak_rule', variantId: 'oak'),
            _rule(id: 'painted_rule', variantId: 'painted'),
          ],
        );
        expect(draft.validateForPublish, returnsNormally);
      },
    );

    test(
      'rejects missing parents, self-parenting, and cycles at any depth',
      () {
        for (final categories in [
          [_category('door', parentId: 'missing')],
          [_category('door', parentId: 'door')],
          [_category('a', parentId: 'b'), _category('b', parentId: 'a')],
          [
            _category('a', parentId: 'b'),
            _category('b', parentId: 'c'),
            _category('c', parentId: 'a'),
          ],
          [_category('root'), _category('door', parentId: 'missing')],
        ]) {
          expect(() => _draft(categories: categories), throwsArgumentError);
        }
      },
    );

    test('rejects duplicate IDs in each collection', () {
      expect(
        () => _draft(categories: [_category('door'), _category('door')]),
        throwsArgumentError,
      );
      expect(
        () => _draft(variants: [_variant(), _variant()]),
        throwsArgumentError,
      );
      expect(() => _draft(addons: [_addon(), _addon()]), throwsArgumentError);
      expect(
        () => _draft(
          variants: [_variant()],
          rules: [
            _rule(),
            _rule(variantId: 'oak'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test(
      'rejects variants with missing categories, including inactive variants',
      () {
        expect(
          () => _draft(variants: [_variant(categoryId: 'missing')]),
          throwsArgumentError,
        );
        expect(
          () => _draft(
            variants: [_variant(categoryId: 'missing', active: false)],
          ),
          throwsArgumentError,
        );
      },
    );

    test('rejects rules targeting a missing category or variant', () {
      expect(
        () => _draft(rules: [_rule(categoryId: 'missing')]),
        throwsArgumentError,
      );
      expect(
        () => _draft(rules: [_rule(variantId: 'missing')]),
        throwsArgumentError,
      );
    });

    test('rejects a variant belonging to a different category', () {
      expect(
        () => _draft(
          categories: [_category('door'), _category('window')],
          variants: [_variant(categoryId: 'window')],
          rules: [_rule(variantId: 'oak')],
        ),
        throwsArgumentError,
      );
    });

    test('rejects duplicate targets even when rule IDs are different', () {
      expect(
        () => _draft(
          rules: [
            _rule(id: 'first'),
            _rule(id: 'second'),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => _draft(
          variants: [_variant()],
          rules: [
            _rule(id: 'first', variantId: 'oak'),
            _rule(id: 'second', variantId: 'oak'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects missing or repeated add-on references', () {
      expect(
        () => _draft(
          rules: [
            _rule(addonIds: ['missing']),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => _draft(
          addons: [_addon()],
          rules: [
            _rule(addonIds: ['hinges', 'hinges']),
          ],
        ),
        throwsArgumentError,
      );
    });

    test(
      'draft collections are independent of source lists and unmodifiable',
      () {
        final categories = [_category('door')];
        final variants = [_variant()];
        final rules = [
          _rule(variantId: 'oak', addonIds: ['hinges']),
        ];
        final addons = [_addon()];
        final draft = _draft(
          categories: categories,
          variants: variants,
          rules: rules,
          addons: addons,
        );
        categories.clear();
        variants.clear();
        rules.clear();
        addons.clear();
        expect(draft.categories.single.id, 'door');
        expect(draft.variants.single.id, 'oak');
        expect(draft.rules.single.variantId, 'oak');
        expect(draft.addons.single.id, 'hinges');
        expect(draft.validateForPublish, returnsNormally);
        expect(() => draft.categories.clear(), throwsUnsupportedError);
        expect(() => draft.variants.clear(), throwsUnsupportedError);
        expect(() => draft.rules.clear(), throwsUnsupportedError);
        expect(() => draft.addons.clear(), throwsUnsupportedError);
      },
    );

    test('publishing requires rates for every active leaf', () {
      final categories = [
        _category('doors'),
        _category('door', parentId: 'doors'),
        _category('window'),
      ];
      expect(
        _draft(categories: categories, rules: [_rule()]).validateForPublish,
        throwsStateError,
      );
      expect(
        _draft(
          categories: categories,
          rules: [
            _rule(),
            _rule(id: 'window_rule', categoryId: 'window'),
          ],
        ).validateForPublish,
        returnsNormally,
      );
    });

    test('a category default cannot replace a missing active variant rate', () {
      final variants = [_variant(), _variant(id: 'painted')];
      expect(
        _draft(variants: variants, rules: [_rule()]).validateForPublish,
        throwsStateError,
      );
      expect(
        _draft(
          variants: variants,
          rules: [_rule(variantId: 'oak')],
        ).validateForPublish,
        throwsStateError,
      );
      expect(
        _draft(
          variants: variants,
          rules: [
            _rule(id: 'oak_rule', variantId: 'oak'),
            _rule(id: 'painted_rule', variantId: 'painted'),
          ],
        ).validateForPublish,
        returnsNormally,
      );
    });

    test('inactive leaves and variants do not require their own rates', () {
      expect(
        _draft(
          categories: [_category('door'), _category('retired', active: false)],
          variants: [
            _variant(),
            _variant(id: 'retired_finish', active: false),
          ],
          rules: [_rule(variantId: 'oak')],
        ).validateForPublish,
        returnsNormally,
      );
      expect(
        _draft(
          variants: [_variant(active: false)],
          rules: [_rule()],
        ).validateForPublish,
        returnsNormally,
      );
    });

    test('a parent with only inactive children still needs its own rate', () {
      final categories = [
        _category('doors'),
        _category('door', parentId: 'doors', active: false),
      ];
      expect(
        _draft(categories: categories, rules: [_rule()]).validateForPublish,
        throwsStateError,
      );
      expect(
        _draft(
          categories: categories,
          rules: [_rule(categoryId: 'doors')],
        ).validateForPublish,
        returnsNormally,
      );
    });
  });

  group('Door template', () {
    test(
      'is structure only and cannot publish before rates are configured',
      () {
        final currency = Currency('INR', 2);
        final draft = doorTemplate(currency);
        expect(draft.name, 'Door Price Calculator');
        expect(draft.industryTemplate, 'doors');
        expect(draft.currency, same(currency));
        expect(draft.defaultUnit, LengthUnit.feetInches);
        expect(draft.defaultMethod, PricingMethod.squareFoot);
        expect(draft.categories.map((category) => category.id), [
          'basic_flush',
          'premium_flush',
          'wpc',
          'designer',
        ]);
        expect(draft.categories.map((category) => category.sortOrder), [
          0,
          1,
          2,
          3,
        ]);
        expect(draft.categories.every((category) => category.active), isTrue);
        expect(draft.variants, isEmpty);
        expect(draft.rules, isEmpty);
        expect(draft.addons, isEmpty);
        expect(draft.validateForPublish, throwsStateError);
        final restored = RateCardDraft.fromJson(
          jsonObject(canonicalJson(draft.toJson())),
        );
        expect(restored.validateForPublish, throwsStateError);
      },
    );

    test(
      'partial configuration remains unpublishable; all leaves need rates',
      () {
        final template = doorTemplate(Currency('INR', 2));
        final rules = [
          for (final category in template.categories)
            _rule(id: '${category.id}_rule', categoryId: category.id),
        ];
        expect(
          _draft(
            categories: template.categories,
            rules: rules.take(3).toList(),
          ).validateForPublish,
          throwsStateError,
        );
        expect(
          _draft(
            categories: template.categories,
            rules: rules,
          ).validateForPublish,
          returnsNormally,
        );
      },
    );
  });

  group('Deterministic serialization', () {
    test('recursively sorts object keys and preserves list order and primitives', () {
      final first = <String, Object?>{
        'z': [
          {'z': '2/3', 'a': 1},
          {'b': false, 'a': null},
        ],
        'a': {'z': '0.10', 'a': true},
      };
      final second = <String, Object?>{
        'a': {'a': true, 'z': '0.10'},
        'z': [
          {'a': 1, 'z': '2/3'},
          {'a': null, 'b': false},
        ],
      };
      const expected =
          '{"a":{"a":true,"z":"0.10"},"z":[{"a":1,"z":"2/3"},{"a":null,"b":false}]}';
      expect(canonicalJson(first), expected);
      expect(canonicalJson(second), expected);
      expect(first.keys, ['z', 'a']);
      expect(canonicalJson(['b', 'a']), '["b","a"]');
      expect(canonicalJson(null), 'null');
    });

    test('rejects fractional and unsafe numbers and values outside the JSON contract', () {
      for (final value in <Object>[
        9007199254740992,
        0.1,
        double.nan,
        double.infinity,
        BigInt.one,
        Exact.one,
        DateTime.utc(2026),
        {1: 'non-string key'},
        {1, 2},
        {
          'nested': [0.1],
        },
      ]) {
        expect(
          () => canonicalJson(value),
          throwsArgumentError,
          reason: '$value',
        );
      }
    });

    test(
      'whole metadata numbers normalize identically on VM and JavaScript',
      () {
        expect(canonicalJson({'quantity': 1.0}), '{"quantity":1}');
        expect(canonicalJson(-0.0), '0');
        expect(canonicalJson(9007199254740991), '9007199254740991');
      },
    );

    test('JSON strings retain escapes, Unicode, and numeric strings', () {
      final object = {'name': 'Door "A"\n₹\\finish', 'rate': '1/3', 'count': 3};
      expect(jsonObject(canonicalJson(object)), object);
      expect(() => jsonObject('{'), throwsFormatException);
      for (final nonObject in ['[]', 'null', '1', '"text"']) {
        expect(() => jsonObject(nonObject), throwsA(isA<TypeError>()));
      }
    });

    test('dimensions use canonical exact strings independent of axis insertion order', () {
      final first = Dimensions({
        Axis.width: Exact.parse('0.2'),
        Axis.height: Exact.parse('1/3'),
      }, enteredUnit: LengthUnit.centimetres);
      final second = Dimensions({
        Axis.height: Exact.parse('2/6'),
        Axis.width: Exact.parse('2/10'),
      }, enteredUnit: LengthUnit.centimetres);
      const expected =
          '{"enteredUnit":"centimetres","metres":{"height":"1/3","width":"1/5"}}';
      expect(canonicalJson(first.toJson()), expected);
      expect(canonicalJson(second.toJson()), expected);
      final restored = Dimensions.fromJson(jsonObject(expected));
      expect(restored.metres, first.metres);
      expect(restored.enteredUnit, LengthUnit.centimetres);
    });

    test('a configured card round-trips every nested policy and presentation field', () {
      final original = _configuredDraft();
      final encoded = canonicalJson(original.toJson());
      final restored = RateCardDraft.fromJson(jsonObject(encoded));
      expect(canonicalJson(restored.toJson()), encoded);
      expect(restored.toJson(), original.toJson());
      expect(restored.validateForPublish, returnsNormally);
      expect(restored.description, 'Made-to-order doors');
      expect(restored.currency.code, 'KWD');
      expect(restored.currency.minorDigits, 3);
      expect(restored.rounding, MoneyRounding.halfEven);
      expect(restored.defaultUnit, LengthUnit.millimetres);
      expect(restored.rules.single.rate, Exact.parse('1001/3'));
      expect(restored.rules.single.catalogProductId, 'catalog-door');
      expect(restored.rules.single.billing.minimumMeasure, Exact.parse('1/3'));
      expect(
        restored.rules.single.billing.dimensionIncrementMetres,
        Exact.parse('0.001'),
      );
      expect(
        restored.rules.single.billing.stockedSizes.single.enteredUnit,
        LengthUnit.millimetres,
      );
      expect(
        restored.rules.single.billing.ranges[Axis.height]!.maximum,
        Exact.parse('2.4'),
      );
      expect(restored.rules.single.discount.percent, Exact.parse('2.5'));
      expect(restored.rules.single.tax.behavior, TaxBehavior.inclusive);
      expect(restored.rules.single.tax.percent, Exact.parse('7.5'));
      expect(restored.addons.single.required, isTrue);
      expect(restored.addons.single.included, isTrue);
      expect(restored.addons.single.defaultSelected, isTrue);
      expect(
        () => restored.rules.single.billing.ranges.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => restored.variants.single.attributes.clear(),
        throwsUnsupportedError,
      );
      expect(
        canonicalJson(_configuredDraft(reverseMaps: true).toJson()),
        encoded,
      );
    });

    test('deserialization copies input collections and reruns reference validation', () {
      final input = jsonObject(canonicalJson(_configuredDraft().toJson()));
      final restored = RateCardDraft.fromJson(input);
      final originalJson = canonicalJson(restored.toJson());
      ((input['variants'] as List).single['attributes'] as Map)['finish'] =
          'changed';
      ((input['rules'] as List).single['addonIds'] as List).clear();
      (input['categories'] as List).clear();
      expect(canonicalJson(restored.toJson()), originalJson);
      final broken = jsonObject(originalJson);
      (broken['rules'] as List).single['categoryId'] = 'missing';
      expect(() => RateCardDraft.fromJson(broken), throwsArgumentError);
    });

    test('rejects unsupported or missing schema versions', () {
      for (final version in <Object?>[null, 0, 2, '1']) {
        final json = _draft().toJson()..['schemaVersion'] = version;
        expect(() => RateCardDraft.fromJson(json), throwsFormatException);
      }
      final missing = _draft().toJson()..remove('schemaVersion');
      expect(() => RateCardDraft.fromJson(missing), throwsFormatException);
    });

    test('deserialization rejects invalid measurement enums and values', () {
      expect(
        () => Dimensions.fromJson({
          'enteredUnit': 'yards',
          'metres': {'height': '1'},
        }),
        throwsArgumentError,
      );
      expect(
        () => Dimensions.fromJson({
          'enteredUnit': 'metres',
          'metres': {'length': '1'},
        }),
        throwsArgumentError,
      );
      expect(
        () => Dimensions.fromJson({
          'enteredUnit': 'metres',
          'metres': {'height': '-1'},
        }),
        throwsArgumentError,
      );
      expect(
        () => Dimensions.fromJson({
          'enteredUnit': 'metres',
          'metres': {'height': 1.0},
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test('published metadata normalizes timestamps to UTC and preserves exact values', () {
      final published = PublishedRateCard(
        businessId: 'business_1',
        profileId: 'profile_1',
        version: 7,
        card: _configuredDraft(),
        effectiveAt: DateTime.parse('2026-11-08T10:00:00+05:30'),
        expiresAt: DateTime.parse('2026-12-08T10:00:00+05:30'),
        publishedAt: DateTime.parse('2026-11-07T23:30:00-04:00'),
        publishedBy: 'owner_1',
      );
      final json = published.toJson();
      expect(json['effectiveAt'], '2026-11-08T04:30:00.000Z');
      expect(json['expiresAt'], '2026-12-08T04:30:00.000Z');
      expect(json['publishedAt'], '2026-11-08T03:30:00.000Z');
      final restored = PublishedRateCard.fromJson(
        jsonObject(canonicalJson(json)),
      );
      expect(restored.businessId, 'business_1');
      expect(restored.profileId, 'profile_1');
      expect(restored.version, 7);
      expect(restored.publishedBy, 'owner_1');
      expect(restored.effectiveAt, published.effectiveAt);
      expect(restored.expiresAt, published.expiresAt);
      expect(restored.publishedAt, published.publishedAt);
      expect(canonicalJson(restored.toJson()), canonicalJson(json));
      final noExpiry = PublishedRateCard.fromJson({...json, 'expiresAt': null});
      expect(noExpiry.expiresAt, isNull);
      expect(noExpiry.toJson()['expiresAt'], isNull);
      expect(() => restored.card.categories.clear(), throwsUnsupportedError);
    });
  });
}

PricingCategory _category(String id, {String? parentId, bool active = true}) =>
    PricingCategory(id: id, name: id, parentId: parentId, active: active);

PricingVariant _variant({
  String id = 'oak',
  String categoryId = 'door',
  bool active = true,
  Map<String, String> attributes = const {},
}) => PricingVariant(
  id: id,
  categoryId: categoryId,
  name: id,
  active: active,
  attributes: attributes,
);

PricingAddon _addon({AddonMethod method = AddonMethod.perItem, Exact? rate}) =>
    PricingAddon(
      id: 'hinges',
      name: 'Hinges',
      method: method,
      rate: rate ?? Exact.integer(3),
    );

PricingRule _rule({
  String id = 'rule',
  String categoryId = 'door',
  String? variantId,
  PricingMethod method = PricingMethod.squareFoot,
  Exact? rate,
  List<String> addonIds = const [],
}) => PricingRule(
  id: id,
  categoryId: categoryId,
  variantId: variantId,
  method: method,
  rate: rate ?? Exact.integer(10),
  addonIds: addonIds,
  tax: TaxPolicy(
    reference: 'configured-exempt',
    behavior: TaxBehavior.exempt,
    percent: Exact.zero,
  ),
);

RateCardDraft _draft({
  List<PricingCategory>? categories,
  List<PricingVariant> variants = const [],
  List<PricingRule> rules = const [],
  List<PricingAddon> addons = const [],
}) => RateCardDraft(
  name: 'Test rate card',
  currency: Currency('INR', 2),
  categories: categories ?? [_category('door')],
  variants: variants,
  rules: rules,
  addons: addons,
);

RateCardDraft _configuredDraft({bool reverseMaps = false}) {
  final axes = <Axis, Exact>{
    Axis.width: Exact.integer(900),
    Axis.height: Exact.integer(2100),
  };
  final ranges = <Axis, DimensionRange>{
    Axis.width: DimensionRange(Exact.parse('0.6'), Exact.parse('1.2')),
    Axis.height: DimensionRange(Exact.parse('1.8'), Exact.parse('2.4')),
  };
  final attributes = {'finish': 'oak', 'core': 'solid'};
  return RateCardDraft(
    name: 'Configured door card',
    description: 'Made-to-order doors',
    industryTemplate: 'doors',
    currency: Currency('KWD', 3),
    defaultUnit: LengthUnit.millimetres,
    defaultMethod: PricingMethod.squareMetre,
    rounding: MoneyRounding.halfEven,
    categories: [
      PricingCategory(
        id: 'door',
        name: 'Door',
        parentId: 'doors',
        sortOrder: 5,
      ),
      _category('doors'),
      _category('retired', active: false),
    ],
    variants: [
      _variant(
        attributes: reverseMaps
            ? Map.fromEntries(attributes.entries.toList().reversed)
            : attributes,
      ),
    ],
    addons: [
      PricingAddon(
        id: 'hinges',
        name: 'Hinges',
        method: AddonMethod.quantity,
        rate: Exact.parse('7/3'),
        required: true,
        included: true,
        defaultSelected: true,
      ),
    ],
    rules: [
      PricingRule(
        id: 'oak_rule',
        categoryId: 'door',
        variantId: 'oak',
        method: PricingMethod.squareMetre,
        rate: Exact.parse('1001/3'),
        catalogProductId: 'catalog-door',
        addonIds: ['hinges'],
        tax: TaxPolicy(
          reference: 'configured-tax',
          behavior: TaxBehavior.inclusive,
          percent: Exact.parse('7.5'),
        ),
        discount: DiscountPolicy(
          minimumQuantity: 5,
          fixedPerLine: Exact.parse('1/7'),
          percent: Exact.parse('2.5'),
        ),
        billing: BillingPolicy(
          minimumMeasure: Exact.parse('1/3'),
          measureIncrement: Exact.parse('0.25'),
          dimensionIncrementMetres: Exact.parse('0.001'),
          minimumPrice: Exact.parse('100.01'),
          minimumQuantity: 2,
          stockedSizes: [
            Dimensions.entered(
              reverseMaps
                  ? Map.fromEntries(axes.entries.toList().reversed)
                  : axes,
              LengthUnit.millimetres,
            ),
          ],
          ranges: reverseMaps
              ? Map.fromEntries(ranges.entries.toList().reversed)
              : ranges,
        ),
      ),
    ],
  );
}
